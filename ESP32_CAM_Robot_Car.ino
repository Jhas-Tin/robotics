#include <WiFi.h>
#include <WebServer.h>
#include "esp_camera.h"
#include "esp_http_server.h"

const char* ssid = "ESP32_CAM_Robot";
const char* password = "12345678";

#define IN1 14
#define IN2 15
#define IN3 12
#define IN4 13

#define LED_PIN   33
#define FLASH_LED 4

int speedValue = 180;   // 0–255
#define PWM_FREQ  1000
#define PWM_RES   8

WebServer server(80);
httpd_handle_t stream_httpd = NULL;

#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

void stopMotors() {
  ledcWrite(IN1, 0);
  ledcWrite(IN2, 0);
  ledcWrite(IN3, 0);
  ledcWrite(IN4, 0);
}

void forward() {
  ledcWrite(IN1, speedValue);
  ledcWrite(IN2, 0);
  ledcWrite(IN3, speedValue);
  ledcWrite(IN4, 0);
}

void backward() {
  ledcWrite(IN1, 0);
  ledcWrite(IN2, speedValue);
  ledcWrite(IN3, 0);
  ledcWrite(IN4, speedValue);
}

void left() {
  ledcWrite(IN1, 0);
  ledcWrite(IN2, speedValue);
  ledcWrite(IN3, speedValue);
  ledcWrite(IN4, 0);
}

void right() {
  ledcWrite(IN1, speedValue);
  ledcWrite(IN2, 0);
  ledcWrite(IN3, 0);
  ledcWrite(IN4, speedValue);
}

void ledOn()  { digitalWrite(LED_PIN, LOW); }
void ledOff() { digitalWrite(LED_PIN, HIGH); }

void flashOn()  { digitalWrite(FLASH_LED, HIGH); }
void flashOff() { digitalWrite(FLASH_LED, LOW); }

void startCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_QVGA;
  config.jpeg_quality = 12;
  config.fb_count = 2;

  esp_camera_init(&config);
}

static esp_err_t stream_handler(httpd_req_t *req) {
  camera_fb_t *fb;
  char buf[128];

  httpd_resp_set_type(req, "multipart/x-mixed-replace;boundary=frame");

  while (true) {
    fb = esp_camera_fb_get();
    if (!fb) continue;

    int len = snprintf(buf, sizeof(buf),
      "--frame\r\nContent-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n",
      fb->len
    );

    if (httpd_resp_send_chunk(req, buf, len) != ESP_OK) break;
    if (httpd_resp_send_chunk(req, (char*)fb->buf, fb->len) != ESP_OK) break;
    if (httpd_resp_send_chunk(req, "\r\n", 2) != ESP_OK) break;

    esp_camera_fb_return(fb);
    vTaskDelay(100 / portTICK_PERIOD_MS);
  }
  return ESP_OK;
}

void startCameraServer() {
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = 81;

  httpd_uri_t uri = {
    .uri = "/stream",
    .method = HTTP_GET,
    .handler = stream_handler,
    .user_ctx = NULL
  };

  httpd_start(&stream_httpd, &config);
  httpd_register_uri_handler(stream_httpd, &uri);
}

void setupRoutes() {
  server.on("/forward",  [](){ forward(); server.send(200); });
  server.on("/backward", [](){ backward(); server.send(200); });
  server.on("/left",     [](){ left(); server.send(200); });
  server.on("/right",    [](){ right(); server.send(200); });
  server.on("/stop",     [](){ stopMotors(); server.send(200); });

  server.on("/speed", [](){
    if (server.hasArg("value")) {
      speedValue = constrain(server.arg("value").toInt(), 0, 255);
    }
    server.send(200, "text/plain", "OK");
  });

  server.on("/flash/on",  [](){ flashOn(); server.send(200); });
  server.on("/flash/off", [](){ flashOff(); server.send(200); });
}

void setup() {
  Serial.begin(115200);

  ledcAttach(IN1, PWM_FREQ, PWM_RES);
  ledcAttach(IN2, PWM_FREQ, PWM_RES);
  ledcAttach(IN3, PWM_FREQ, PWM_RES);
  ledcAttach(IN4, PWM_FREQ, PWM_RES);

  stopMotors();

  pinMode(LED_PIN, OUTPUT);
  pinMode(FLASH_LED, OUTPUT);
  digitalWrite(LED_PIN, HIGH);
  digitalWrite(FLASH_LED, LOW);

  startCamera();

  WiFi.softAP(ssid, password);
  Serial.println(WiFi.softAPIP());

  setupRoutes();
  server.begin();
  startCameraServer();
}

void loop() {
  server.handleClient();
}
