#include <WiFi.h>
#include <WiFiUdp.h>
#include <Wire.h>

#include <Adafruit_LSM6DSOX.h>
#include <Adafruit_Sensor.h>

// ===== WIFI =====
const char* WIFI_SSID = "TU_SSID";
const char* WIFI_PASS = "TU_PASSWORD";

// ===== PC IP (FIJO) =====
IPAddress PC_IP(192, 168, 1, 134);

// ===== PORTS =====
const uint16_t DATA_PORT = 5005; // PC/MATLAB recibe datos aquí
const uint16_t CTRL_PORT = 6006; // ESP32 escucha comandos aquí

// ===== I2C PINS (GPIO) =====
constexpr int SDA_PIN = 5;
constexpr int SCL_PIN = 6;

// ===== IMU I2C ADDR =====
constexpr uint8_t LSM6DSOX_ADDR = 0x6A;

WiFiUDP udpData;
WiFiUDP udpCtrl;
Adafruit_LSM6DSOX imu;

// ===== Runtime config =====
bool streaming = true;
uint32_t t0_ms = 0;
uint32_t next_us = 0;

uint32_t sendHz = 100;
uint32_t periodUs = 1000000UL / 100;

int accRangeG = 2;
int gyroRangeDps = 250;

static inline void updatePeriod() {
  if (sendHz < 1) sendHz = 1;
  if (sendHz > 104) sendHz = 104; // coherente con ODR actual
  periodUs = 1000000UL / sendHz;
}

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(WIFI_SSID, WIFI_PASS);

  uint32_t tStart = millis();
  while (WiFi.status() != WL_CONNECTED) {
    delay(250);
    if (millis() - tStart > 15000) {
      WiFi.disconnect();
      WiFi.begin(WIFI_SSID, WIFI_PASS);
      tStart = millis();
    }
  }
}

bool applyAccRange(int g) {
  switch (g) {
    case 2:  imu.setAccelRange(LSM6DS_ACCEL_RANGE_2_G); break;
    case 4:  imu.setAccelRange(LSM6DS_ACCEL_RANGE_4_G); break;
    case 8:  imu.setAccelRange(LSM6DS_ACCEL_RANGE_8_G); break;
    case 16: imu.setAccelRange(LSM6DS_ACCEL_RANGE_16_G); break;
    default: return false;
  }
  accRangeG = g;
  return true;
}

bool applyGyroRange(int dps) {
  switch (dps) {
    case 125:  imu.setGyroRange(LSM6DS_GYRO_RANGE_125_DPS); break;
    case 250:  imu.setGyroRange(LSM6DS_GYRO_RANGE_250_DPS); break;
    case 500:  imu.setGyroRange(LSM6DS_GYRO_RANGE_500_DPS); break;
    case 1000: imu.setGyroRange(LSM6DS_GYRO_RANGE_1000_DPS); break;
    case 2000: imu.setGyroRange(LSM6DS_GYRO_RANGE_2000_DPS); break;
    default: return false;
  }
  gyroRangeDps = dps;
  return true;
}

void scanI2C() {
  Serial.println("Scan I2C:");
  int found = 0;
  for (int addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.print(" 0x");
      if (addr < 16) Serial.print("0");
      Serial.println(addr, HEX);
      found++;
      delay(2);
    }
  }
  if (!found) Serial.println(" (nada)");
}

void initIMU() {
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(100000);
  delay(50);

  scanI2C();

  Serial.println("Init LSM6DSOX...");
  if (!imu.begin_I2C(LSM6DSOX_ADDR, &Wire)) {
    Serial.println("ERROR: begin_I2C falló. Revisa VIN/GND/SDA/SCL o prueba 0x6B.");
    while (1) delay(10);
  }
  Serial.println("OK IMU");

  applyAccRange(accRangeG);
  applyGyroRange(gyroRangeDps);

  imu.setAccelDataRate(LSM6DS_RATE_104_HZ);
  imu.setGyroDataRate(LSM6DS_RATE_104_HZ);
}

void reply(IPAddress ip, uint16_t port, const String& msg) {
  udpCtrl.beginPacket(ip, port);
  udpCtrl.print(msg);
  udpCtrl.endPacket();
}

String statusString() {
  String s;
  s.reserve(240);
  s += "STATUS ";
  s += "STREAM="; s += (streaming ? "1" : "0");
  s += "RATE_HZ="; s += sendHz;
  s += " ACCRANGE="; s += accRangeG;
  s += " GYRORANGE="; s += gyroRangeDps;
  s += " SDA="; s += SDA_PIN;
  s += " SCL="; s += SCL_PIN;
  s += " I2C_ADDR=0x"; s += String(LSM6DSOX_ADDR, HEX);
  s += " ESP_IP="; s += WiFi.localIP().toString();
  s += " PC_IP="; s += PC_IP.toString();
  s += " DATA_PORT="; s += DATA_PORT;
  s += " CTRL_PORT="; s += CTRL_PORT;
  return s;
}

