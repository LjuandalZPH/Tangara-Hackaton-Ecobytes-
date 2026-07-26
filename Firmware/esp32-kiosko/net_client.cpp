#include "net_client.h"

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>

namespace net {

void imprimirHeap(const char* etiqueta) {
  Serial.printf(
      "[heap] %-28s libre=%8u  min_historico=%8u  bloque_max_contiguo=%8u\n",
      etiqueta, ESP.getFreeHeap(), ESP.getMinFreeHeap(), ESP.getMaxAllocHeap());
}

bool conectarWifi(const char* ssid, const char* password, unsigned long timeoutMs) {
  Serial.printf("Conectando a WiFi '%s'...\n", ssid);

  // Asegura un estado limpio antes de intentar. Sin esto, reintentar
  // despues de un timeout previo (ej. el usuario toca "Guardar y
  // conectar" de nuevo en ui_config.cpp tras un primer intento fallido)
  // puede toparse con el intento anterior todavia "in progress" a nivel
  // del driver WiFi del ESP-IDF -- nuestro propio timeout ya se rindio,
  // pero el driver puede seguir reintentando en segundo plano. Visto en
  // hardware real (T-07.3): "E (...) wifi:sta is connecting, cannot set
  // config" seguido de un reinicio -- WiFi.disconnect(true, true) +
  // una pausa corta antes de WiFi.begin() de nuevo lo evita.
  WiFi.disconnect(true, true);
  delay(100);
  WiFi.mode(WIFI_STA);

  // Mitigacion de brownout: antes esto
  // solo se aplicaba DESPUES de conectar con exito, en esp32-kiosko.ino --
  // un gap real, porque el escaneo de redes de ui_config.cpp y los
  // reintentos de conexion (que es donde mas se vio inestabilidad en
  // hardware real) corrian a full power sin esta mitigacion. Se mueve aca
  // para que cubra todo intento de conexion, sea el primero o un
  // reintento.
  WiFi.setTxPower(WIFI_POWER_2dBm);

  WiFi.begin(ssid, password);

  const unsigned long inicio = millis();
  while (WiFi.status() != WL_CONNECTED) {
    if (millis() - inicio > timeoutMs) {
      Serial.printf("No se pudo conectar a WiFi (timeout %lums).\n", timeoutMs);
      return false;
    }
    delay(250);
    Serial.print(".");
  }
  Serial.printf("\nWiFi conectado. IP local: %s\n", WiFi.localIP().toString().c_str());
  return true;
}

namespace {

// ArduinoJson, al leer directo de un Stream de red, llama a read() y si en
// ese instante no hay byte disponible lo interpreta como fin de stream --
// sin reintentar, aunque la conexion siga viva y lleguen mas datos un
// milisegundo despues. Con TLS + el relay de Tailscale Funnel moviendo
// ~774 KB, esos huecos son casi garantizados. Este wrapper espera
// activamente (hasta kStallMaxMs sin bytes nuevos) antes de rendirse, y
// solo devuelve -1 de verdad si la conexion se cerro o el hueco fue
// demasiado largo. Patron recomendado por ArduinoJson para "streams
// lentos" (https://arduinojson.org/v7/how-to/deserialize-a-slow-stream/).
//
// kStallMaxMs subido de 5000 a 12000: con 5000 el relay de Funnel
// dejaba huecos de silencio mas largos a mitad de transferencia en 2-3 de
// cada 5 fetches, cortando el JSON (IncompleteInput) aunque la conexion
// seguia viva.
class LectorResiliente {
 public:
  LectorResiliente(WiFiClient& stream, HTTPClient& http)
      : _stream(stream), _http(http) {}

  int read() {
    const unsigned long inicioEspera = millis();
    while (!_stream.available()) {
      if (!_http.connected()) {
        return -1;  // conexion realmente cerrada: fin real del stream.
      }
      if (millis() - inicioEspera > kStallMaxMs) {
        Serial.printf("LectorResiliente: %lu ms sin datos nuevos (leidos %u bytes), abandono.\n",
                      kStallMaxMs, _bytesLeidos);
        return -1;
      }
      delay(1);
    }
    _bytesLeidos++;
    return _stream.read();
  }

  uint32_t bytesLeidos() const { return _bytesLeidos; }

