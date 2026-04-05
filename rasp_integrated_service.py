import cv2
from ultralytics import YOLO
import ntcore
import serial
import time
import json

inst = ntcore.NetworkTableInstance.getDefault()
table = inst.getTable("SmartDashboard")
inst.startServer() 

status_pub = table.getStringTopic("PlantStatus").publish()
disease_detected_pub = table.getBooleanTopic("DiseaseDetected").publish()
conf_pub = table.getDoubleTopic("Confidence").publish()

# Tópicos do Arduino 
umidade1_pub = table.getDoubleTopic("Umid1").publish()
umidade2_pub = table.getDoubleTopic("Umid2").publish()
luz1_pub = table.getDoubleTopic("Luz1").publish()
luz2_pub = table.getDoubleTopic("Luz2").publish()
temp1_pub = table.getDoubleTopic("Temp1").publish()
temp2_pub = table.getDoubleTopic("Temp2").publish()
ph1_pub = table.getDoubleTopic("PH1").publish()
ph2_pub = table.getDoubleTopic("PH2").publish()

# --- CONFIGURAÇÃO SERIAL (ARDUINO) ---
try:
    ser = serial.Serial('/dev/ttyACM0', 9600, timeout=1)
    ser.flush()
    print("Conectado ao Arduino via Serial!")
except Exception as e:
    print(f"Erro ao conectar ao Arduino: {e}")
    ser = None

try:
    model = YOLO('best.pt') 
except Exception as e:
    print(f"Erro ao carregar modelo: {e}")
    exit()

cap = cv2.VideoCapture(0)

# --- LISTENERS PARA COMANDOS DO DART ---
PLANT_CLASSES = [0, 1, 2] # 0: folha_seca, 1: planta_bicolor, 2: mancha
HEALTHY_CLASS = 3        # 3: saudavel

def on_pump_change(v):
    if ser:
        cmd = "B1\n" if v else "B0\n"
        ser.write(cmd.encode())
        print(f"Comando Bomba: {v}")

def on_ph_offset_change(v):
    print(f"Novo Offset pH: {v}")

def pump_listener(event):
    on_pump_change(event.data.value.getBoolean())

def ph_listener(event):
    on_ph_offset_change(event.data.value.getFloat())

inst.addListener(
    table.getEntry("CmdPump"), 
    ntcore.EventFlags.VALUE_ALL, 
    pump_listener
)

inst.addListener(
    table.getEntry("PH_Offset"), 
    ntcore.EventFlags.VALUE_ALL, 
    ph_listener
)

print("Sistema Integrado (Raspberry + Arduino + NT4) Iniciado...")

while True:
    # 1. Processar Detecção (YOLO)
    ret, frame = cap.read()
    if ret:
        results = model.predict(frame, conf=0.5, imgsz=320, verbose=False)
        detected_diseases = []
        is_healthy = True
        max_conf = 0.0
        
        for r in results:
            for box in r.boxes:
                cls = int(box.cls[0])
                
                # FILTRAR: Ignorar tudo que não for folha doente ou saudável
                if cls not in PLANT_CLASSES and cls != HEALTHY_CLASS:
                    continue
                    
                label = model.names[cls]
                conf = float(box.conf[0])
                
                if cls in PLANT_CLASSES:
                    detected_diseases.append(label)
                    is_healthy = False
                
                if conf > max_conf:
                    max_conf = conf

        if not is_healthy and detected_diseases:
            status_msg = ", ".join(set(detected_diseases))
            status_pub.set(status_msg)
            disease_detected_pub.set(True)
            conf_pub.set(max_conf)
        else:
            status_pub.set("Saudável")
            disease_detected_pub.set(False)
            conf_pub.set(max_conf if max_conf > 0 else 0.0)

    if ser and ser.in_waiting > 0:
        try:
            line = ser.readline().decode('utf-8').rstrip()
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

    time.sleep(0.01)

cap.release()
inst.stopServer()
