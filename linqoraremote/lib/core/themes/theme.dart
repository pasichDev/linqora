import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff2e6a44),
      surfaceTint: Color(0xff2e6a44),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xffb2f1c1),
      onPrimaryContainer: Color(0xff12512e),
      secondary: Color(0xff4f6353),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffd2e8d4),
      onSecondaryContainer: Color(0xff384b3c),
      tertiary: Color(0xff116b56),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffa3f2d8),
      onTertiaryContainer: Color(0xff005140),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff93000a),
      surface: Color(0xfff6fbf3),
      onSurface: Color(0xff181d18),
      onSurfaceVariant: Color(0xff414941),
      outline: Color(0xff717971),
      outlineVariant: Color(0xffc1c9bf),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2c322d),
      inversePrimary: Color(0xff96d5a6),
      primaryFixed: Color(0xffb2f1c1),
      onPrimaryFixed: Color(0xff00210e),
      primaryFixedDim: Color(0xff96d5a6),
      onPrimaryFixedVariant: Color(0xff12512e),
      secondaryFixed: Color(0xffd2e8d4),
      onSecondaryFixed: Color(0xff0d1f13),
      secondaryFixedDim: Color(0xffb6ccb8),
      onSecondaryFixedVariant: Color(0xff384b3c),
      tertiaryFixed: Color(0xffa3f2d8),
      onTertiaryFixed: Color(0xff002018),
      tertiaryFixedDim: Color(0xff87d6bd),
      onTertiaryFixedVariant: Color(0xff005140),
      surfaceDim: Color(0xffd7dbd4),
      surfaceBright: Color(0xfff6fbf3),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff0f5ed),
      surfaceContainer: Color(0xffebefe8),
      surfaceContainerHigh: Color(0xffe5eae2),
      surfaceContainerHighest: Color(0xffdfe4dc),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff003f1f),
      surfaceTint: Color(0xff2e6a44),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff3e7951),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff283a2c),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff5e7261),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff003e31),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff287a65),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff740006),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffcf2c27),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff6fbf3),
      onSurface: Color(0xff0d120e),
      onSurfaceVariant: Color(0xff303831),
      outline: Color(0xff4d544d),
      outlineVariant: Color(0xff676f67),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2c322d),
      inversePrimary: Color(0xff96d5a6),
      primaryFixed: Color(0xff3e7951),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff24603b),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff5e7261),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff46594a),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff287a65),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff00614d),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffc3c8c1),
      surfaceBright: Color(0xfff6fbf3),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff0f5ed),
      surfaceContainer: Color(0xffe5eae2),
      surfaceContainerHigh: Color(0xffd9ded7),
      surfaceContainerHighest: Color(0xffced3cc),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff003419),
      surfaceTint: Color(0xff2e6a44),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff165430),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff1e3023),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff3a4e3e),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff003328),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff005442),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff600004),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff98000a),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff6fbf3),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff262e27),
      outlineVariant: Color(0xff434b44),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2c322d),
      inversePrimary: Color(0xff96d5a6),
      primaryFixed: Color(0xff165430),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff003b1d),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff3a4e3e),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff243729),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff005442),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff003a2e),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffb5bab3),
      surfaceBright: Color(0xfff6fbf3),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffedf2ea),
      surfaceContainer: Color(0xffdfe4dc),
      surfaceContainerHigh: Color(0xffd1d6ce),
      surfaceContainerHighest: Color(0xffc3c8c1),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xff96d5a6),
      surfaceTint: Color(0xff96d5a6),
      onPrimary: Color(0xff00391c),
      primaryContainer: Color(0xff12512e),
      onPrimaryContainer: Color(0xffb2f1c1),
      secondary: Color(0xffb6ccb8),
      onSecondary: Color(0xff223527),
      secondaryContainer: Color(0xff384b3c),
      onSecondaryContainer: Color(0xffd2e8d4),
      tertiary: Color(0xff87d6bd),
      onTertiary: Color(0xff00382c),
      tertiaryContainer: Color(0xff005140),
      onTertiaryContainer: Color(0xffa3f2d8),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff101510),
      onSurface: Color(0xffdfe4dc),
      onSurfaceVariant: Color(0xffc1c9bf),
      outline: Color(0xff8b938a),
      outlineVariant: Color(0xff414941),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdfe4dc),
      inversePrimary: Color(0xff2e6a44),
      primaryFixed: Color(0xffb2f1c1),
      onPrimaryFixed: Color(0xff00210e),
      primaryFixedDim: Color(0xff96d5a6),
      onPrimaryFixedVariant: Color(0xff12512e),
      secondaryFixed: Color(0xffd2e8d4),
      onSecondaryFixed: Color(0xff0d1f13),
      secondaryFixedDim: Color(0xffb6ccb8),
      onSecondaryFixedVariant: Color(0xff384b3c),
      tertiaryFixed: Color(0xffa3f2d8),
      onTertiaryFixed: Color(0xff002018),
      tertiaryFixedDim: Color(0xff87d6bd),
      onTertiaryFixedVariant: Color(0xff005140),
      surfaceDim: Color(0xff101510),
      surfaceBright: Color(0xff353a35),
      surfaceContainerLowest: Color(0xff0a0f0b),
      surfaceContainerLow: Color(0xff181d18),
      surfaceContainer: Color(0xff1c211c),
      surfaceContainerHigh: Color(0xff262b26),
      surfaceContainerHighest: Color(0xff313631),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffacebbb),
      surfaceTint: Color(0xff96d5a6),
      onPrimary: Color(0xff002d14),
      primaryContainer: Color(0xff629e73),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xffcce2ce),
      onSecondary: Color(0xff172a1c),
      secondaryContainer: Color(0xff819684),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xff9cecd2),
      onTertiary: Color(0xff002c22),
      tertiaryContainer: Color(0xff509f88),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffd2cc),
      onError: Color(0xff540003),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff101510),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffd6dfd5),
      outline: Color(0xffacb4ab),
      outlineVariant: Color(0xff8a928a),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdfe4dc),
      inversePrimary: Color(0xff14522f),
      primaryFixed: Color(0xffb2f1c1),
      onPrimaryFixed: Color(0xff001507),
      primaryFixedDim: Color(0xff96d5a6),
      onPrimaryFixedVariant: Color(0xff003f1f),
      secondaryFixed: Color(0xffd2e8d4),
      onSecondaryFixed: Color(0xff041509),
      secondaryFixedDim: Color(0xffb6ccb8),
      onSecondaryFixedVariant: Color(0xff283a2c),
      tertiaryFixed: Color(0xffa3f2d8),
      onTertiaryFixed: Color(0xff00150f),
      tertiaryFixedDim: Color(0xff87d6bd),
      onTertiaryFixedVariant: Color(0xff003e31),
      surfaceDim: Color(0xff101510),
      surfaceBright: Color(0xff414640),
      surfaceContainerLowest: Color(0xff050805),
      surfaceContainerLow: Color(0xff1a1f1a),
      surfaceContainer: Color(0xff242924),
      surfaceContainerHigh: Color(0xff2f342f),
      surfaceContainerHighest: Color(0xff3a3f3a),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffbfffce),
      surfaceTint: Color(0xff96d5a6),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xff92d1a2),
      onPrimaryContainer: Color(0xff000f04),
      secondary: Color(0xffdff6e1),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffb2c8b5),
      onSecondaryContainer: Color(0xff010e05),
      tertiary: Color(0xffb5ffe6),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xff83d2b9),
      onTertiaryContainer: Color(0xff000e09),
      error: Color(0xffffece9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffaea4),
      onErrorContainer: Color(0xff220001),
      surface: Color(0xff101510),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xffeaf2e8),
      outlineVariant: Color(0xffbdc5bb),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdfe4dc),
      inversePrimary: Color(0xff14522f),
      primaryFixed: Color(0xffb2f1c1),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xff96d5a6),
      onPrimaryFixedVariant: Color(0xff001507),
      secondaryFixed: Color(0xffd2e8d4),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffb6ccb8),
      onSecondaryFixedVariant: Color(0xff041509),
      tertiaryFixed: Color(0xffa3f2d8),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xff87d6bd),
      onTertiaryFixedVariant: Color(0xff00150f),
      surfaceDim: Color(0xff101510),
      surfaceBright: Color(0xff4c514c),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff1c211c),
      surfaceContainer: Color(0xff2c322d),
      surfaceContainerHigh: Color(0xff373d38),
      surfaceContainerHighest: Color(0xff434843),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }

  ThemeData theme(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    textTheme: textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    ),
    scaffoldBackgroundColor: colorScheme.surface,
    canvasColor: colorScheme.surface,
  );

  List<ExtendedColor> get extendedColors => [];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
