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
    
    # 1. Carregar modelo base (YOLOv8 nano é ótimo para testes e dispositivos móveis/embarcados)
    model = YOLO('best.pt') 

    # 2. Iniciar o treinamento
    # data='plant_diseases.yaml' aponta para o arquivo que criamos com os nomes das classes
    # epochs=50 -> Número de vezes que ele verá todas as fotos (aumente para melhor precisão)
    # imgsz=640 -> Redimensiona as fotos JPG para 640x640 durante o treino
    
    results = model.train(
        data='plant_diseases.yaml', 
        epochs=50,
        imgsz=640,
        device='cpu', # Mude para 0 se tiver placa de vídeo NVIDIA (CUDA)
        project='treino_plantas',
        name='modelo_v1'
    )
    
    print("Treino concluído! O modelo treinado está em: treino_plantas/modelo_v1/weights/best.pt")

if __name__ == "__main__":
    print("Iniciando treinamento com seus arquivos JPG...")
    # Descomente a linha abaixo quando seu dataset estiver pronto na pasta /dataset
    train_model() 
    print("Certifique-se de que a estrutura de pastas /dataset/images e /dataset/labels está correta.")
