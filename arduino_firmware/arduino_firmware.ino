#include <ArduinoJson.hpp>
#include <SPI.h>
#include <MFRC522.h>

// Definição dos Pinos RFID
#define SS_PIN 10
#define RST_PIN 9
MFRC522 rfid(SS_PIN, RST_PIN);

// Definição dos Pinos de Controle Físico
const int PIN_POT         = A0; // Potenciômetro para regular luz
const int PIN_LUZ_FISICA  = 6;  // Saída PWM para os LEDs da plantação
const int PIN_LED_STATUS  = 7;  // LED que indica se está liberado (VERDE) ou bloqueado (VERMELHO/OFF)

// Pinos dos Sensores (A1 a A7)
const int S_UMIDADE_1 = A1;
const int S_UMIDADE_2 = A2;
const int S_LUZ_1     = A3;
const int S_LUZ_2     = A4;
const int S_TEMP_1    = A5;
const int S_TEMP_2    = A6; // Disponível em Nano/Mega
const int S_PH_1      = A7; // Disponível em Nano/Mega

// Atuadores
const int PIN_BOMBA   = 8; 

// Estado do Sistema
bool isAccessGranted = false;
int currentLightIntensity = 0;

void setup() {
  Serial.begin(9600);
  SPI.begin();           // Inicializa barramento SPI
  rfid.PCD_Init();       // Inicializa módulo RC522

  pinMode(PIN_BOMBA, OUTPUT);
  pinMode(PIN_LUZ_FISICA, OUTPUT);
  pinMode(PIN_LED_STATUS, OUTPUT);

  digitalWrite(PIN_BOMBA, LOW);
  digitalWrite(PIN_LED_STATUS, LOW);
  analogWrite(PIN_LUZ_FISICA, 0);

  Serial.println("Sistema PlantGuard Iniciado...");
  Serial.println("Aproxime o cartão RFID para liberar o controle de luz.");
}

void loop() {
  // 1. Lógica de Acesso RFID
  if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
    isAccessGranted = !isAccessGranted; // Alterna acesso ao detectar cartão
    digitalWrite(PIN_LED_STATUS, isAccessGranted ? HIGH : LOW);
    
    Serial.print("Controle ");
    Serial.println(isAccessGranted ? "LIBERADO" : "BLOQUEADO");
    
    rfid.PICC_HaltA(); // Para leitura do cartão
    rfid.PCD_StopCrypto1();
  }

  // 2. Lógica do Potenciômetro (Apenas se liberado)
  if (isAccessGranted) {
    int potVal = analogRead(PIN_POT);
    currentLightIntensity = map(potVal, 0, 1023, 0, 255);
    analogWrite(PIN_LUZ_FISICA, currentLightIntensity);
  }

  // 3. Verificar Comandos Serial (Bomba)
  if (Serial.available() > 0) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    
    if (cmd == "B1") {
      digitalWrite(PIN_BOMBA, HIGH);
    } else if (cmd == "B0") {
      digitalWrite(PIN_BOMBA, LOW);
    }
  }

  // 4. Leitura dos sensores
  int valU1 = analogRead(S_UMIDADE_1);
  int valU2 = analogRead(S_UMIDADE_2);
  int valL1 = analogRead(S_LUZ_1);
  int valL2 = analogRead(S_LUZ_2);
  int valT1 = analogRead(S_TEMP_1);
  int valT2 = analogRead(S_TEMP_2);
  int valP1 = analogRead(S_PH_1);

  // 5. Conversões
  float umidade1 = map(valU1, 1023, 200, 0, 100);
  float umidade2 = map(valU2, 1023, 200, 0, 100);
  float luz1     = map(valL1, 0, 1023, 0, 100);
  float luz2     = map(valL2, 0, 1023, 0, 100);
  float temp1    = (valT1 * 5.0 * 100.0) / 1024.0;
  float temp2    = (valT2 * 5.0 * 100.0) / 1024.0;
  float ph1      = map(valP1, 0, 1023, 0, 1400) / 100.0;

  // 6. Reporte JSON
  StaticJsonDocument<512> doc;
  doc["u1"] = umidade1;
  doc["u2"] = umidade2;
  doc["l1"] = luz1;
  doc["l2"] = luz2;
  doc["t1"] = temp1;
  doc["t2"] = temp2;
  doc["p1"] = ph1;
  doc["locked"] = !isAccessGranted;
  doc["light_int"] = map(currentLightIntensity, 0, 255, 0, 100); // % de intensidade

  serializeJson(doc, Serial);
  Serial.println();

  delay(500); // Reduzido delay para melhor resposta do RFID e Pot
}
