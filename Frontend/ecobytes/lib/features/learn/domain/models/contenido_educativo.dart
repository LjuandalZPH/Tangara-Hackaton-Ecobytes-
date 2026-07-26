import '../../../dashboard/domain/models/sector.dart';

/// Contenido de la pantalla "Aprende", tal como lo devuelve `GET /education`.
///
/// El backend sirve `data/educacion.json` tal cual, y ese mismo archivo es el
/// que alimenta al chatbot: es la fuente única del contenido educativo, para
/// que la pantalla y el asistente no puedan darle cifras distintas al usuario.
///
/// Todos los `fromJson` son tolerantes a claves ausentes (sub-objetos con
/// `?? const {}`, listas con `?? const []`): el modelo debe poder construirse
/// desde `{}` sin lanzar, para que un JSON incompleto degrade a una pantalla
/// con secciones vacías en vez de a un error inesperado.
class ContenidoEducativo {
  const ContenidoEducativo({
    required this.hero,
    required this.seccionSenales,
    required this.seccionNiveles,
    required this.seccionRecomendaciones,
    required this.tituloRecomendacionesGenerales,
    required this.senales,
    required this.niveles,
    required this.recomendacionesPorPerfil,
    required this.recomendacionesGenerales,
    required this.fuente,
  });

  final CopySeccion hero;
  final CopySeccion seccionSenales;
  final CopySeccion seccionNiveles;
  final CopySeccion seccionRecomendaciones;
  final String tituloRecomendacionesGenerales;
  final List<SenalMedida> senales;
  final List<NivelCalidad> niveles;
  final List<RecomendacionPerfil> recomendacionesPorPerfil;
  final List<String> recomendacionesGenerales;
  final FuenteEducativa fuente;

  factory ContenidoEducativo.fromJson(Map<String, dynamic> json) {
    final ui = (json['ui'] as Map<String, dynamic>?) ?? const {};

    CopySeccion copy(String clave) => CopySeccion.fromJson(
          (ui[clave] as Map<String, dynamic>?) ?? const {},
        );

    return ContenidoEducativo(
      hero: copy('hero'),
      seccionSenales: copy('seccion_senales'),
      seccionNiveles: copy('seccion_niveles'),
      seccionRecomendaciones: copy('seccion_recomendaciones'),
      tituloRecomendacionesGenerales:
          ui['titulo_recomendaciones_generales'] as String? ?? '',
      senales: ((json['contaminantes'] as List?) ?? const [])
          .map((e) => SenalMedida.fromJson(e as Map<String, dynamic>))
          .toList(),
      niveles: ((json['niveles_calidad'] as List?) ?? const [])
          .map((e) => NivelCalidad.fromJson(e as Map<String, dynamic>))
          .toList(),
      recomendacionesPorPerfil: ((json['recomendaciones_por_perfil'] as List?) ?? const [])
          .map((e) => RecomendacionPerfil.fromJson(e as Map<String, dynamic>))
          .toList(),
      recomendacionesGenerales: ((json['recomendaciones_generales'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      fuente: FuenteEducativa.fromJson(
        (json['fuente'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}

/// Textos de encabezado de una sección (etiqueta pequeña + título).
/// `descripcion` solo la usa el hero; en las demás llega vacía.
class CopySeccion {
  const CopySeccion({
    required this.etiqueta,
    required this.titulo,
    required this.descripcion,
  });

  final String etiqueta;
  final String titulo;
  final String descripcion;

  factory CopySeccion.fromJson(Map<String, dynamic> json) => CopySeccion(
        etiqueta: json['etiqueta'] as String? ?? '',
        titulo: json['titulo'] as String? ?? '',
        descripcion: json['descripcion'] as String? ?? '',
      );
}

/// Una de las señales que la red de sensores mide (PM2.5, CO2, humedad).
///
/// Se llama "señal" y no "contaminante" porque la humedad no lo es
/// (`esContaminante: false`); la clave del JSON sigue siendo `contaminantes`
/// por compatibilidad con lo que ya consume el chatbot.
class SenalMedida {
  const SenalMedida({
    required this.id,
    required this.sigla,
    required this.nombre,
    required this.descripcion,
    required this.esContaminante,
    required this.efectosEnSalud,
    required this.limites,
  });

  final String id;
  final String sigla;
  final String nombre;
  final String descripcion;
  final bool esContaminante;
  final List<String> efectosEnSalud;
  final LimitesEducativos limites;

  factory SenalMedida.fromJson(Map<String, dynamic> json) => SenalMedida(
        id: json['id'] as String? ?? '',
        sigla: json['sigla'] as String? ?? '',
        nombre: json['nombre'] as String? ?? '',
        descripcion: json['descripcion'] as String? ?? '',
        esContaminante: json['es_contaminante'] as bool? ?? true,
        efectosEnSalud: ((json['efectos_en_salud'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        limites: LimitesEducativos.fromJson(
          (json['limites'] as Map<String, dynamic>?) ?? const {},
        ),
      );
}

/// Límites de referencia de una señal. Forma uniforme para las tres:
/// `resumen` es la línea corta de la tarjeta, `detalle` los bullets
/// (puede venir vacío, como en la humedad).
class LimitesEducativos {
  const LimitesEducativos({
    required this.resumen,
    required this.detalle,
    required this.fuente,
  });

  final String resumen;
  final List<String> detalle;
  final String fuente;

  factory LimitesEducativos.fromJson(Map<String, dynamic> json) => LimitesEducativos(
        resumen: json['resumen'] as String? ?? '',
        detalle: ((json['detalle'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        fuente: json['fuente'] as String? ?? '',
      );
}

/// Un peldaño de la escala de calidad del aire (verde/amarillo/rojo/gris).
///
/// El color y la etiqueta ("Buena", "Dañina"…) NO vienen del JSON: se derivan
/// de `EstadoSector`, el mismo enum con el que el mapa colorea las comunas.
/// Si vinieran del JSON, la pantalla que *enseña* la escala podría acabar
/// mostrando una distinta de la que el mapa aplica.
class NivelCalidad {
  const NivelCalidad({
    required this.estado,
    required this.nombreColor,
    required this.descripcion,
  });

  final EstadoSector estado;
  final String nombreColor;
  final String descripcion;

  factory NivelCalidad.fromJson(Map<String, dynamic> json) => NivelCalidad(
        estado: EstadoSectorX.fromApi(json['id'] as String?),
        nombreColor: json['nombre_color'] as String? ?? '',
        descripcion: json['descripcion'] as String? ?? '',
      );
}

/// Recomendación dirigida a un perfil de población concreto.
class RecomendacionPerfil {
  const RecomendacionPerfil({
    required this.emoji,
    required this.perfil,
    required this.texto,
  });

  final String emoji;
  final String perfil;
  final String texto;

  factory RecomendacionPerfil.fromJson(Map<String, dynamic> json) => RecomendacionPerfil(
        emoji: json['emoji'] as String? ?? '',
        perfil: json['perfil'] as String? ?? '',
        texto: json['texto'] as String? ?? '',
      );
}

/// Atribución de la fuente del contenido (OMS).
class FuenteEducativa {
  const FuenteEducativa({required this.nombre, required this.url});

  final String nombre;
  final String url;

  factory FuenteEducativa.fromJson(Map<String, dynamic> json) => FuenteEducativa(
        nombre: json['nombre'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );
}
