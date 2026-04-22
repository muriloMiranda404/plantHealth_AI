package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

type Alert struct {
	ID        int       `json:"id"`
	Message   string    `json:"message"`
	Type      string    `json:"type"`
	Timestamp time.Time `json:"timestamp"`
}

var alerts []Alert

func main() {
	http.HandleFunc("/alerts", handleAlerts)
	fmt.Println("Go Microservice de Alertas rodando na porta 8080...")
	http.ListenAndServe(":8080", nil)
}

func handleAlerts(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodPost {
		var newAlert Alert
		json.NewDecoder(r.Body).Decode(&newAlert)
		newAlert.ID = len(alerts) + 1
		newAlert.Timestamp = time.Now()
		alerts = append(alerts, newAlert)
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(newAlert)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(alerts)
}
