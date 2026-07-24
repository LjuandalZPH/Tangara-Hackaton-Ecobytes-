import 'package:latlong2/latlong.dart';

/// Determina si [punto] está dentro de [poligono] usando el algoritmo de
/// ray-casting (conteo de cruces con una semirrecta horizontal).
///
/// [poligono] es una lista de vértices (anillo exterior) en el orden en
/// que llegan del backend, sin necesidad de estar cerrado explícitamente.
bool puntoEnPoligono(LatLng punto, List<LatLng> poligono) {
  if (poligono.length < 3) return false;

  var dentro = false;
  final n = poligono.length;

  for (var i = 0, j = n - 1; i < n; j = i++) {
    final vi = poligono[i];
    final vj = poligono[j];

    final intersecta = ((vi.latitude > punto.latitude) !=
            (vj.latitude > punto.latitude)) &&
        (punto.longitude <
            (vj.longitude - vi.longitude) *
                    (punto.latitude - vi.latitude) /
                    (vj.latitude - vi.latitude) +
                vi.longitude);

    if (intersecta) dentro = !dentro;
  }

  return dentro;
}
