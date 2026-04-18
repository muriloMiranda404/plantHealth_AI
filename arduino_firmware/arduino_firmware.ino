#include <ArduinoJson.h>
#include <SPI.h>
#include <MFRC522.h>
#include <EEPROM.h>

#define SS_PIN 10
#define RST_PIN 9
MFRC522 rfid(SS_PIN, RST_PIN);

struct SensorConfig {
  char id[4];
  int pin;
  bool enabled;
};

SensorConfig sensors[] = {
  {"u1", A1, true},
  {"u2", A2, true},
  {"l1", A3, true},
  {"l2", A4, true},
  {"t1", A5, true},
  {"t2", A6, true},
  {"p1", A7, true}
};
const int numSensors = 7;

byte masterUID[4] = {0x00, 0x00, 0x00, 0x00};
bool isAccessGranted = false;
bool registerMode = false;

const int PIN_POT         = A0; 
const int PIN_LUZ_FISICA  = 6;  
const int PIN_LED_STATUS  = 7;  
const int PIN_BOMBA       = 8; 

int currentLightIntensity = 0;

void saveConfigs() {
  int addr = 0;
  for (int i = 0; i < numSensors; i++) {
    EEPROM.put(addr, sensors[i]);
    addr += sizeof(SensorConfig);
  }
  EEPROM.put(addr, masterUID);
}

void loadConfigs() {
  int addr = 0;
  for (int i = 0; i < numSensors; i++) {
    EEPROM.get(addr, sensors[i]);
    addr += sizeof(SensorConfig);
  }
  EEPROM.get(addr, masterUID);
}

void setup() {
  Serial.begin(9600);
  SPI.begin();
  rfid.PCD_Init();

  pinMode(PIN_BOMBA, OUTPUT);
  pinMode(PIN_LUZ_FISICA, OUTPUT);
  pinMode(PIN_LED_STATUS, OUTPUT);

  digitalWrite(PIN_BOMBA, LOW);
  digitalWrite(PIN_LED_STATUS, LOW);
  analogWrite(PIN_LUZ_FISICA, 0);

  loadConfigs();

  Serial.println("{\"msg\":\"Sistema PlantGuard Online\"}");
}

void loop() {
  if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
    if (registerMode) {
      for (byte i = 0; i < 4; i++) masterUID[i] = rfid.uid.uidByte[i];
      saveConfigs();
      registerMode = false;
      Serial.println("{\"msg\":\"Novo RFID registrado\"}");
    } else {
      bool match = true;
      bool allZeros = true;
      for (byte i = 0; i < 4; i++) {
        if (masterUID[i] != 0x00) allZeros = false;
        if (rfid.uid.uidByte[i] != masterUID[i]) match = false;
      }

      if (allZeros) match = true;

      Serial.print("{\"event\":\"rfid_detected\",\"uid\":\"");
      for (byte i = 0; i < rfid.uid.size; i++) {
        Serial.print(rfid.uid.uidByte[i] < 0x10 ? "0" : "");
        Serial.print(rfid.uid.uidByte[i], HEX);
      }
      Serial.print("\",\"match\":");
      Serial.print(match ? "true" : "false");
      Serial.println("}");

      if (match) {
        isAccessGranted = !isAccessGranted;
        digitalWrite(PIN_LED_STATUS, isAccessGranted ? HIGH : LOW);
      }
    }
    
    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();
  }

  if (isAccessGranted) {
    int potVal = analogRead(PIN_POT);
    currentLightIntensity = map(potVal, 0, 1023, 0, 255);
    analogWrite(PIN_LUZ_FISICA, currentLightIntensity);
  }

  if (Serial.available() > 0) {
    String input = Serial.readStringUntil('\n');
    input.trim();

    if (input.startsWith("{")) {
      StaticJsonDocument<256> doc;
      DeserializationError error = deserializeJson(doc, input);
      if (!error) {
        if (doc.containsKey("cfg")) {
          const char* id = doc["cfg"]["id"];
          JsonVariant pinVar = doc["cfg"]["pin"];
          bool enabled = doc["cfg"]["enabled"];
          
          int finalPin = -1;
          if (pinVar.is<int>()) {
            finalPin = pinVar.as<int>();
          } else if (pinVar.is<const char*>()) {
            const char* pinStr = pinVar.as<const char*>();
            if (pinStr[0] == 'A' || pinStr[0] == 'a') {
              finalPin = A0 + atoi(pinStr + 1);
            } else {
              finalPin = atoi(pinStr);
            }
          }

          if (finalPin != -1) {
            for (int i = 0; i < numSensors; i++) {
              if (strcmp(sensors[i].id, id) == 0) {
                sensors[i].pin = finalPin;
                sensors[i].enabled = enabled;
                saveConfigs();
                Serial.println("{\"msg\":\"Configuracao atualizada\",\"id\":\"" + String(id) + "\",\"pin\":" + String(finalPin) + "}");
                break;
              }
            }
          }
        } else if (doc.containsKey("cmd")) {
          const char* cmd = doc["cmd"];
          if (strcmp(cmd, "register_rfid") == 0) {
            registerMode = true;
            Serial.println("{\"msg\":\"Aproxime o novo cartao\"}");
          }
        }
      }
    } else {
      if (input == "B1") digitalWrite(PIN_BOMBA, HIGH);
      else if (input == "B0") digitalWrite(PIN_BOMBA, LOW);
    }
  }

  StaticJsonDocument<512> report;
  for (int i = 0; i < numSensors; i++) {
    if (sensors[i].enabled) {
      int val = analogRead(sensors[i].pin);
      float converted = 0;
      
      if (sensors[i].id[0] == 'u') converted = map(val, 1023, 200, 0, 100);
      else if (sensors[i].id[0] == 'l') converted = map(val, 0, 1023, 0, 100);
      else if (sensors[i].id[0] == 't') converted = (val * 5.0 * 100.0) / 1024.0;
      else if (sensors[i].id[0] == 'p') converted = map(val, 0, 1023, 0, 1400) / 100.0;
      
      report[sensors[i].id] = converted;
    }
  }

  report["locked"] = !isAccessGranted;
  report["light_int"] = map(currentLightIntensity, 0, 255, 0, 100);

  serializeJson(report, Serial);
  Serial.println();

  delay(500);
}

