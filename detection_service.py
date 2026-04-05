import cv2
from ultralytics import YOLO
import ntcore
import time

# Configuração NetworkTables (NT4)
inst = ntcore.NetworkTableInstance.getDefault()
table = inst.getTable("SmartDashboard")

# Publicadores (Publishers) para NT4
status_pub = table.getStringTopic("PlantStatus").publish()
disease_detected_pub = table.getBooleanTopic("DiseaseDetected").publish()
conf_pub = table.getDoubleTopic("Confidence").publish()

inst.startServer()

# Carregar modelo YOLOv8
try:

    model = YOLO('best.pt') 
    print(f"Modelo carregado com as classes: {model.names}")
except Exception as e:
    print(f"Erro ao carregar modelo 'best.pt': {e}. Tentando modelo padrão...")
    model = YOLO('yolov8n.pt')

PLANT_CLASSES = [0, 1, 2] # 0: folha_seca, 1: planta_bicolor, 2: mancha
HEALTHY_CLASS = 3        # 3: saudavel

# Abrir Webcam
cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("Erro: Não foi possível abrir a webcam.")
    exit()

print("Serviço de Detecção YOLO (NT4) Iniciado...")

while True:
    ret, frame = cap.read()
    if not ret:
        print("Erro: Não foi possível capturar o frame da webcam.")
        break

    # Validar o frame antes da inferência
    if frame is None or frame.size == 0:
        print("Aviso: Recebido frame vazio.")
        continue

    try:
        results = model.predict(frame, conf=0.5, imgsz=320, verbose=False)
    except Exception as e:
        print(f"Erro durante a inferência YOLO: {e}")
        continue

    detected_diseases = []
    is_healthy = True
    max_conf = 0.0
    
    for r in results:
        for box in r.boxes:
            cls = int(box.cls[0])
            
            if cls not in PLANT_CLASSES and cls != HEALTHY_CLASS:
                continue
                
            label = model.names[cls]
            conf = float(box.conf[0])
            
            if cls in PLANT_CLASSES:
                detected_diseases.append(f"{label}")
                is_healthy = False
            
            if conf > max_conf:
                max_conf = conf
            
            x1, y1, x2, y2 = map(int, box.xyxy[0])
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
            cv2.putText(frame, f"{label} {conf:.2f}", (x1, y1 - 10), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)

    if not is_healthy and detected_diseases:
        status_msg = ", ".join(set(detected_diseases))
        status_pub.set(status_msg)
        disease_detected_pub.set(True)
        conf_pub.set(max_conf)
        print(f"Anomalia Detectada: {status_msg} ({max_conf:.2f})")
    else:
        status_pub.set("Saudável")
        disease_detected_pub.set(False)
        conf_pub.set(max_conf if max_conf > 0 else 0.0)
        if max_conf > 0:
            print(f"Planta Saudável ({max_conf:.2f})")

    cv2.imshow("Plant Disease Detection", frame)

    # Sair com 'q'
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
inst.stopServer()
inst.close()