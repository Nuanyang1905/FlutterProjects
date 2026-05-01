#include <LiquidCrystal_I2C.h>
#include <Wire.h>
#include <SoftwareSerial.h>
#include <EEPROM.h>
#include <avr/wdt.h>

// ================== Pin Mapping ==================
const uint8_t RELAY_PIN = 8;
const uint8_t SENSOR_PIN = A0;
const uint8_t ESP_RX = 13;
const uint8_t ESP_TX = 12;

// ================== Sensor Calibration ==================
const int AIR_VALUE = 1023;
const int WATER_VALUE = 0;
const int SENSOR_FAULT_RAW_LOW = 5;
const uint8_t SENSOR_FAULT_SAMPLE_LIMIT = 3;

// ================== Timing ==================
const unsigned long SENSOR_READ_INTERVAL = 1000UL;
const unsigned long LCD_REFRESH_INTERVAL = 500UL;
const unsigned long STATUS_REPORT_INTERVAL = 2000UL;
const unsigned long PUMP_MAX_RUNTIME = 60000UL;
const unsigned long PUMP_TOGGLE_COOLDOWN = 2000UL;
const unsigned long MANUAL_TIMEOUT = 43200000UL;

// ================== EEPROM Layout ==================
const uint8_t EEPROM_MAGIC_BYTE = 0x5A;
const uint8_t EEPROM_VERSION = 2;
const int EEPROM_ADDR_CONFIG = 0;

struct PersistedConfig {
  uint8_t magic;
  uint8_t version;
  uint8_t thresholdLow;
  uint8_t thresholdHigh;
  uint8_t checksum;
};

// ================== Objects ==================
LiquidCrystal_I2C lcd(0x27, 16, 2);
SoftwareSerial espSerial(ESP_RX, ESP_TX);

// ================== System State ==================
enum ControlMode : uint8_t {
  MODE_MANUAL = 0,
  MODE_AUTO = 1,
};

ControlMode controlMode = MODE_AUTO;

bool pumpState = false;
bool targetPumpState = false;
bool sensorOk = true;
bool protectionLocked = false;

int lastRawValue = 0;
int filteredRawValue = 0;
int moisturePercent = 0;
int thresholdLow = 30;
int thresholdHigh = 60;

bool filterInitialized = false;
uint8_t sensorFaultSamples = 0;
bool statusDirty = true;

unsigned long lastSensorReadAt = 0;
unsigned long lastDisplayAt = 0;
unsigned long lastStatusAt = 0;
unsigned long pumpStartedAt = 0;
unsigned long lastPumpToggleAt = 0;
unsigned long manualModeStartedAt = 0;

char lineBuffer[128];
size_t lineLength = 0;

// ================== Utility ==================
void trimInPlace(char* s) {
  size_t len = strlen(s);
  size_t start = 0;
  while (start < len &&
         (s[start] == ' ' || s[start] == '\t' || s[start] == '\r' ||
          s[start] == '\n')) {
    start++;
  }

  size_t end = len;
  while (end > start &&
         (s[end - 1] == ' ' || s[end - 1] == '\t' || s[end - 1] == '\r' ||
          s[end - 1] == '\n')) {
    end--;
  }

  size_t writeIndex = 0;
  for (size_t i = start; i < end; i++) {
    s[writeIndex++] = s[i];
  }
  s[writeIndex] = '\0';
}

void toLowerInPlace(char* s) {
  while (*s) {
    if (*s >= 'A' && *s <= 'Z') {
      *s = *s - 'A' + 'a';
    }
    s++;
  }
}

uint8_t calculateConfigChecksum(
  uint8_t version,
  uint8_t low,
  uint8_t high
) {
  return static_cast<uint8_t>(EEPROM_MAGIC_BYTE ^ version ^ low ^ high ^ 0xA5);
}

bool jsonGetString(
  const char* json,
  const char* key,
  char* out,
  size_t outSize
) {
  char pattern[24];
  snprintf(pattern, sizeof(pattern), "\"%s\"", key);

  const char* pos = strstr(json, pattern);
  if (pos == nullptr) {
    return false;
  }

  pos = strchr(pos + strlen(pattern), ':');
  if (pos == nullptr) {
    return false;
  }
  pos++;

  while (*pos == ' ' || *pos == '\t') {
    pos++;
  }
  if (*pos != '"') {
    return false;
  }
  pos++;

  size_t index = 0;
  while (*pos != '\0' && *pos != '"' && index < outSize - 1) {
    out[index++] = *pos++;
  }
  out[index] = '\0';

  return index > 0;
}

