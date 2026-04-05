import os

def create_labels():
    """
    Cria rótulos .txt (labels) automáticos para as imagens JPG que você colocou.
    Isso serve para mostrar como o treinamento funciona.
    """
    # 0: folha_seca
    # 1: planta_bicolor
    
    # Lista de imagens nas pastas
    dirs = ['train', 'val']
    
    for d in dirs:
        img_dir = f'dataset/images/{d}'
        label_dir = f'dataset/labels/{d}'
        
        # Cria a pasta de labels se não existir
        os.makedirs(label_dir, exist_ok=True)
        
        if not os.path.exists(img_dir):
            continue
            
        for img_file in os.listdir(img_dir):
            if img_file.endswith('.jpg') or img_file.endswith('.jpeg'):
                # Nome do arquivo de texto correspondente
                txt_file = os.path.splitext(img_file)[0] + '.txt'
                txt_path = os.path.join(label_dir, txt_file)
                
                # Escolhe a classe baseada no nome (exemplo simples)
                class_id = 0 # folha_seca
                if 'bicolor' in img_file:
                    class_id = 1 # planta_bicolor
                
                # Cria um rótulo cobrindo o centro (x_center y_center width height)
                # Formato: <class_id> <x_center> <y_center> <width> <height>
                with open(txt_path, 'w') as f:
                    f.write(f"{class_id} 0.5 0.5 0.8 0.8")
                
                print(f"Rótulo criado: {txt_path} para {img_file}")

if __name__ == "__main__":
    create_labels()
