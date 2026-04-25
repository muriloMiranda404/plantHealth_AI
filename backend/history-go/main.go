package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"
)

type SensorLog struct {
	Key       string  `json:"key"`
	Value     float64 `json:"value"`
	Timestamp int64   `json:"timestamp"`
}

var (
	history []SensorLog
	mutex   sync.Mutex
)

func main() {
	http.HandleFunc("/log", handleLog)
	http.HandleFunc("/history", handleGetHistory)

	fmt.Println("Microserviço de Histórico em Go rodando na porta 8080...")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func handleLog(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Método não permitido", http.StatusMethodNotAllowed)
		return
	}

	var entry SensorLog
	if err := json.NewDecoder(r.Body).Decode(&entry); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	entry.Timestamp = time.Now().UnixMilli()

	mutex.Lock()
	history = append(history, entry)
	if len(history) > 1000 { // Limite de 1000 registros em memória para este exemplo
		history = history[1:]
	}
	mutex.Unlock()

	w.WriteHeader(http.StatusCreated)
}

func handleGetHistory(w http.ResponseWriter, r *http.Request) {
	mutex.Lock()
	defer mutex.Unlock()
	json.NewEncoder(w).Encode(history)
}
