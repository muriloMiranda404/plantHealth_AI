import os
import cv2

def auto_label_dataset(base_path):
    """
    Varre as subpastas de images/train e gera arquivos .txt correspondentes
    em labels/train, mapeando o nome da pasta para a classe.
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
        'saudavel': 3
    }

    img_train_path = os.path.join(base_path, 'images', 'train')
    label_train_path = os.path.join(base_path, 'labels', 'train')

    if not os.path.exists(label_train_path):
        os.makedirs(label_train_path)

    print(f"Iniciando rotulagem automática em: {img_train_path}")

    for root, dirs, files in os.walk(img_train_path):
        folder_name = os.path.basename(root)
        
        class_id = None
        for key, val in class_mapping.items():
            if key in folder_name:
                class_id = val
                break
        
        if class_id is None:
            continue

        for file in files:
            if file.lower().endswith(('.jpg', '.jpeg', '.png')):
                img_path = os.path.join(root, file)

                label_name = os.path.splitext(file)[0] + ".txt"
                label_path = os.path.join(label_train_path, label_name)

                if not os.path.exists(label_path):
                    try:

                        with open(label_path, 'w') as f:
                            f.write(f"{class_id} 0.5 0.5 0.8 0.8\n")
                    except Exception as e:
                        print(f"Erro ao criar {label_name}: {e}")

    print("Rotulagem concluída com sucesso!")

if __name__ == "__main__":

    base_dir = r'c:\Users\erika\Downloads\teste\dataset'
    auto_label_dataset(base_dir)
