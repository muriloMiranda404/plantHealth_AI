import os
import sys
import cv2
import serial
import serial.tools.list_ports
import time
import json
import threading
import asyncio
import websockets
import paho.mqtt.client as mqtt
import torch
import multiprocessing as mp
import socket
import ntcore
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn
try:
    from edge_impulse_linux.image import ImageImpulseRunner
    HAS_EDGE_IMPULSE = True
except ImportError:
    HAS_EDGE_IMPULSE = False
import io
os.environ['OPENBLAS_CORETYPE'] = 'ARMV8'
os.environ['OMP_NUM_THREADS'] = '1'
os.environ['MKL_DEBUG_CPU_TYPE'] = '5'
os.environ['OPENCV_VIDEOIO_PRIORITY_MSMF'] = '0'
class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True
class StreamHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args): pass
    def do_GET(self):
        if self.path == '/video_feed':
            try:
                header = (
                    "HTTP/1.1 200 OK\r\n"
                    "Age: 0\r\n"
                    "Cache-Control: no-cache, private\r\n"
                    "Pragma: no-cache\r\n"
                    "Content-Type: multipart/x-mixed-replace; boundary=FRAME\r\n"
                    "\r\n"
                ).encode()
                self.wfile.write(header)
                while True:
                    with frame_lock:
                        frame_data = current_encoded_frame if current_encoded_frame else create_test_frame("INICIANDO...")
                    footer = f"--FRAME\r\nContent-Type: image/jpeg\r\nContent-Length: {len(frame_data)}\r\n\r\n".encode()
                    self.wfile.write(footer)
                    self.wfile.write(frame_data)
                    self.wfile.write(b"\r\n")
                    time.sleep(0.1)
            except (ConnectionResetError, BrokenPipeError): pass
            except Exception as e: print(f" [STREAM] Erro: {e}")
        elif self.path == '/capture':
            try:
                with frame_lock:
                    frame_data = current_encoded_frame if current_encoded_frame else create_test_frame("BUSCANDO...")
                self.send_response(200)
                self.send_header('Content-Type', 'image/jpeg')
                self.send_header('Content-Length', len(frame_data))
                self.send_header('Cache-Control', 'no-cache')
                self.end_headers()
                self.wfile.write(frame_data)
            except Exception as e:
                print(f" [CAPTURE] Erro: {e}")
                self.send_error(500)
        else:
            self.send_error(404)
def start_mjpeg_server():
    try:
        server = ThreadedHTTPServer(('0.0.0.0', 5000), StreamHandler)
        server.serve_forever()
    except Exception as e:
        print(f" [ERRO] Servidor MJPEG falhou: {e}")
