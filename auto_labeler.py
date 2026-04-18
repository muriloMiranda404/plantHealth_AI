import os
import cv2
import numpy as np
def get_leaf_bbox(image_path):
    """
    Tenta encontrar o bounding box da folha usando processamento de imagem simples.
    Retorna (x_center, y_center, width, height) normalizados.
    """
    img = cv2.imread(image_path)
    if img is None:
        return None
    h, w = img.shape[:2]
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    lower_green = np.array([35, 20, 20])
    upper_green = np.array([85, 255, 255])
    mask_green = cv2.inRange(hsv, lower_green, upper_green)
    lower_brown = np.array([10, 20, 20])
    upper_brown = np.array([30, 255, 255])
    mask_brown = cv2.inRange(hsv, lower_brown, upper_brown)
    mask = cv2.bitwise_or(mask_green, mask_brown)
    kernel = np.ones((5, 5), np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return 0.5, 0.5, 0.7, 0.7
    largest_contour = max(contours, key=cv2.contourArea)
    x, y, bw, bh = cv2.boundingRect(largest_contour)
    x_center = (x + bw / 2) / w
    y_center = (y + bh / 2) / h
    width = bw / w
    height = bh / h
    x_center = max(0, min(1, x_center))
    y_center = max(0, min(1, y_center))
    width = max(0.1, min(1, width))
    height = max(0.1, min(1, height))
    return x_center, y_center, width, height
def auto_label_dataset(base_path):
    """
    Varre as subpastas de images/train e gera arquivos .txt correspondentes
    em labels/train, usando detecção de contorno.
    """
    class_mapping = {
        'Apple___healthy': 3,
        'Apple___Black_rot': 2,
        'Apple___Cedar_apple_rust': 2,
        'Apple___Apple_scab': 2,
        'Corn___healthy': 3,
        'Corn___Common_rust': 2,
        'Corn___Northern_Leaf_Blight': 2,
        'Grape___healthy': 3,
        'Grape___Black_rot': 2,
        'Potato___healthy': 3,
        'Potato___Early_blight': 2,
        'Potato___Late_blight': 2,
        'Tomato___healthy': 3,
        'Tomato___Tomato_Yellow_Leaf_Curl_Virus': 2,
        'Tomato___Leaf_Mold': 2,
        'folha_seca': 0,
        'planta_bicolor': 1,
        'mancha': 2,
        'saudavel': 3,
        'saudável': 3,
        'healthy': 3,
        'diseased': 2,
        'bicolor': 1,
        'dry': 0
    }
    img_train_path = os.path.normpath(os.path.join(base_path, 'images', 'train'))
    label_train_path = os.path.normpath(os.path.join(base_path, 'labels', 'train'))
    if not os.path.exists(img_train_path):
        print(f" [!] ERRO: Pasta de imagens não encontrada: {img_train_path}")
        return
    if not os.path.exists(label_train_path):
        os.makedirs(label_train_path)
    print(f"Iniciando rotulagem INTELIGENTE em: {img_train_path}")
    labeled_count = 0
    for root, dirs, files in os.walk(img_train_path):
        folder_name = os.path.basename(root)
        print(f"DEBUG: Verificando pasta: {folder_name}")
        class_id = None
        for key, val in class_mapping.items():
            if key.lower() in folder_name.lower():
                class_id = val
                print(f"DEBUG: Mapeado {folder_name} para classe {val} (chave: {key})")
                break
        if class_id is None:
            if files:
                print(f"DEBUG: Pasta {folder_name} não mapeada, ignorando {len(files)} arquivos.")
            continue
        for file in files:
            if file.lower().endswith(('.jpg', '.jpeg', '.png', '.bmp', '.webp')):
                img_path = os.path.join(root, file)
                print(f"DEBUG: Processando {file}...")
                label_name = os.path.splitext(file)[0] + ".txt"
                label_path = os.path.join(label_train_path, label_name)
                bbox = get_leaf_bbox(img_path)
                if bbox:
                    try:
                        with open(label_path, 'w') as f:
                            f.write(f"{class_id} {bbox[0]:.6f} {bbox[1]:.6f} {bbox[2]:.6f} {bbox[3]:.6f}\n")
                        labeled_count += 1
                    except Exception as e:
                        print(f"Erro ao criar {label_name}: {e}")
    print(f"Rotulagem concluída! {labeled_count} imagens processadas.")
if __name__ == "__main__":
    base_dir = r'c:\Users\erika\Downloads\teste\dataset'
    auto_label_dataset(base_dir)