bool jsonGetInt(const char* json, const char* key, int* out) {
  char pattern[24];
  snprintf(pattern, sizeof(pattern), "\"%s\"", key);

  const char* pos = strstr(json, pattern);
  if (pos == nullptr) {
    return false;
  }

  pos = strchr(pos + strlen(pattern), ':');
  if (pos == nullptr) {
    return false;
  }
  pos++;

  while (*pos == ' ' || *pos == '\t') {
    pos++;
  }

  *out = static_cast<int>(strtol(pos, nullptr, 10));
  return true;
}

int clampPercent(int value) {
  if (value < 0) {
    return 0;
  }
  if (value > 100) {
    return 100;
  }
  return value;
}

bool buildLegacyThresholdPair(int value, int* outLow, int* outHigh) {
  int low = clampPercent(value);
  int high = clampPercent(value + 20);

  if (high <= low) {
    if (low >= 100) {
      low = 99;
      high = 100;
    } else {
      high = low + 1;
    }
  }

  *outLow = low;
  *outHigh = high;
  return true;
}

void markStatusDirty() {
  statusDirty = true;
}

// ================== Persistence ==================
void saveThresholds() {
  PersistedConfig config;
  config.magic = EEPROM_MAGIC_BYTE;
  config.version = EEPROM_VERSION;
  config.thresholdLow = static_cast<uint8_t>(thresholdLow);
  config.thresholdHigh = static_cast<uint8_t>(thresholdHigh);
  config.checksum = calculateConfigChecksum(
    config.version,
    config.thresholdLow,
    config.thresholdHigh
  );
  EEPROM.put(EEPROM_ADDR_CONFIG, config);
}

void loadThresholds() {
  PersistedConfig config;
  EEPROM.get(EEPROM_ADDR_CONFIG, config);

  const bool valid = config.magic == EEPROM_MAGIC_BYTE &&
      config.version == EEPROM_VERSION &&
      config.checksum == calculateConfigChecksum(
        config.version,
        config.thresholdLow,
        config.thresholdHigh
      ) &&
      config.thresholdLow < config.thresholdHigh &&
      config.thresholdHigh <= 100;

  if (valid) {
    thresholdLow = config.thresholdLow;
    thresholdHigh = config.thresholdHigh;
  } else {
    thresholdLow = 30;
    thresholdHigh = 60;
    saveThresholds();
  }
}

bool setThresholds(int low, int high) {
  if (low < 0 || low > 100 || high < 0 || high > 100 || low >= high) {
    return false;
  }

  thresholdLow = low;
  thresholdHigh = high;
  saveThresholds();
  return true;
}

// ================== Control ==================
void clearProtectionLock() {
  if (protectionLocked) {
    protectionLocked = false;
    markStatusDirty();
  }
}

void evaluateAutoControl() {
  if (controlMode != MODE_AUTO) {
    return;
  }

  if (!sensorOk || protectionLocked) {
    targetPumpState = false;
    return;
  }

  if (moisturePercent < thresholdLow) {
    targetPumpState = true;
  } else if (moisturePercent > thresholdHigh) {
    targetPumpState = false;
  }
}

void enterManualMode(unsigned long now) {
  if (controlMode != MODE_MANUAL) {
    markStatusDirty();
  }
  controlMode = MODE_MANUAL;
  manualModeStartedAt = now;
}

void enterAutoMode() {
  if (controlMode != MODE_AUTO) {
    markStatusDirty();
  }
  controlMode = MODE_AUTO;
  evaluateAutoControl();
}

void requestPumpState(bool on, unsigned long now) {
  enterManualMode(now);

  if (on && protectionLocked) {
    targetPumpState = false;
    return;
  }

  targetPumpState = on;
}

// ================== Command Handling ==================
bool handleThresholdPair(int low, int high) {
  if (!setThresholds(low, high)) {
    return false;
  }
  markStatusDirty();
  evaluateAutoControl();
  return true;
}

