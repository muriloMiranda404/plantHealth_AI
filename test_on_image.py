import cv2
from ultralytics import YOLO
import ntcore
import os
def test_on_jpg(image_path, model_path='yolov8n.pt'):
    """
    Testa o modelo em uma imagem JPG e envia o resultado para NetworkTables.
    """
    inst = ntcore.NetworkTableInstance.getDefault()
    table = inst.getTable("SmartDashboard")
    status_pub = table.getStringTopic("PlantStatus").publish()
    disease_detected_pub = table.getBooleanTopic("DiseaseDetected").publish()
    inst.startServer()
    model = YOLO(model_path)
    results = model(image_path)
    for r in results:
        detected = []
        for box in r.boxes:
            cls = int(box.cls[0])
            label = model.names[cls]
            detected.append(label)
        if detected:
            msg = ", ".join(detected)
            status_pub.set(f"Imagem {os.path.basename(image_path)}: {msg}")
            disease_detected_pub.set(True)
            print(f"Detectado em {image_path}: {msg}")
        else:
            status_pub.set("Saudável")
            disease_detected_pub.set(False)
            print(f"Nenhuma doença detectada em {image_path}")
        r.save(filename=f"resultado_{os.path.basename(image_path)}")
if __name__ == "__main__":
    print("Script de teste de imagem JPG configurado.")
