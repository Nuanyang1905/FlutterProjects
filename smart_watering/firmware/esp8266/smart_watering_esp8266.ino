#include <ESP8266WiFi.h>
#include <PubSubClient.h>

// ======================= Required Config =======================
const char* ssid = "Redmi K70 Ultra";
const char* password = "12345678";
const char* mqttClientId = "f148fce62c08490e9ffe25b43948c5c8";
const char* baseTopic = "plant001";
// ===============================================================

const char* mqttServer = "bemfa.com";
const uint16_t mqttServerPort = 9501;

const uint8_t LED_PIN = 2;
const unsigned long WIFI_RETRY_INTERVAL = 10000UL;
const unsigned long MQTT_RETRY_INTERVAL = 5000UL;
const unsigned long REBOOT_INTERVAL = 24UL * 60UL * 60UL * 1000UL;

WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);

char statusTopic[64];
char controlTopic[64];
char serialBuffer[256];
size_t serialLength = 0;

unsigned long bootAt = 0;
unsigned long lastWiFiAttemptAt = 0;
unsigned long lastMqttAttemptAt = 0;
unsigned long lastLedBlinkAt = 0;

bool ledState = false;

// ----------------- Utility -----------------
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

void sendToArduino(const char* line) {
  Serial.println(line);
}

// ----------------- Command Normalization -----------------
bool normalizeJsonCommand(char* input, char* out, size_t outSize) {
  char cmd[20];
  char value[20];
  int low = 0;
  int high = 0;
  int single = 0;

  if (!jsonGetString(input, "cmd", cmd, sizeof(cmd))) {
    return false;
  }
  toLowerInPlace(cmd);

  if (strcmp(cmd, "pump") == 0) {
    if (!jsonGetString(input, "value", value, sizeof(value))) {
      return false;
    }
    toLowerInPlace(value);
    if (strcmp(value, "on") == 0) {
      snprintf(out, outSize, "on");
      return true;
    }
    if (strcmp(value, "off") == 0) {
      snprintf(out, outSize, "off");
      return true;
    }
    return false;
  }

  if (strcmp(cmd, "mode") == 0) {
    if (!jsonGetString(input, "value", value, sizeof(value))) {
      return false;
    }
    toLowerInPlace(value);
    if (strcmp(value, "auto") == 0 || strcmp(value, "manual") == 0) {
      snprintf(out, outSize, "%s", value);
      return true;
    }
    return false;
  }

  if (strcmp(cmd, "threshold") == 0) {
    if (jsonGetInt(input, "low", &low) && jsonGetInt(input, "high", &high)) {
      snprintf(out, outSize, "set:%d,%d", low, high);
      return true;
    }
    if (jsonGetInt(input, "value", &single)) {
      snprintf(out, outSize, "t:%d", single);
      return true;
    }
    return false;
  }

  if (strcmp(cmd, "unlock") == 0) {
    snprintf(out, outSize, "unlock");
    return true;
  }

  return false;
}

bool normalizeTextCommand(char* input, char* out, size_t outSize) {
  trimInPlace(input);
  toLowerInPlace(input);

  if (input[0] == '\0') {
    return false;
  }

  if (strcmp(input, "on") == 0 || strcmp(input, "cmd:pump_on") == 0) {
    snprintf(out, outSize, "on");
    return true;
  }

  if (strcmp(input, "off") == 0 || strcmp(input, "cmd:pump_off") == 0) {
    snprintf(out, outSize, "off");
    return true;
  }

  if (strcmp(input, "auto") == 0 || strcmp(input, "cmd:pump_auto") == 0) {
    snprintf(out, outSize, "auto");
    return true;
  }

  if (strcmp(input, "manual") == 0 || strcmp(input, "cmd:manual") == 0) {
    snprintf(out, outSize, "manual");
    return true;
  }

  if (strcmp(input, "unlock") == 0 || strcmp(input, "cmd:unlock") == 0) {
    snprintf(out, outSize, "unlock");
    return true;
  }

  if (strncmp(input, "set:", 4) == 0 || strncmp(input, "t:", 2) == 0) {
    snprintf(out, outSize, "%s", input);
    return true;
  }

  if (strncmp(input, "cmd:set:", 8) == 0 || strncmp(input, "cmd:t:", 6) == 0) {
    snprintf(out, outSize, "%s", input + 4);
    return true;
  }

  return false;
}