bool handleJsonCommand(char* payload, unsigned long now) {
  char cmd[20];
  char value[20];
  int low = 0;
  int high = 0;
  int single = 0;

  if (!jsonGetString(payload, "cmd", cmd, sizeof(cmd))) {
    return false;
  }
  toLowerInPlace(cmd);

  if (strcmp(cmd, "pump") == 0) {
    if (!jsonGetString(payload, "value", value, sizeof(value))) {
      return false;
    }
    toLowerInPlace(value);

    if (strcmp(value, "on") == 0) {
      requestPumpState(true, now);
      return true;
    }
    if (strcmp(value, "off") == 0) {
      requestPumpState(false, now);
      return true;
    }
    return false;
  }

  if (strcmp(cmd, "mode") == 0) {
    if (!jsonGetString(payload, "value", value, sizeof(value))) {
      return false;
    }
    toLowerInPlace(value);

    if (strcmp(value, "auto") == 0) {
      enterAutoMode();
      return true;
    }
    if (strcmp(value, "manual") == 0) {
      enterManualMode(now);
      return true;
    }
    return false;
  }

  if (strcmp(cmd, "threshold") == 0) {
    if (jsonGetInt(payload, "low", &low) && jsonGetInt(payload, "high", &high)) {
      return handleThresholdPair(low, high);
    }

    if (jsonGetInt(payload, "value", &single)) {
      buildLegacyThresholdPair(single, &low, &high);
      return handleThresholdPair(low, high);
    }
    return false;
  }

  if (strcmp(cmd, "unlock") == 0) {
    clearProtectionLock();
    evaluateAutoControl();
    return true;
  }

  return false;
}

bool handleTextCommand(char* cmd, unsigned long now) {
  trimInPlace(cmd);
  toLowerInPlace(cmd);

  if (cmd[0] == '\0') {
    return false;
  }

  if (strcmp(cmd, "on") == 0 || strcmp(cmd, "cmd:pump_on") == 0) {
    requestPumpState(true, now);
    return true;
  }

  if (strcmp(cmd, "off") == 0 || strcmp(cmd, "cmd:pump_off") == 0) {
    requestPumpState(false, now);
    return true;
  }

  if (strcmp(cmd, "auto") == 0 || strcmp(cmd, "cmd:pump_auto") == 0) {
    enterAutoMode();
    return true;
  }

  if (strcmp(cmd, "manual") == 0 || strcmp(cmd, "cmd:manual") == 0) {
    enterManualMode(now);
    return true;
  }

  if (strcmp(cmd, "unlock") == 0 || strcmp(cmd, "cmd:unlock") == 0) {
    clearProtectionLock();
    evaluateAutoControl();
    return true;
  }

  if (strncmp(cmd, "set:", 4) == 0) {
    char* pair = cmd + 4;
    char* comma = strchr(pair, ',');
    if (comma == nullptr) {
      return false;
    }

    *comma = '\0';
    const int low = atoi(pair);
    const int high = atoi(comma + 1);
    return handleThresholdPair(low, high);
  }

  if (strncmp(cmd, "cmd:set:", 8) == 0) {
    return handleTextCommand(cmd + 4, now);
  }

  if (strncmp(cmd, "t:", 2) == 0) {
    int low = 0;
    int high = 0;
    buildLegacyThresholdPair(atoi(cmd + 2), &low, &high);
    return handleThresholdPair(low, high);
  }

  if (strncmp(cmd, "cmd:t:", 6) == 0) {
    return handleTextCommand(cmd + 4, now);
  }

  return false;
}

void processIncomingLine(char* line, unsigned long now) {
  trimInPlace(line);
  if (line[0] == '\0') {
    return;
  }

  if (line[0] == '{' && handleJsonCommand(line, now)) {
    return;
  }

  handleTextCommand(line, now);
}

void handleEspInput(unsigned long now) {
  while (espSerial.available() > 0) {
    const char incoming = static_cast<char>(espSerial.read());

    if (incoming == '\r') {
      continue;
    }

    if (incoming == '\n') {
      lineBuffer[lineLength] = '\0';
      processIncomingLine(lineBuffer, now);
      lineLength = 0;
      continue;
    }

    if (lineLength < sizeof(lineBuffer) - 1) {
      lineBuffer[lineLength++] = incoming;
    } else {
      lineLength = 0;
    }
  }
}

