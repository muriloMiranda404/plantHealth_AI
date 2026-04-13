import os
import shutil
from ultralytics import YOLO

def train_model():
    # 1. Carregar um modelo pré-treinado (YOLOv8 Nano é ideal para Raspberry Pi)
    model = YOLO('yolov8n.pt')

    # 2. Caminho para o arquivo de dados
    data_path = os.path.join(os.getcwd(), 'data.yaml')
    
    if not os.path.exists(data_path):
        print(f" [!] ERRO: Arquivo {data_path} não encontrado!")
        return

    print("--- INICIANDO TREINAMENTO INTELIGENTE ---")
    print(" Isso pode demorar dependendo do seu hardware.")
    
    # 3. Treinar o modelo
    results = model.train(
        data=data_path,
        epochs=10,
        imgsz=320,
        batch=16,
        name='plant_disease_model',
        device='cpu' # Mude para '0' se tiver GPU NVIDIA
    )
    
    print("--- TREINAMENTO CONCLUÍDO ---")
    
    # 4. Copiar o arquivo best.pt gerado para a pasta raiz automaticamente
    generated_best_path = os.path.join(results.save_dir, 'weights', 'best.pt')
    target_best_path = os.path.join(os.getcwd(), 'best.pt')
    
    if os.path.exists(generated_best_path):
        shutil.copy(generated_best_path, target_best_path)
        print(f" [+] SUCESSO: O melhor modelo foi copiado para: {target_best_path}")
    else:
        print(f" [!] AVISO: Não foi possível encontrar o arquivo gerado em {generated_best_path}")

if __name__ == "__main__":
    train_model()