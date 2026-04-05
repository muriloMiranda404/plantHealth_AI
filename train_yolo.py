from ultralytics import YOLO

def train_model():
    """
    Treina o modelo YOLOv8 usando seu dataset de imagens JPG locais.
    Sua pasta 'dataset' deve estar organizada assim:
    /dataset
        /images
            /train (seus JPGs de treino)
            /val   (seus JPGs de validação)
        /labels
            /train (seus .txt correspondentes a cada imagem)
            /val   (seus .txt correspondentes a cada imagem)
    """
    
    model = YOLO('best.pt') 
    
    results = model.train(
        data='plant_diseases.yaml', 
        epochs=50,
        imgsz=640,
        device='cpu', 
        project='treino_plantas',
        name='modelo_v1'
    )
    
    print("Treino concluído! O modelo treinado está em: treino_plantas/modelo_v1/weights/best.pt")

if __name__ == "__main__":
    print("Iniciando treinamento com seus arquivos JPG...")

    train_model() 
    print("Certifique-se de que a estrutura de pastas /dataset/images e /dataset/labels está correta.")
