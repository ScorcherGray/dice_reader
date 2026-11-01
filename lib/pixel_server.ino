#include <WiFi.h>
#include <ESPAsyncWebServer.h>

const char* ssid = "Verizon XT1650 3932";
const char* password = "a25f729f9317";

AsyncWebServer server(8080);
AsyncEventSource events("/listen");

int lastRoll = 0;

void setup() {
  Serial.begin(115200);
  delay(1000);
  WiFi.mode(WIFI_STA); // Set to station mode
  WiFi.begin(ssid, password);

  Serial.print("Connecting to Hotspot");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nHotspot connected");
  Serial.println("\nIP address: " + WiFi.localIP().toString());
  Serial.println(WiFi.localIP());

  server.on("/roll", HTTP_POST, [](AsyncWebServerRequest *request){
    if (request->hasParam("value3")) {
      IPAddress remote = request->client()->remoteIP();
      Serial.printf("Roll request from %s\n", remote.toString().c_str());
      String val = request->getParam("value3")->value();
      lastRoll = val.toInt();
      Serial.printf("Received roll: %d\n", lastRoll);

      // Broadcast to mobile app
      String jsonPayload = "{\"roll\": " + String(lastRoll) + "}";
      events.send(jsonPayload.c_str(), NULL, millis());

      Serial.print("Broadcasting Roll: ");
      Serial.println(jsonPayload);
      request->send(200, "application/json", "{\"status\":\"success\"}");
    } else {
      request->send(400, "text/plain", "Missing roll parameter");
    }
  });

  server.addHandler(&events);
  Serial.print("\nHandler added...");

  // Debug catch to see if die sends wrong URL
  server.onNotFound([](AsyncWebServerRequest *request){
    Serial.printf("DUBUG: Not Found - Method: %s, URL: %s\n", request->methodToString(), request->url().c_str());
    if(request->url() == "/listen") {
      Serial.println("Server saw /listen but did NOT trigger SSE handler");
    }
    request->send(404, "text/plain", "Not found");
  });

  // SSE handler
  events.onConnect([](AsyncEventSourceClient *client){
    if(client->lastId()){
      Serial.printf("Client reconnected! Last ID: %u\n", client->lastId());
    }
    client->send("{\"heartbeat\": true}", NULL, millis());
    Serial.println("Flutter app connected to /listen");
  });
  server.begin();

}

void loop() {}