void processCloudPayload(char* payload) {
  trimInPlace(payload);
  if (payload[0] == '\0') {
    return;
  }

  char bridgeCommand[64];
  const bool normalized = payload[0] == '{'
      ? normalizeJsonCommand(payload, bridgeCommand, sizeof(bridgeCommand))
      : normalizeTextCommand(payload, bridgeCommand, sizeof(bridgeCommand));

  if (normalized) {
    sendToArduino(bridgeCommand);
  }
}

// ----------------- MQTT / Serial -----------------
void mqttCallback(char* topicName, byte* payload, unsigned int length) {
  if (strcmp(topicName, controlTopic) != 0) {
    return;
  }

  char message[192];
  const unsigned int copyLength =
      length < sizeof(message) - 1 ? length : sizeof(message) - 1;
  memcpy(message, payload, copyLength);
  message[copyLength] = '\0';

  processCloudPayload(message);
}

void processSerialLine(char* line) {
  trimInPlace(line);
  if (line[0] == '\0') {
    return;
  }

  if ((line[0] == '{' || line[0] == '#') && mqttClient.connected()) {
    mqttClient.publish(statusTopic, line);
  }
}

void readArduinoSerial() {
  while (Serial.available() > 0) {
    const char incoming = static_cast<char>(Serial.read());

    if (incoming == '\r') {
      continue;
    }

    if (incoming == '\n') {
      serialBuffer[serialLength] = '\0';
      processSerialLine(serialBuffer);
      serialLength = 0;
      continue;
    }

    if (serialLength < sizeof(serialBuffer) - 1) {
      serialBuffer[serialLength++] = incoming;
    } else {
      serialLength = 0;
    }
  }
}

bool connectMqtt() {
  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }

  if (!mqttClient.connect(mqttClientId)) {
    return false;
  }

  mqttClient.subscribe(controlTopic, 0);
  return true;
}

// ----------------- Connectivity -----------------
void startWiFiConnect(unsigned long now) {
  lastWiFiAttemptAt = now;
  WiFi.disconnect();
  WiFi.begin(ssid, password);
}

void ensureWiFi(unsigned long now) {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }

  if (now - lastWiFiAttemptAt >= WIFI_RETRY_INTERVAL || lastWiFiAttemptAt == 0) {
    startWiFiConnect(now);
  }
}

void ensureMqtt(unsigned long now) {
  if (WiFi.status() != WL_CONNECTED || mqttClient.connected()) {
    return;
  }

  if (now - lastMqttAttemptAt < MQTT_RETRY_INTERVAL && lastMqttAttemptAt != 0) {
    return;
  }

  lastMqttAttemptAt = now;
  if (connectMqtt()) {
    lastMqttAttemptAt = 0;
  }
}

void updateLedStatus(unsigned long now) {
  const bool wifiConnected = WiFi.status() == WL_CONNECTED;
  const bool mqttConnected = mqttClient.connected();

  if (!wifiConnected) {
    if (now - lastLedBlinkAt >= 200UL) {
      lastLedBlinkAt = now;
      ledState = !ledState;
      digitalWrite(LED_PIN, ledState ? LOW : HIGH);
    }
    return;
  }

  if (!mqttConnected) {
    if (now - lastLedBlinkAt >= 1000UL) {
      lastLedBlinkAt = now;
      ledState = !ledState;
      digitalWrite(LED_PIN, ledState ? LOW : HIGH);
    }
    return;
  }

  digitalWrite(LED_PIN, LOW);
}

// ----------------- Setup / Loop -----------------
void setup() {
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);

  Serial.begin(9600);
  Serial.setRxBufferSize(256);

  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);

  snprintf(statusTopic, sizeof(statusTopic), "%s", baseTopic);
  snprintf(controlTopic, sizeof(controlTopic), "%s/set", baseTopic);

  mqttClient.setServer(mqttServer, mqttServerPort);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setKeepAlive(60);
  mqttClient.setBufferSize(384);

  bootAt = millis();
  startWiFiConnect(bootAt);
}

void loop() {
  const unsigned long now = millis();

  ensureWiFi(now);
  ensureMqtt(now);

  if (mqttClient.connected()) {
    mqttClient.loop();
    readArduinoSerial();
  }

  updateLedStatus(now);

  if (now - bootAt >= REBOOT_INTERVAL) {
    ESP.restart();
  }

  yield();
}
