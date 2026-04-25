import os
import shutil
import json
from ultralytics import YOLO

def on_train_epoch_end(trainer):
    progress_file = "training_progress.json"
    epoch = trainer.epoch + 1
    total_epochs = trainer.epochs
    progress = epoch / total_epochs
    
    data = {
        "epoch": epoch,
        "total_epochs": total_epochs,
        "progress": progress,
        "status": f"Treinando Época {epoch}/{total_epochs}"
    }
    
    with open(progress_file, "w") as f:
        json.dump(data, f)
    print(f" [PROGRESS] {data['status']} - {progress*100:.1f}%")

def train_model():
    if os.path.exists("training_progress.json"):
        os.remove("training_progress.json")
        
    model = YOLO('yolov8n.pt')
    data_path = os.path.join(os.getcwd(), 'data.yaml')
    
    if not os.path.exists(data_path):
        error_msg = f" [!] ERRO: Arquivo {data_path} não encontrado!"
        print(error_msg)
        with open("training_progress.json", "w") as f:
            json.dump({"status": "Erro: data.yaml não encontrado", "progress": 0}, f)
        return

    print("--- INICIANDO TREINAMENTO INTELIGENTE ---")
    
    model.add_callback("on_train_epoch_end", on_train_epoch_end)
    
    import torch
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    print(f"--- USANDO DISPOSITIVO: {device.upper()} ---")

    results = model.train(
        data=data_path,
        epochs=100,
        imgsz=416,
        batch=-1,
        patience=20,
        workers=8,
        device=device,
        amp=True,
        name='plant_disease_model',
        verbose=True
    )
    
    print("--- TREINAMENTO CONCLUÍDO ---")
    
    with open("training_progress.json", "w") as f:
        json.dump({"status": "Concluído", "progress": 1.0}, f)
        
    generated_best_path = os.path.join(results.save_dir, 'weights', 'best.pt')
    target_best_path = os.path.join(os.getcwd(), 'best.pt')
    
    if os.path.exists(generated_best_path):
        try:
            if os.path.exists(target_best_path):
                os.remove(target_best_path)
            
            shutil.copy2(generated_best_path, target_best_path)
            print(f" [+] SUCESSO: O melhor modelo foi copiado para: {target_best_path}")
        except Exception as e:
            print(f" [!] ERRO ao copiar modelo: {e}")
            print(f" [i] Você pode encontrar o modelo manualmente em: {generated_best_path}")
    else:
        print(f" [!] AVISO: Não foi possível encontrar o arquivo gerado em {generated_best_path}")

if __name__ == "__main__":
    train_model()
