import os
import shutil
import json
from ultralytics import YOLO

def on_train_epoch_end(trainer):
    """Callback para registrar o progresso de cada época em um arquivo JSON."""
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
    # Limpa progresso anterior
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
    
    # Adiciona o callback
    model.add_callback("on_train_epoch_end", on_train_epoch_end)
    
    results = model.train(
        data=data_path,
        epochs=10,
        imgsz=320,
        batch=16,
        name='plant_disease_model',
        device='cpu',
        verbose=True
    )
    
    print("--- TREINAMENTO CONCLUÍDO ---")
    
    # Finaliza o arquivo de progresso
    with open("training_progress.json", "w") as f:
        json.dump({"status": "Concluído", "progress": 1.0}, f)
        
    generated_best_path = os.path.join(results.save_dir, 'weights', 'best.pt')
    target_best_path = os.path.join(os.getcwd(), 'best.pt')
    
    if os.path.exists(generated_best_path):
        shutil.copy(generated_best_path, target_best_path)
        print(f" [+] SUCESSO: O melhor modelo foi copiado para: {target_best_path}")
    else:
        print(f" [!] AVISO: Não foi possível encontrar o arquivo gerado em {generated_best_path}")

if __name__ == "__main__":
    train_model()