def create_test_frame(text="CAMERA OFFLINE"):
    import numpy as np
    img = np.zeros((320, 240, 3), np.uint8)
    cv2.putText(img, text, (20, 120), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
    ret, buffer = cv2.imencode('.jpg', img)
    return buffer.tobytes()
frame_lock = threading.Lock()
current_encoded_frame = None
WS_CLIENTS = set()
latest_sensor_json = "{}"
async def ws_handler(websocket):
    WS_CLIENTS.add(websocket)
    try:
        async for message in websocket: pass
    except: pass
    finally: WS_CLIENTS.remove(websocket)
async def ws_server_logic():
    try:
        async with websockets.serve(ws_handler, "0.0.0.0", 8765, ping_interval=None):
            while True:
                if WS_CLIENTS:
                    msg = latest_sensor_json
                    for client in list(WS_CLIENTS):
                        try: await client.send(msg)
                        except: pass
                await asyncio.sleep(0.2)
    except: pass
def start_ws():
    asyncio.run(ws_server_logic())
def ai_process_worker(queue_in, queue_out, model_path):
    from ultralytics import YOLO
    import torch
    torch.backends.nnpack.enabled = False
    torch.backends.mkldnn.enabled = False
    try:
        _orig_load = torch.load
        torch.load = lambda *a, **k: _orig_load(*a, **{**k, 'weights_only': False})
        model = YOLO(model_path)
        torch.load = _orig_load
        print(" [IA] Modelo YOLO carregado com sucesso.")
    except Exception as e:
        print(f" [IA] Erro ao carregar YOLO: {e}")
        model = None
    ei_runner = None
    if HAS_EDGE_IMPULSE:
        modelfile = "modelfile.eim"
        if os.path.exists(modelfile):
            try:
                ei_runner = ImageImpulseRunner(modelfile)
                model_info = ei_runner.init()
                print(f" [IA] Modelo Edge Impulse carregado: {model_info['project']['name']}")
            except Exception as e:
                print(f" [IA] Falha ao iniciar Edge Impulse: {e}")
                ei_runner = None
    while True:
        try:
            frame = queue_in.get()
            if frame is None: break
            status, has_dis, conf = "Saudável", "false", 0.0
            detected_boxes = []
            if ei_runner:
                try:
                    features, img = ei_runner.get_features_from_image(frame)
                    res = ei_runner.classify(features)
                    if "bounding_boxes" in res["result"]:
                        for bb in res["result"]["bounding_boxes"]:
                            if bb["value"] > 0.5:
                                status = bb["label"]
                                conf = bb["value"]
                                has_dis = "true" if "saudavel" not in status.lower() else "false"
                                detected_boxes.append({
                                    "coords": [bb["x"], bb["y"], bb["x"]+bb["width"], bb["y"]+bb["height"]],
                                    "conf": conf,
                                    "name": status
                                })
                except Exception as e:
                    print(f" [IA] Erro na inferência Edge Impulse: {e}")
            if not detected_boxes and model:
                small_frame = cv2.resize(frame, (320, 240))
                with torch.no_grad():
                    results = model.predict(small_frame, conf=0.35, imgsz=320, verbose=False, device='cpu')
                if results:
                    for r in results:
                        if r.boxes:
                            best_box = None
                            max_conf = -1
                            for box in r.boxes:
                                c = float(box.conf[0])
                                b = box.xyxy[0].tolist()
                                cls_idx = int(box.cls[0])
                                detected_boxes.append({
                                    "coords": b,
                                    "conf": c,
                                    "name": model.names[cls_idx]
                                })
                                if c > max_conf:
                                    max_conf = c
                                    best_box = box
                            if best_box:
                                cls = int(best_box.cls[0])
                                status = model.names[cls]
                                has_dis = "true" if (cls > 0 or "saudavel" not in status.lower()) else "false"
                                conf = max_conf
            queue_out.put({
                "status": status, 
                "disease": has_dis, 
                "confidence": conf, 
                "boxes": detected_boxes
            })
        except: pass
def find_arduino():
    print(" [SISTEMA] Procurando Arduino UNO...")
    ports = serial.tools.list_ports.comports()
    for port in ports:
        vid = port.vid if port.vid is not None else 0
        desc = port.description.lower() if port.description is not None else ""
        if vid in [0x2341, 0x1A86, 0x0403, 0x10C4] or any(x in desc for x in ['arduino', 'uno', 'ch340']):
            for baud in [115200, 9600]:
                try:
                    print(f" [SISTEMA] Tentando conexão serial em {port.device} @ {baud}...")
                    s = serial.Serial(port.device, baud, timeout=1)
                    time.sleep(2)
                    print(f" [SISTEMA] Placa Arduino detectada e aberta em {port.device}")
                    return s
                except Exception as e:
                    print(f" [AVISO] Erro ao abrir porta {port.device}: {e}")
                    continue
    return None
def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except: return "127.0.0.1"
if __name__ == "__main__":
    MQTT_TOPIC_PREFIX = "plantguard_pro/device_ref_9921"
    SIMULATION_MODE = False
    AI_ENABLED = True
    NIGHT_MODE = False
    CAMERA_BRIGHTNESS = 0.0
    CAMERA_TARGET_FPS = 15
    TAKE_PHOTO_REQUEST = False
    current_encoded_frame = create_test_frame("INICIANDO...")
    inst = ntcore.NetworkTableInstance.getDefault()
    table = inst.getTable("SmartDashboard")
    nt_status_pub = table.getStringTopic("PlantStatus").publish()
    nt_disease_pub = table.getBooleanTopic("DiseaseDetected").publish()
    nt_conf_pub = table.getDoubleTopic("Confidence").publish()
    nt_fps_pub = table.getDoubleTopic("CameraFPS").publish()
    nt_arduino_pub = table.getBooleanTopic("ArduinoBoard").publish()
    nt_camera_pub = table.getBooleanTopic("CameraStatus").publish()
    inst.startServer()
    def on_nt_brightness_change(event):
        global CAMERA_BRIGHTNESS
        try:
            CAMERA_BRIGHTNESS = event.data.value.getDouble()
            print(f" [NT4] Brilho ajustado para {CAMERA_BRIGHTNESS}")
        except: pass
    def on_nt_fps_change(event):
        global CAMERA_TARGET_FPS
        try:
            CAMERA_TARGET_FPS = int(round(event.data.value.getDouble()))
            print(f" [NT4] FPS alvo ajustado para {CAMERA_TARGET_FPS}")
        except: pass
    def on_nt_ai_enable(event):
        global AI_ENABLED
        try:
            AI_ENABLED = event.data.value.getBoolean()
            print(f" [NT4] IA {'Ativada' if AI_ENABLED else 'Desativada'}")
        except: pass
    def on_nt_night_mode(event):
        global NIGHT_MODE
        try:
            NIGHT_MODE = event.data.value.getBoolean()
            print(f" [NT4] Modo Noturno {'Ativado' if NIGHT_MODE else 'Desativado'}")
        except: pass
    inst.addListener(table.getEntry("CameraBrightness"), ntcore.EventFlags.kValueAll, on_nt_brightness_change)
    inst.addListener(table.getEntry("CameraTargetFPS"), ntcore.EventFlags.kValueAll, on_nt_fps_change)
    inst.addListener(table.getEntry("AIEnable"), ntcore.EventFlags.kValueAll, on_nt_ai_enable)
    inst.addListener(table.getEntry("NightMode"), ntcore.EventFlags.kValueAll, on_nt_night_mode)
    ai_queue_in = mp.Queue(maxsize=1)
    ai_queue_out = mp.Queue(maxsize=1)
    ai_p = mp.Process(target=ai_process_worker, args=(ai_queue_in, ai_queue_out, 'best.pt'), daemon=True)
    ai_p.start()
    mqtt_client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2)
    mqtt_connected = False
    def on_mqtt_message(client, userdata, msg):
        global SIMULATION_MODE, AI_ENABLED, CAMERA_BRIGHTNESS, CAMERA_TARGET_FPS, TAKE_PHOTO_REQUEST, NIGHT_MODE
        try:
            payload = msg.payload.decode('utf-8').strip()
            topic = msg.topic.split('/')[-1]
            print(f" [MQTT] Comando recebido: {topic} -> {payload}")
            if topic == "simulation": 
                SIMULATION_MODE = (payload.lower() == "true")
            elif topic == "ai_enable": 
                AI_ENABLED = (payload.lower() == "true")
            elif topic == "brightness":
                try:
                    CAMERA_BRIGHTNESS = float(payload)
                    if cap and cap.isOpened():
                        cap.set(cv2.CAP_PROP_BRIGHTNESS, (CAMERA_BRIGHTNESS + 100) / 200.0)
                except: pass
            elif topic == "fps":
                try:
                    val = int(float(payload))
                    if 1 <= val <= 60: 
                        CAMERA_TARGET_FPS = val
                        if cap and cap.isOpened():
                            cap.set(cv2.CAP_PROP_FPS, CAMERA_TARGET_FPS)
                except: pass
            elif topic == "take_photo":
                TAKE_PHOTO_REQUEST = True
            elif topic == "night_mode":
                NIGHT_MODE = (payload.lower() == "true")
            elif topic == "pump":
                if ser and ser.is_open:
                    status = payload.lower()
                    is_on = status in ["true", "on", "1"]
                    cmd = f"PUMP:{'ON' if is_on else 'OFF'}\n"
                    ser.write(cmd.encode())
                    print(f" [ARDUINO] Enviando comando: {cmd.strip()}")
        except Exception as e: 
            print(f" [MQTT ERRO] {e}")
    def on_connect(client, userdata, flags, rc, properties=None):
        global mqtt_connected
        if rc == 0:
            mqtt_connected = True
            print(f" [MQTT] Conectado ao Broker com sucesso!")
            client.subscribe(f"{MQTT_TOPIC_PREFIX}/cmd/
            client.publish(f"{MQTT_TOPIC_PREFIX}/mqtt_status", "connected", retain=True)
        else:
            print(f" [MQTT] Erro na conexão: {rc}")
    def on_nt_change(event):
        global CAMERA_BRIGHTNESS, CAMERA_TARGET_FPS, AI_ENABLED, NIGHT_MODE
        try:
            name = event.data.topic.getName().split('/')[-1]
            val = event.data.value.value()
            print(f" [NT4] Mudança detectada: {name} -> {val}")
            if name == "CameraBrightness":
                CAMERA_BRIGHTNESS = float(val)
                if cap and cap.isOpened():
                    cap.set(cv2.CAP_PROP_BRIGHTNESS, (CAMERA_BRIGHTNESS + 100) / 200.0)
            elif name == "CameraTargetFPS":
                val_int = int(float(val))
                if 1 <= val_int <= 60: CAMERA_TARGET_FPS = val_int
            elif name == "AIEnable":
                AI_ENABLED = bool(val)
            elif name == "NightMode":
                NIGHT_MODE = bool(val)
        except Exception as e:
            print(f" [NT4 ERRO] {e}")
    inst.addListener(table, ntcore.EventFlags.kValueAll, on_nt_change)
    mqtt_client.on_message = on_mqtt_message
    mqtt_client.on_connect = on_connect
    def start_mqtt():
        brokers = ["test.mosquitto.org", "broker.hivemq.com", "broker.emqx.io"]
        for b in brokers:
            try:
                print(f" [MQTT] Tentando conectar ao Broker: {b}...")
                mqtt_client.connect(b, 1883, 60)
                mqtt_client.loop_start()
                return True
            except:
                print(f" [MQTT] Falha no broker {b}")
                continue
        return False
    start_mqtt()
    threading.Thread(target=start_mjpeg_server, daemon=True).start()
    print(f" [SISTEMA] Servidor MJPEG ON em http://{get_local_ip()}:5000/video_feed")
    threading.Thread(target=start_ws, daemon=True).start()
    print(f" [SISTEMA] Servidor WebSocket ON na porta 8765")
    cap = cv2.VideoCapture(1, cv2.CAP_V4L2)
    if not cap.isOpened(): cap = cv2.VideoCapture(0, cv2.CAP_V4L2)
    ser = find_arduino()
    frame_count = 0
    fps_start_time = time.time()
    fps_frame_counter = 0
    last_serial_time = time.time()
    latest_ai_results = {"boxes": []}
    while True:
        loop_start_time = time.time()
        try:
            if cap and cap.isOpened():
                ret, frame = cap.read()
                if ret:
                    h, w = frame.shape[:2]
                    scale_x, scale_y = w / 320, h / 240
                    for detection in latest_ai_results.get("boxes", []):
                        x1, y1, x2, y2 = detection["coords"]
                        ix1, iy1, ix2, iy2 = int(x1 * scale_x), int(y1 * scale_y), int(x2 * scale_x), int(y2 * scale_y)
                        label = detection["name"]
                        color = (0, 0, 255) if "saudavel" not in label.lower() else (0, 255, 0)
                        cv2.rectangle(frame, (ix1, iy1), (ix2, iy2), color, 2)
                        text = f"{label} {detection['conf']:.2f}"
                        cv2.putText(frame, text, (ix1, iy1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)
                    if CAMERA_BRIGHTNESS != 0:
                        frame = cv2.convertScaleAbs(frame, alpha=1.0, beta=float(CAMERA_BRIGHTNESS))
                    fps_frame_counter += 1
                    elapsed = time.time() - fps_start_time
                    if elapsed >= 2.0:
                        real_fps = fps_frame_counter / elapsed
                        mqtt_client.publish(f"{MQTT_TOPIC_PREFIX}/camera_fps", f"{real_fps:.1f}")
                        nt_fps_pub.set(real_fps)
                        fps_frame_counter = 0
                        fps_start_time = time.time()
                    try:
                        ret_enc, buffer = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 40])
                        if ret_enc:
                            with frame_lock: current_encoded_frame = buffer.tobytes()
                    except: pass
                    if AI_ENABLED and frame_count % 10 == 0:
                        if ai_queue_in.empty(): ai_queue_in.put(frame)
                    if TAKE_PHOTO_REQUEST:
                        import os
                        if not os.path.exists('capturas'):
                            os.makedirs('capturas')
                        timestamp = time.strftime("%Y%m%d_%H%M%S")
                        filename = f"capturas/captura_{timestamp}.jpg"
                        cv2.imwrite(filename, frame)
                        print(f" [SISTEMA] Foto salva na Rasp: {filename}")
                        mqtt_client.publish(f"{MQTT_TOPIC_PREFIX}/photo_saved", filename)
                        TAKE_PHOTO_REQUEST = False
                else:
                    print(" [CÂMERA] Falha na leitura. Reiniciando...")
                    cap.release()
                    cap = None
            else:
                if frame_count % 100 == 0:
                    cap = cv2.VideoCapture(1, cv2.CAP_V4L2)
                    if not cap.isOpened(): cap = cv2.VideoCapture(0, cv2.CAP_V4L2)
                with frame_lock: current_encoded_frame = create_test_frame("BUSCANDO CÂMERA...")
            if ser:
                try:
                    if ser.is_open:
                        if ser.in_waiting > 0:
                            line = ser.readline().decode('utf-8', errors='ignore').rstrip()
                            if line.startswith('{'):
                                try:
                                    data = json.loads(line)
                                    for k, v in data.items(): mqtt_client.publish(f"{MQTT_TOPIC_PREFIX}/{k}", str(v))
                                    last_serial_time = time.time()
                                except: pass
                    else: raise Exception("Serial fechado")
                except: 
                    ser = None
                    print(" [ARDUINO] Conexão perdida.")
            elif frame_count % 100 == 0: 
                ser = find_arduino()
            if frame_count % 20 == 0:
                mqtt_client.publish(f"{MQTT_TOPIC_PREFIX}/heartbeat", str(time.time()))
                mqtt_client.publish(f"{MQTT_TOPIC_PREFIX}/arduino_board", "true" if ser else "false")
                mqtt_client.publish(f"{MQTT_TOPIC_PREFIX}/camera_status", "true" if cap and cap.isOpened() else "false")
                nt_arduino_pub.set(True if ser else False)
                nt_camera_pub.set(True if cap and cap.isOpened() else False)
            if not ai_queue_out.empty():
                res = ai_queue_out.get()
                latest_ai_results = res
                mqtt_client.publish(f"{MQTT_TOPIC_PREFIX}/status", res['status'])
                mqtt_client.publish(f"{MQTT_TOPIC_PREFIX}/disease", res['disease'])
                mqtt_client.publish(f"{MQTT_TOPIC_PREFIX}/confidence", str(res['confidence']))
                nt_status_pub.set(res['status'])
                nt_disease_pub.set(res['disease'].lower() == "true")
                nt_conf_pub.set(res['confidence'])
            if SIMULATION_MODE and frame_count % 10 == 0:
                import random
                fake_data = {"u1": random.uniform(40,60), "t1": random.uniform(20,30), "water_level": random.uniform(70,90)}
                for k, v in fake_data.items(): mqtt_client.publish(f"{MQTT_TOPIC_PREFIX}/{k}", str(v))
            frame_count += 1
            loop_duration = time.time() - loop_start_time
            sleep_time = (1.0 / CAMERA_TARGET_FPS) - loop_duration
            if sleep_time > 0:
                time.sleep(sleep_time)
            else:
                time.sleep(0.005)
        except Exception as e:
            print(f" [ERRO LOOP] {e}")
            time.sleep(1)