// ================== Sensor / Pump ==================
void readSensorAndLogic(unsigned long now) {
  if (now - lastSensorReadAt < SENSOR_READ_INTERVAL) {
    return;
  }
  lastSensorReadAt = now;

  lastRawValue = analogRead(SENSOR_PIN);
  if (!filterInitialized) {
    filteredRawValue = lastRawValue;
    filterInitialized = true;
  } else {
    filteredRawValue = (filteredRawValue * 4 + lastRawValue) / 5;
  }

  if (filteredRawValue <= SENSOR_FAULT_RAW_LOW) {
    if (sensorFaultSamples < 255) {
      sensorFaultSamples++;
    }
  } else {
    sensorFaultSamples = 0;
  }

  const bool previousSensorOk = sensorOk;
  sensorOk = sensorFaultSamples < SENSOR_FAULT_SAMPLE_LIMIT;

  if (previousSensorOk != sensorOk) {
    markStatusDirty();
  }

  if (!sensorOk) {
    moisturePercent = 0;
    if (controlMode == MODE_AUTO) {
      targetPumpState = false;
    }
    return;
  }

  moisturePercent = constrain(
    map(filteredRawValue, AIR_VALUE, WATER_VALUE, 0, 100),
    0,
    100
  );

  evaluateAutoControl();
}

void updateManualTimeout(unsigned long now) {
  if (controlMode == MODE_MANUAL &&
      now - manualModeStartedAt >= MANUAL_TIMEOUT) {
    enterAutoMode();
  }
}

void updatePumpHardware(unsigned long now) {
  if (pumpState && now - pumpStartedAt >= PUMP_MAX_RUNTIME) {
    targetPumpState = false;
    if (!protectionLocked) {
      protectionLocked = true;
      markStatusDirty();
    }
  }

  if (protectionLocked && targetPumpState) {
    targetPumpState = false;
  }

  if (targetPumpState == pumpState) {
    return;
  }

  if (now - lastPumpToggleAt < PUMP_TOGGLE_COOLDOWN) {
    return;
  }

  pumpState = targetPumpState;
  lastPumpToggleAt = now;
  digitalWrite(RELAY_PIN, pumpState ? HIGH : LOW);
  markStatusDirty();

  if (pumpState) {
    pumpStartedAt = now;
  } else {
    pumpStartedAt = 0;
  }
}

// ================== LCD / Status ==================
void refreshLCD(unsigned long now) {
  if (now - lastDisplayAt < LCD_REFRESH_INTERVAL) {
    return;
  }
  lastDisplayAt = now;

  char line1[17];
  char line2[17];

  if (!sensorOk) {
    snprintf(line1, sizeof(line1), "Sensor Fault    ");
  } else {
    snprintf(line1, sizeof(line1), "Soil:%3d%% R%4d", moisturePercent, filteredRawValue);
  }

  snprintf(
    line2,
    sizeof(line2),
    "%s P:%s %s",
    controlMode == MODE_AUTO ? "AUTO" : "MAN ",
    pumpState ? "ON " : "OFF",
    protectionLocked ? "LOCK" : "    "
  );

  lcd.setCursor(0, 0);
  lcd.print(line1);
  lcd.setCursor(0, 1);
  lcd.print(line2);
}

void sendStatusToBridge(unsigned long now) {
  if (!statusDirty && now - lastStatusAt < STATUS_REPORT_INTERVAL) {
    return;
  }
  lastStatusAt = now;

  char payload[196];
  snprintf(
    payload,
    sizeof(payload),
    "{\"ver\":2,\"type\":\"status\",\"hum\":%d,\"raw\":%d,\"pump\":%d,\"mode\":\"%s\",\"th_low\":%d,\"th_high\":%d,\"lock\":%d,\"sensor_ok\":%d}",
    sensorOk ? moisturePercent : 0,
    filteredRawValue,
    pumpState ? 1 : 0,
    controlMode == MODE_AUTO ? "auto" : "manual",
    thresholdLow,
    thresholdHigh,
    protectionLocked ? 1 : 0,
    sensorOk ? 1 : 0
  );

  espSerial.println(payload);
  statusDirty = false;
}

// ================== Setup / Loop ==================
void setup() {
  Serial.begin(9600);
  espSerial.begin(9600);

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);

  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Smart Watering  ");
  lcd.setCursor(0, 1);
  lcd.print("Booting...      ");

  loadThresholds();

  lastRawValue = analogRead(SENSOR_PIN);
  filteredRawValue = lastRawValue;
  filterInitialized = true;
  manualModeStartedAt = millis();

  wdt_enable(WDTO_8S);
}

void loop() {
  wdt_reset();

  const unsigned long now = millis();

  handleEspInput(now);
  updateManualTimeout(now);
  readSensorAndLogic(now);
  updatePumpHardware(now);
  refreshLCD(now);
  sendStatusToBridge(now);
}
