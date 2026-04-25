#include <ArduinoJson.h>
#include <SPI.h>
#include <MFRC522.h>
#include <EEPROM.h>
#include <Wire.h> 
#include <LiquidCrystal_I2C.h>

#define SS_PIN 53
#define RST_PIN 9

MFRC522 rfid(SS_PIN, RST_PIN);
LiquidCrystal_I2C lcd(0x27, 16, 2); 

struct SensorConfig {
  char id[5]; 
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
  {"v1", A7, true},
  {"ec1", A8, true},
  {"wl1", A9, true}
};

const int numSensors = 9;

byte masterUID[4] = {0x00, 0x00, 0x00, 0x00};
bool isAccessGranted = false;
bool registerMode = false;

const int PIN_LED_STATUS  = 7;  
const int PIN_BOMBA       = 8; 
const int PIN_POT         = A10; 

int currentMenuPage = 0;
bool pumpDesiredState = false; 
float currentPumpPWM = 0;      
unsigned long lastLcdUpdate = 0;
unsigned long lastPageChange = 0;
unsigned long lastRampUpdate = 0;

const int WATER_LEVEL_MIN = 15; 
const int RAMP_INTERVAL = 30;   
const float RAMP_STEP = 2.0;    

void updateLCD() {
  if (millis() - lastPageChange > 3000) { 
    currentMenuPage = (currentMenuPage + 1) % 4;
    lastPageChange = millis();
    lcd.clear();
  }

  if (millis() - lastLcdUpdate > 500) {
    lastLcdUpdate = millis();
    
    switch (currentMenuPage) {
      case 0: 
        lcd.setCursor(0, 0);
        lcd.print("PlantGuard Mega");
        lcd.setCursor(0, 1);
        lcd.print(isAccessGranted ? "Acesso: OK" : "Acesso: BLOQ");
        break;
      case 1:  
        lcd.setCursor(0, 0);
        lcd.print("U1:"); lcd.print(analogRead(A1));
        lcd.print(" U2:"); lcd.print(analogRead(A2));
        lcd.setCursor(0, 1);
        lcd.print("L1:"); lcd.print(analogRead(A3));
        lcd.print(" L2:"); lcd.print(analogRead(A4));
        break;
      case 2: 
        lcd.setCursor(0, 0);
        lcd.print("T1:"); lcd.print(analogRead(A5));
        lcd.print(" T2:"); lcd.print(analogRead(A6));
        lcd.setCursor(0, 1);
        lcd.print("V:"); lcd.print(analogRead(A7));
        lcd.print(" EC:"); lcd.print(analogRead(A8));
        break;
      case 3: 
        lcd.setCursor(0, 0);
        int waterLevel = map(analogRead(A9), 0, 1023, 0, 100);
        if (waterLevel < WATER_LEVEL_MIN) {
          lcd.print("AVISO: SEM AGUA ");
        } else {
          lcd.print("Pot. Bomba:");
          lcd.print(map(analogRead(PIN_POT), 0, 1023, 0, 100));
          lcd.print("%");
        }
        lcd.setCursor(0, 1);
        if (!isAccessGranted) {
          lcd.print("Bomba: TRAVADA ");
        } else if (waterLevel < WATER_LEVEL_MIN) {
          lcd.print("Bomba: EMERGENC.");
        } else {
          lcd.print("Bomba: PRONTA  ");
        }
        break;
    }
  }
}

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

  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Iniciando...");

  pinMode(PIN_BOMBA, OUTPUT);
  pinMode(PIN_LED_STATUS, OUTPUT);

  digitalWrite(PIN_BOMBA, LOW);
  digitalWrite(PIN_LED_STATUS, LOW);

  loadConfigs();

  Serial.println("{\"msg\":\"Sistema PlantGuard Online\"}");
}

void loop() {
  updateLCD();
  
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
      if (input == "B1") pumpDesiredState = true;
      else if (input == "B0") pumpDesiredState = false;
    }
  }

  int waterLevel = map(analogRead(A9), 0, 1023, 0, 100);
  int targetPWM = 0;

  if (isAccessGranted && pumpDesiredState && (waterLevel >= WATER_LEVEL_MIN)) {
    int potVal = analogRead(PIN_POT);
    targetPWM = map(potVal, 0, 1023, 0, 255);
  }

  if (millis() - lastRampUpdate > RAMP_INTERVAL) {
    lastRampUpdate = millis();
    if (currentPumpPWM < targetPWM) {
      currentPumpPWM += RAMP_STEP;
      if (currentPumpPWM > targetPWM) currentPumpPWM = targetPWM;
    } else if (currentPumpPWM > targetPWM) {
      currentPumpPWM -= RAMP_STEP;
      if (currentPumpPWM < targetPWM) currentPumpPWM = targetPWM;
    }
    analogWrite(PIN_BOMBA, (int)currentPumpPWM);
  }

  StaticJsonDocument<512> report;
  for (int i = 0; i < numSensors; i++) {
    if (sensors[i].enabled) {
      int val = analogRead(sensors[i].pin);
      float converted = 0;
      
      if (sensors[i].id[0] == 'u') converted = map(val, 1023, 200, 0, 100);
      else if (sensors[i].id[0] == 'l') converted = map(val, 0, 1023, 0, 100);
      else if (sensors[i].id[0] == 't') converted = (val * 5.0 * 100.0) / 1024.0;
      else if (strcmp(sensors[i].id, "v1") == 0) converted = (val * 5.0 / 1024.0) * 5.0; 
      else if (strcmp(sensors[i].id, "ec1") == 0) converted = map(val, 0, 1023, 0, 5000) / 1000.0; 
      else if (strcmp(sensors[i].id, "wl1") == 0) converted = map(val, 0, 1023, 0, 100); 
      
      report[sensors[i].id] = converted;
    }
  }

  report["locked"] = !isAccessGranted;
  report["pump_state"] = pumpDesiredState;
  report["pump_power"] = map((int)currentPumpPWM, 0, 255, 0, 100);
  report["low_water"] = (waterLevel < WATER_LEVEL_MIN);

  serializeJson(report, Serial);
  Serial.println();

  delay(500);
}
