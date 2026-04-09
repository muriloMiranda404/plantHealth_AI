import ntcore
import time
import random

def run_mock():
    inst = ntcore.NetworkTableInstance.getDefault()
    table = inst.getTable("SmartDashboard")
    inst.startServer()

    # Publicadores para os 8 sensores
    pubs = {
        "Umid1": table.getDoubleTopic("Umid1").publish(),
        "Umid2": table.getDoubleTopic("Umid2").publish(),
        "Luz1": table.getDoubleTopic("Luz1").publish(),
        "Luz2": table.getDoubleTopic("Luz2").publish(),
        "Temp1": table.getDoubleTopic("Temp1").publish(),
        "Temp2": table.getDoubleTopic("Temp2").publish(),
        "PH1": table.getDoubleTopic("PH1").publish(),
        "PH2": table.getDoubleTopic("PH2").publish(),
    }

    print(" [MOCK] Simulador de Sensores Iniciado...")
    print(" [MOCK] Enviando dados fictícios para o App...")

    while True:
        # Gera valores aleatórios realistas
        pubs["Umid1"].set(random.uniform(60, 80))
        pubs["Umid2"].set(random.uniform(55, 75))
        pubs["Luz1"].set(random.uniform(300, 400))
        pubs["Luz2"].set(random.uniform(310, 410))
        pubs["Temp1"].set(random.uniform(24, 28))
        pubs["Temp2"].set(random.uniform(23, 27))
        pubs["PH1"].set(random.uniform(6.2, 6.8))
        pubs["PH2"].set(random.uniform(6.1, 6.7))

        time.sleep(1) # Atualiza a cada 1 segundo

if __name__ == "__main__":
    run_mock()