void startStreaming() {
  streaming = true;
  t0_ms = millis();
  next_us = micros() + periodUs;
}

void stopStreaming() {
  streaming = false;
}

void handleCtrl() {
  int packetSize = udpCtrl.parsePacket();
  if (!packetSize) return;

  char buf[200];
  int len = udpCtrl.read(buf, sizeof(buf) - 1);
  if (len <= 0) return;
  buf[len] = '\0';

  String cmd = String(buf);
  cmd.trim();

  IPAddress senderIP = udpCtrl.remoteIP();
  uint16_t senderPort = udpCtrl.remotePort();

  String up = cmd;
  up.toUpperCase();

  if (up == "PING") {
    reply(senderIP, senderPort, "PONG");
    return;
  }

  if (up == "STATUS") {
    reply(senderIP, senderPort, statusString());
    return;
  }

  if (up == "START") {
    startStreaming();
    reply(senderIP, senderPort, "OK START");
    return;
  }

  if (up == "STOP") {
    stopStreaming();
    reply(senderIP, senderPort, "OK STOP");
    return;
  }

  if (up.startsWith("SET ")) {
    int p1 = cmd.indexOf(' ');
    int p2 = cmd.indexOf(' ', p1 + 1);
    if (p2 < 0) {
      reply(senderIP, senderPort, "ERR SET_FORMAT");
      return;
    }

    String key = cmd.substring(p1 + 1, p2);
    key.trim();
    key.toUpperCase();

    String val = cmd.substring(p2 + 1);
    val.trim();

    if (key == "RATE") {
      long hz = val.toInt();
      if (hz <= 0) {
        reply(senderIP, senderPort, "ERR RATE");
        return;
      }
      sendHz = (uint32_t)hz;
      updatePeriod();
      next_us = micros() + periodUs;
      reply(senderIP, senderPort, "OK RATE " + String(sendHz));
      return;
    }

    if (key == "ACCRANGE") {
      int g = val.toInt();
      if (!applyAccRange(g)) {
        reply(senderIP, senderPort, "ERR ACCRANGE");
        return;
      }
      reply(senderIP, senderPort, "OK ACCRANGE " + String(accRangeG));
      return;
    }

    if (key == "GYRORANGE") {
      int dps = val.toInt();
      if (!applyGyroRange(dps)) {
        reply(senderIP, senderPort, "ERR GYRORANGE");
        return;
      }
      reply(senderIP, senderPort, "OK GYRORANGE " + String(gyroRangeDps));
      return;
    }

    reply(senderIP, senderPort, "ERR UNKNOWN_KEY");
    return;
  }

  reply(senderIP, senderPort, "ERR UNKNOWN_CMD");
}

void setup() {
  updatePeriod();

  Serial.begin(115200);
  delay(1200);

  connectWiFi();
  Serial.print("WiFi conectado, IP: ");
  Serial.println(WiFi.localIP());

  udpCtrl.begin(CTRL_PORT);
  udpData.begin(0);

  initIMU();

  t0_ms = millis();
  next_us = micros() + periodUs;

  Serial.print("Enviando UDP a PC ");
  Serial.print(PC_IP);
  Serial.print(":");
  Serial.println(DATA_PORT);
  Serial.println("Comandos en UDP 6006: PING, STATUS, START, STOP, SET RATE <Hz>, SET ACCRANGE <2|4|8|16>, SET GYRORANGE <125|250|500|1000|2000>");
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  handleCtrl();

  if (!streaming) {
    delay(10);
    return;
  }

  uint32_t now_us = micros();
  if ((int32_t)(now_us - next_us) < 0) {
    delay(0);
    return;
  }
  next_us += periodUs;

  sensors_event_t accel, gyro, temp;
  imu.getEvent(&accel, &gyro, &temp);

  uint32_t t_ms = millis() - t0_ms;

  char msg[240];
  int n = snprintf(
    msg, sizeof(msg),
    "%lu,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.2f\n",
    (unsigned long)t_ms,
    accel.acceleration.x, accel.acceleration.y, accel.acceleration.z,
    gyro.gyro.x, gyro.gyro.y, gyro.gyro.z,
    temp.temperature
  );

  if (n > 0) {
    udpData.beginPacket(PC_IP, DATA_PORT);
    udpData.write((const uint8_t*)msg, n);
    udpData.endPacket();
  }

  static uint32_t lastLog = 0;
  static uint32_t sent = 0;
  sent++;
  if (millis() - lastLog > 1000) {
    lastLog = millis();
    Serial.print("sent/s ~");
    Serial.print(sent);
    Serial.print(" -> ");
    Serial.print(PC_IP);
    Serial.print(":");
    Serial.println(DATA_PORT);
    sent = 0;
  }
}