 private:
  static constexpr unsigned long kStallMaxMs = 12000;
  WiFiClient& _stream;
  HTTPClient& _http;
  uint32_t _bytesLeidos = 0;
};

// Tolera un "/" final en backendUrl -- sin esto, un trailing slash genera
// ".../ts.net//sectors" (doble slash) y FastAPI responde 404 porque esa
// ruta no matchea. Compartido por los tres fetch de este archivo.
String normalizarBaseUrl(const String& backendUrl) {
  String base = backendUrl;
  while (base.endsWith("/")) {
    base.remove(base.length() - 1);
  }
  return base;
}

// GET simple para payloads chicos (~2-3KB `/sectors/{id}`, <1KB
// `/risk/{sector}` -- ver docs/firmware-esp32-kiosko.md): a diferencia de
// fetchSectores() (774KB, streaming + filtro), estos entran comodos en un
// String antes de parsear, sin necesitar LectorResiliente ni el filtro de
// deserializacion.
bool fetchJsonSimple(const String& url, JsonDocument& doc) {
  WiFiClientSecure client;
  client.setInsecure();  // TODO(antes del firmware final): setCACert(), ver README.
  client.setTimeout(15000);

  HTTPClient http;
  Serial.printf("URL solicitada: %s\n", url.c_str());
  http.begin(client, url);
  http.setTimeout(20000);  // Funnel puede tardar en el handshake del relay.

  const int codigo = http.GET();
  if (codigo != HTTP_CODE_OK) {
    Serial.printf("GET %s fallo, codigo HTTP=%d (%s)\n", url.c_str(), codigo,
                  http.errorToString(codigo).c_str());
    http.end();
    return false;
  }

  const String payload = http.getString();
  http.end();

  const DeserializationError error = deserializeJson(doc, payload);
  if (error) {
    Serial.printf("Fallo al parsear JSON de %s: %s\n", url.c_str(), error.c_str());
    return false;
  }
  return true;
}

}  // namespace

JsonDocument construirFiltroSectores() {
  JsonDocument filtro;
  JsonObject elemento = filtro["sectores"][0].to<JsonObject>();
  elemento["id"] = true;
  elemento["nombre"] = true;
  elemento["estado"] = true;
  elemento["pm25_promedio"] = true;
  elemento["sin_datos_recientes"] = true;
  elemento["ultima_lectura"] = true;
  return filtro;
}

bool fetchSectores(const String& backendUrl, const JsonDocument& filtro, JsonDocument& doc) {
  WiFiClientSecure client;
  client.setInsecure();  // TODO(antes del firmware final): setCACert() con
                          // el cert de Let's Encrypt de Funnel, ver README.
  // Timeout del propio stream TLS (no el de HTTPClient, que solo cubre
  // conectar + leer cabeceras) -- necesario porque la transferencia via TLS
  // + relay de Funnel deja huecos breves sin datos disponibles.
  client.setTimeout(15000);

  HTTPClient http;
  const String url = normalizarBaseUrl(backendUrl) + "/sectors";
  Serial.printf("URL solicitada: %s\n", url.c_str());
  http.begin(client, url);
  // 20s, no 10s: la primera conexion por Tailscale Funnel puede tardar en
  // el handshake del relay.
  http.setTimeout(20000);

  const int codigo = http.GET();
  imprimirHeap("despues de GET (headers)");

  if (codigo != HTTP_CODE_OK) {
    Serial.printf("GET /sectors fallo, codigo HTTP=%d (%s)\n", codigo,
                  http.errorToString(codigo).c_str());
    char tlsError[128];
    client.lastError(tlsError, sizeof(tlsError));
    if (tlsError[0] != '\0') {
      Serial.printf("Detalle TLS (WiFiClientSecure::lastError): %s\n", tlsError);
    }
    http.end();
    return false;
  }

  // Streaming directo desde el WiFiClientSecure, sin volcar a String
  // primero: el pico de memoria nunca debe incluir el JSON completo sin
  // filtrar.
  WiFiClient& stream = http.getStream();
  LectorResiliente lector(stream, http);
  const int contentLength = http.getSize();  // capturar antes de http.end(), que lo invalida.

  const unsigned long inicioParseo = millis();
  const DeserializationError error =
      deserializeJson(doc, lector, DeserializationOption::Filter(filtro));
  const unsigned long duracionParseoMs = millis() - inicioParseo;

  imprimirHeap("despues de parsear (filtrado)");
  http.end();

  Serial.printf("Bytes recibidos: %u / %d (Content-Length) en %lu ms\n", lector.bytesLeidos(),
                contentLength, duracionParseoMs);

  if (error) {
    Serial.printf("Fallo al parsear JSON: %s\n", error.c_str());
    return false;
  }

  return true;
}

bool fetchDetalleSector(const String& backendUrl, const String& sectorId, JsonDocument& doc) {
  return fetchJsonSimple(normalizarBaseUrl(backendUrl) + "/sectors/" + sectorId, doc);
}

bool fetchRiesgoSector(const String& backendUrl, const String& sectorId, JsonDocument& doc) {
  return fetchJsonSimple(normalizarBaseUrl(backendUrl) + "/risk/" + sectorId, doc);
}

}  // namespace net
