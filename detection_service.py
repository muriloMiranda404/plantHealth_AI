import cv2
from ultralytics import YOLO
import ntcore
import time
from flask import Flask, Response
import threading
import logging

# Desativar logs chatos do Flask
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

import numpy as np

# --- CONFIGURAÇÃO STREAMING HTTP (Flask) ---
app = Flask(__name__)
output_jpeg = None
lock = threading.Lock()
brightness_offset = 0
stream_fps = 18
jpeg_quality = 72

# Criar um frame de erro/espera (placeholder)
def create_placeholder(msg="Aguardando Câmera..."):
    img = np.zeros((480, 640, 3), dtype=np.uint8)
    cv2.putText(img, msg, (120, 240), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
    _, encoded = cv2.imencode('.jpg', img)
    return encoded.tobytes()

# Inicializa com placeholder
output_jpeg = create_placeholder("Iniciando Sistema...")

STREAM_WIDTH = 480
DETECTION_INTERVAL = 3
MIN_STREAM_FPS = 5
MAX_STREAM_FPS = 30
DEFAULT_JPEG_QUALITY = 72
MIN_JPEG_QUALITY = 35
MAX_JPEG_QUALITY = 85


def adjust_quality_for_fps(current_fps):
    global jpeg_quality

    if current_fps < stream_fps - 1.0 and jpeg_quality > MIN_JPEG_QUALITY:
        jpeg_quality = max(MIN_JPEG_QUALITY, jpeg_quality - 5)
        print(f" [STREAM] Reduzindo qualidade para {jpeg_quality} para buscar {stream_fps} FPS")
    elif current_fps >= stream_fps - 0.3 and jpeg_quality < DEFAULT_JPEG_QUALITY:
        jpeg_quality = min(DEFAULT_JPEG_QUALITY, jpeg_quality + 2)
        print(f" [STREAM] Recuperando qualidade para {jpeg_quality}")


def apply_stream_adjustments(frame):
    if frame is None:
        return None

    adjusted = frame
    if brightness_offset != 0:
        adjusted = cv2.convertScaleAbs(adjusted, alpha=1.0, beta=brightness_offset)

    height, width = adjusted.shape[:2]
    if width > STREAM_WIDTH:
        stream_height = int(height * (STREAM_WIDTH / width))
        adjusted = cv2.resize(
            adjusted,
            (STREAM_WIDTH, stream_height),
            interpolation=cv2.INTER_LINEAR,
        )

    return adjusted

def generate():
    global output_jpeg, lock, stream_fps
    print(" [STREAM] Novo cliente conectado ao vídeo feed")
    while True:
        with lock:
            encoded_image = output_jpeg
        
        if encoded_image is None:
            time.sleep(0.02)
            continue

        try:
            yield(
                b'--frame\r\n'
                b'Content-Type: image/jpeg\r\n\r\n' + encoded_image + b'\r\n'
            )
        except GeneratorExit:
            print(" [STREAM] Cliente desconectado")
            break
            
        time.sleep(1 / max(stream_fps, 1))

@app.route("/video_feed")
def video_feed():
    return Response(generate(), mimetype="multipart/x-mixed-replace; boundary=frame")

def start_flask():
    print(" [STREAM] Servidor de vídeo rodando em http://0.0.0.0:5000/video_feed")
    app.run(host="0.0.0.0", port=5000, debug=False, threaded=True, use_reloader=False)


def on_brightness_change(event):
    global brightness_offset
    try:
        brightness_offset = int(event.data.value.getDouble())
        print(f" [STREAM] Luminosidade ajustada para {brightness_offset}")
    except Exception as exc:
        print(f" [STREAM] Erro ao aplicar luminosidade: {exc}")


def on_fps_change(event):
    global stream_fps, jpeg_quality
    try:
        new_fps = int(round(event.data.value.getDouble()))
        stream_fps = max(MIN_STREAM_FPS, min(MAX_STREAM_FPS, new_fps))
        if stream_fps >= 24:
            jpeg_quality = min(jpeg_quality, 60)
        elif stream_fps >= 18:
            jpeg_quality = min(jpeg_quality, 68)
        else:
            jpeg_quality = min(MAX_JPEG_QUALITY, max(jpeg_quality, DEFAULT_JPEG_QUALITY))
        print(f" [STREAM] FPS alvo ajustado para {stream_fps}")
    except Exception as exc:
        print(f" [STREAM] Erro ao aplicar FPS: {exc}")

# --- LÓGICA DE DETECÇÃO ---
def get_best_camera():
    """Tenta encontrar uma câmera funcional, priorizando WebCams externas (índices 1 e 2)."""
    # A câmera integrada do laptop ou a câmera CSI da Pi costumam ser o index 0.
    test_indices = [1, 2, 0, 3, 4]
    working_cameras = []
    
    print(f" [STREAM] Iniciando busca por câmeras (priorizando índices {test_indices[:2]})...")
    
    for idx in test_indices:
        # Tenta abrir a câmera. Usamos CAP_V4L2 no Linux/Pi, mas o OpenCV vai decidir se falhar.
        cap = cv2.VideoCapture(idx, cv2.CAP_V4L2)
        if not cap.isOpened():
            cap = cv2.VideoCapture(idx) # Tenta sem backend específico
            
        if cap.isOpened():
            ret, _ = cap.read()
            if ret:
                working_cameras.append(idx)
                print(f" [STREAM] Câmera encontrada no index {idx}")
            cap.release()

    if not working_cameras:
        print(" [!] ERRO: Nenhuma câmera funcional detectada nos índices testados.")
        return 0
    
    for target in [1, 2]:
        if target in working_cameras:
            print(f" [STREAM] Selecionando WebCam Externa (Index {target})")
            return target
            
    print(f" [STREAM] Nenhuma WebCam externa (1/2) encontrada. Usando Index {working_cameras[0]}")
    return working_cameras[0]

def run_detection():
    global output_jpeg, lock
    
    # 1. Configurar NT4
    inst = ntcore.NetworkTableInstance.getDefault()
    table = inst.getTable("SmartDashboard")
    status_pub = table.getStringTopic("PlantStatus").publish()
    disease_detected_pub = table.getBooleanTopic("DiseaseDetected").publish()
    conf_pub = table.getDoubleTopic("Confidence").publish()
    camera_fps_pub = table.getDoubleTopic("CameraFPS").publish()
    inst.startServer()
    inst.addListener(
        table.getEntry("CameraBrightness"),
        ntcore.EventFlags.kValueAll,
        on_brightness_change,
    )
    inst.addListener(
        table.getEntry("CameraTargetFPS"),
        ntcore.EventFlags.kValueAll,
        on_fps_change,
    )

    # 2. Carregar modelo YOLOv8
    try:
        model = YOLO('best.pt') 
        print(f" [AI] Modelo carregado: {model.names}")
    except Exception as e:
        print(f" [!] Erro ao carregar 'best.pt': {e}. Usando padrão.")
        model = YOLO('yolov8n.pt')

    cam_idx = get_best_camera()
    cap = cv2.VideoCapture(cam_idx)
    # Tentar aumentar FPS da câmera
    cap.set(cv2.CAP_PROP_FPS, 30)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

    if not cap.isOpened():
        print(f" [!] Erro: Webcam no index {cam_idx} não pôde ser aberta.")
        with lock:
            output_jpeg = create_placeholder(f"Erro: Camera {cam_idx} offline")
        return

    print(f" [AI] Serviço de Detecção Iniciado com Câmera {cam_idx}...")
    frame_count = 0
    last_draw_frame = None
    encoded_frames = 0
    fps_window_started_at = time.perf_counter()
    camera_fps_pub.set(float(stream_fps))

    while True:
        ret, frame = cap.read()
        if not ret: break
        frame_count += 1
        
        # Rodar IA em intervalos para priorizar fluidez do stream.
        if frame_count % DETECTION_INTERVAL == 0:
            results = model.predict(frame, conf=0.15, imgsz=320, verbose=False)
            
            detected_diseases = []
            is_healthy = True
            max_conf = 0.0
            draw_frame = frame.copy()

            for r in results:
                for box in r.boxes:
                    cls = int(box.cls[0])
                    label = model.names[cls]
                    conf = float(box.conf[0])

                    is_disease = any(word in label.lower() for word in ['seca', 'bicolor', 'mancha', 'rot', 'rust', 'blight', 'mold', 'virus', 'doenca'])
                    is_healthy_label = any(word in label.lower() for word in ['healthy', 'saudavel', 'saudável'])

                    if not (is_disease or is_healthy_label):
                        continue 
                    
                    if is_disease:
                        detected_diseases.append(label)
                        is_healthy = False
                    
                    if conf > max_conf: max_conf = conf
                    
                    # Desenhar no draw_frame
                    x1, y1, x2, y2 = map(int, box.xyxy[0])
                    color = (0, 0, 255) if is_disease else (0, 255, 0)
                    cv2.rectangle(draw_frame, (x1, y1), (x2, y2), color, 2)
                    cv2.putText(draw_frame, f"{label} {conf:.2f}", (x1, y1 - 10), 
                                cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

            # Atualizar NetworkTables (NT4)
            if not is_healthy and detected_diseases:
                msg = ", ".join(set(detected_diseases))
                status_pub.set(msg)
                disease_detected_pub.set(True)
                conf_pub.set(max_conf)
                print(f" [!] ALERTA: {msg} ({max_conf:.2f})")
            elif max_conf > 0:
                status_pub.set("Saudável")
                disease_detected_pub.set(False)
                conf_pub.set(max_conf)
                print(f" [+] Planta Saudável ({max_conf:.2f})")
            else:
                status_pub.set("Buscando...")
                if frame_count % 40 == 0:
                    print(" [AI] Analisando ambiente (nenhuma planta confirmada)...")
            
            last_draw_frame = draw_frame.copy()

        # Atualizar o frame global para o stream do Flask (sempre atualiza)
        source_frame = last_draw_frame if last_draw_frame is not None else frame
        stream_frame = apply_stream_adjustments(source_frame)
        flag, encoded_image = cv2.imencode(
            ".jpg",
            stream_frame,
            [int(cv2.IMWRITE_JPEG_QUALITY), jpeg_quality],
        )
        with lock:
            if flag:
                output_jpeg = encoded_image.tobytes()
                encoded_frames += 1

        now = time.perf_counter()
        elapsed = now - fps_window_started_at
        if elapsed >= 1.0:
            pipeline_fps = encoded_frames / elapsed
            current_fps = min(pipeline_fps, float(stream_fps))
            adjust_quality_for_fps(current_fps)
            camera_fps_pub.set(current_fps)
            encoded_frames = 0
            fps_window_started_at = now

        # Se o preview local falhar ou não for desejado em headless:
        # if frame_count % 30 == 0:
        #     print(f" [STREAM] Enviando frame... (FPS: {current_fps:.1f})")

    cap.release()
    inst.stopServer()

if __name__ == "__main__":
    # Rodar Flask em uma thread
    t_flask = threading.Thread(target=start_flask, daemon=True)
    t_flask.start()
    
    # Rodar Detecção na thread principal
    run_detection()
