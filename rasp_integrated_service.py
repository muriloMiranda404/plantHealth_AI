import cv2
from ultralytics import YOLO
import ntcore
import serial
import time
import json

# --- CONFIGURAÇÃO NETWORKTABLES (NT4) ---
inst = ntcore.NetworkTableInstance.getDefault()
table = inst.getTable("SmartDashboard")
inst.startServer() # A Raspberry Pi atua como o Servidor

# Tópicos da IA (YOLO)
status_pub = table.getStringTopic("PlantStatus").publish()
disease_detected_pub = table.getBooleanTopic("DiseaseDetected").publish()
conf_pub = table.getDoubleTopic("Confidence").publish()

# Tópicos do Arduino (Sensores Expandidos)
umidade1_pub = table.getDoubleTopic("Umid1").publish()
umidade2_pub = table.getDoubleTopic("Umid2").publish()
luz1_pub = table.getDoubleTopic("Luz1").publish()
luz2_pub = table.getDoubleTopic("Luz2").publish()
temp1_pub = table.getDoubleTopic("Temp1").publish()
temp2_pub = table.getDoubleTopic("Temp2").publish()
ph1_pub = table.getDoubleTopic("PH1").publish()
ph2_pub = table.getDoubleTopic("PH2").publish()

# --- CONFIGURAÇÃO SERIAL (ARDUINO) ---
# Substitua '/dev/ttyACM0' ou '/dev/ttyUSB0' pela porta correta na sua Raspberry
try:
    ser = serial.Serial('/dev/ttyACM0', 9600, timeout=1)
    ser.flush()
    print("Conectado ao Arduino via Serial!")
except Exception as e:
    print(f"Erro ao conectar ao Arduino: {e}")
    ser = None

# --- CARREGAR MODELO YOLOv8 ---
try:
    model = YOLO('best.pt') 
except Exception as e:
    print(f"Erro ao carregar modelo: {e}")
    exit()

cap = cv2.VideoCapture(0)

print("Sistema Integrado (Raspberry + Arduino + NT4) Iniciado...")

while True:
    # 1. Processar Detecção (YOLO)
    ret, frame = cap.read()
    if ret:
        results = model.predict(frame, conf=0.5, imgsz=320, verbose=False)
        detected = []
        max_conf = 0.0
        for r in results:
            for box in r.boxes:
                cls = int(box.cls[0])
                label = model.names[cls]
                conf = float(box.conf[0])
                detected.append(label)
                if conf > max_conf: max_conf = conf

        if detected:
            status_pub.set(", ".join(detected))
            disease_detected_pub.set(True)
            conf_pub.set(max_conf)
        else:
            status_pub.set("Saudável")
            disease_detected_pub.set(False)
            conf_pub.set(0.0)

    # 2. Processar Dados do Arduino (Serial)
    if ser and ser.in_waiting > 0:
        try:
            line = ser.readline().decode('utf-8').rstrip()
            # Mapeamento do JSON do Arduino para os publicadores NT4
            data = json.loads(line)
            if "u1" in data: umidade1_pub.set(float(data["u1"]))
            if "u2" in data: umidade2_pub.set(float(data["u2"]))
            if "l1" in data: luz1_pub.set(float(data["l1"]))
            if "l2" in data: luz2_pub.set(float(data["l2"]))
            if "t1" in data: temp1_pub.set(float(data["t1"]))
            if "t2" in data: temp2_pub.set(float(data["t2"]))
            if "p1" in data: ph1_pub.set(float(data["p1"]))
            if "p2" in data: ph2_pub.set(float(data["p2"]))
        except Exception as e:
            print(f"Erro ao ler serial: {e}")

    # Pausa leve para não sobrecarregar a CPU
    time.sleep(0.01)

cap.release()
inst.stopServer()
