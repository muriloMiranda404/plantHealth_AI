#include <ArduinoJson.h>

// Definição dos Pinos (A0 a A7)
const int S_UMIDADE_1 = A0;
const int S_UMIDADE_2 = A1;
const int S_LUZ_1     = A2;
const int S_LUZ_2     = A3;
const int S_TEMP_1    = A4;
const int S_TEMP_2    = A5;
const int S_PH_1      = A6;
const int S_PH_2      = A7;

// Atuadores
const int PIN_BOMBA   = 8; 

void setup() {
  Serial.begin(9600);
  pinMode(PIN_BOMBA, OUTPUT);
  digitalWrite(PIN_BOMBA, LOW); // Inicia desligada
}

void loop() {
  // 0. Verificar Comandos Serial 
  if (Serial.available() > 0) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    
    if (cmd == "B1") {
      digitalWrite(PIN_BOMBA, HIGH);
    } else if (cmd == "B0") {
      digitalWrite(PIN_BOMBA, LOW);
    }
  }

  // 1. Leitura dos sensores
  int valU1 = analogRead(S_UMIDADE_1);
  int valU2 = analogRead(S_UMIDADE_2);
  int valL1 = analogRead(S_LUZ_1);
  int valL2 = analogRead(S_LUZ_2);
  int valT1 = analogRead(S_TEMP_1);
  int valT2 = analogRead(S_TEMP_2);
  int valP1 = analogRead(S_PH_1);
  int valP2 = analogRead(S_PH_2);

  // 2. Conversões (Exemplos genéricos - ajuste conforme seus sensores)
  float umidade1 = map(valU1, 1023, 200, 0, 100);
  float umidade2 = map(valU2, 1023, 200, 0, 100);
  float luz1     = map(valL1, 0, 1023, 0, 100);
  float luz2     = map(valL2, 0, 1023, 0, 100);
  
  // Conversão simples para Temperatura 
  float temp1    = (valT1 * 5.0 * 100.0) / 1024.0;
  float temp2    = (valT2 * 5.0 * 100.0) / 1024.0;
  
  // Conversão para pH (escala 0 a 14)
  float ph1      = map(valP1, 0, 1023, 0, 1400) / 100.0;
  float ph2      = map(valP2, 0, 1023, 0, 1400) / 100.0;

  StaticJsonDocument<512> doc;
  doc["u1"] = umidade1;
  doc["u2"] = umidade2;
  doc["l1"] = luz1;
  doc["l2"] = luz2;
  doc["t1"] = temp1;
  doc["t2"] = temp2;
  doc["p1"] = ph1;
  doc["p2"] = ph2;

  serializeJson(doc, Serial);
  Serial.println();

  delay(2000); 
}
