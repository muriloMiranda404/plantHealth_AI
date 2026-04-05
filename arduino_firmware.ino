#include <ArduinoJson.h> // Instale a biblioteca "ArduinoJson" pelo gerenciador

const int SENSOR_UMIDADE = A0;
const int SENSOR_LUZ = A1;

void setup() {
  Serial.begin(9600);
}

void loop() {
  // 1. Ler sensores
  int valorUmidade = analogRead(SENSOR_UMIDADE);
  int valorLuz = analogRead(SENSOR_LUZ);

  // Converter para porcentagem (exemplo genérico)
  float percUmidade = map(valorUmidade, 1023, 200, 0, 100); 
  float percLuz = map(valorLuz, 0, 1023, 0, 100);

  // 2. Criar JSON para enviar para a Raspberry Pi
  StaticJsonDocument<200> doc;
  doc["umidade"] = percUmidade;
  doc["luz"] = percLuz;

  // 3. Enviar via Serial
  serializeJson(doc, Serial);
  Serial.println(); // Nova linha para o Python identificar o fim da mensagem

  delay(2000); // Enviar dados a cada 2 segundos
}
