import 'package:flutter/material.dart';

import '../constants/app_breakpoints.dart';
import '../constants/app_spacing.dart';

/// Tipos de pantalla soportados por la aplicación.
enum ScreenType { mobile, tablet, desktop }

/// Extensiones para facilitar el diseño responsivo desde cualquier Widget mediante el [BuildContext].
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Retorna el tipo de pantalla actual basado en los breakpoints del sistema.
  ScreenType get screenType {
    final width = screenWidth;
    if (width < AppBreakpoints.mobile) return ScreenType.mobile;
    if (width < AppBreakpoints.desktop) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  bool get isMobile => screenType == ScreenType.mobile;
  bool get isTablet => screenType == ScreenType.tablet;
  bool get isDesktop => screenType == ScreenType.desktop;

  /// Devuelve un valor genérico [T] adaptado dinámicamente al tamaño de pantalla actual.
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? desktop;
      case ScreenType.desktop:
        return desktop;
    }
  }

  int get gridColumns => responsiveValue(mobile: 1, tablet: 2, desktop: 3);

  EdgeInsets get pagePadding => EdgeInsets.symmetric(
        horizontal: responsiveValue(mobile: 20.0, tablet: 32.0, desktop: 48.0),
      );
}

/// Cuántas tarjetas de al menos [anchoMinimo] caben en [anchoDisponible],
/// con [espaciado] entre ellas.
///
/// Se usa donde el número de tarjetas viene de datos y no del código: fijar
/// las columnas a mano (`isMobile ? 1 : 4`) descuadra la grilla en cuanto el
/// backend devuelve una cantidad distinta a la prevista. Nunca devuelve menos
/// de 1 ni más de [maximo], para que una lista larga no genere columnas
/// diminutas en escritorio.
int columnasParaAncho(
  double anchoDisponible, {
  required double anchoMinimo,
  double espaciado = AppSpacing.lg,
  int maximo = 4,
}) {
  if (anchoDisponible <= 0) return 1;
  final cabidas = ((anchoDisponible + espaciado) / (anchoMinimo + espaciado)).floor();
  return cabidas.clamp(1, maximo);
}

/// Contenedor adaptativo que limita el ancho máximo del contenido en pantallas grandes.
class ContentContainer extends StatelessWidget {
  const ContentContainer({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.desktop,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? context.pagePadding,
          child: child,
        ),
      ),
    );
  }
}