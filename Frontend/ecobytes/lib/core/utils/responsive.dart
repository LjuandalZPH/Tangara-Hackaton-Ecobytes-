import 'package:flutter/material.dart';

import '../constants/app_breakpoints.dart';

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