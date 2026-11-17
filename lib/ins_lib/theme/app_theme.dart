import 'package:flutter/material.dart';

// =====================================================================
// AppTheme.dart — TOKENS DE DISEÑO (colores, espacios, radios y textos)
// ---------------------------------------------------------------------
// Clases con miembros static const que definen la paleta de colores,
// dimensiones y estilos de texto de la aplicación.
// =====================================================================

/// Paleta de colores inspirada en la interfaz oscura de Moxfield y MTG
class AppColores {
  /// Morado amatista vibrante (Planeswalker / Moxfield accent)
  static const Color principal = Color(0xFF8B5CF6);

  /// Púrpura profundo para botones destacados y elementos primarios
  static const Color oscuro = Color(0xFF7C3AED);

  /// Grafito/púrpura suave para fondos de badges, chips y contenedores
  static const Color suave = Color(0xFF282538);

  /// Fondo oscuro confortable (Dark Mode Moxfield / Draftsim)
  static const Color fondo = Color(0xFF13131A);

  /// Superficie elevada para tarjetas y modales
  static const Color tarjeta = Color(0xFF1E1E28);

  /// Texto principal en blanco marfil de alto contraste
  static const Color texto = Color(0xFFF3F4F6);

  /// Texto secundario en gris neutro legible
  static const Color textoSecundario = Color(0xFF9CA3AF);

  /// Texto sobre fondo principal
  static const Color sobrePrincipal = Colors.white;

  /// Texto secundario sobre fondo principal
  static const Color sobrePrincipalSuave = Color(0xDCFFFFFF);

  /// Pastillas translúcidas sobre cabeceras
  static const Color pastilla = Color(0x28FFFFFF);

  /// Líneas divisorias sutiles en grafito medio
  static const Color divisor = Color(0xFF2D2D3E);

  /// Borde de pastillas
  static const Color pastillaBorde = Color(0x55FFFFFF);

  /// Borde de campos en reposo
  static const Color bordeCampo = Color(0xFF3E3E50);

  /// Dorado legendario / multicolor MTG para torneos y destacados
  static const Color dorado = Color(0xFFF59E0B);

  /// Color de alertas y errores
  static const Color error = Color(0xFFEF4444);
}

/// Identidad cromática oficial WUBRG de Magic: The Gathering
class MtgColores {
  /// W - White / Llanura (Pergamino marfil)
  static const Color blanco = Color(0xFFF8F6D8);

  /// U - Blue / Isla (Zafiro celeste)
  static const Color azul = Color(0xFF38BDF8);

  /// B - Black / Pantano (Ónice pizarra)
  static const Color negro = Color(0xFF64748B);

  /// R - Red / Montaña (Carmín vivo)
  static const Color rojo = Color(0xFFEF4444);

  /// G - Green / Bosque (Esmeralda naturaleza)
  static const Color verde = Color(0xFF10B981);

  /// C - Colorless / Incoloro (Plata artefacto)
  static const Color incoloro = Color(0xFF94A3B8);

  /// M - Multicolor / Gold (Oro de cartas multicolor)
  static const Color multicolor = Color(0xFFF59E0B);

  /// Lealtad de Planeswalker (Amatista Moxfield)
  static const Color planeswalker = Color(0xFF8B5CF6);

  /// Devuelve el color MTG correspondiente a la letra de maná
  static Color colorParaSimbolo(String simbolo) {
    switch (simbolo.toUpperCase().trim()) {
      case 'W':
        return blanco;
      case 'U':
        return azul;
      case 'B':
        return negro;
      case 'R':
        return rojo;
      case 'G':
        return verde;
      case 'C':
        return incoloro;
      default:
        return multicolor;
    }
  }
}

/// Espaciados de la interfaz
class AppEspacios {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const double anchoMaximo = 720;
  static const double anchoFormulario = 440;
  static const double alturaBoton = 48;
  static const double iconoGrande = 48;
  static const double imagenLista = 56;
}

/// Radios de curvatura de bordes
class AppRadios {
  static const double pastilla = 20;
  static const double tarjeta = 20;
  static const double cabecera = 32;
  static const double campo = 14;
  static const double imagen = 12;
}

/// Estilos tipográficos reutilizables
class AppTextos {
  static const TextStyle tituloCabecera = TextStyle(
    color: AppColores.sobrePrincipal,
    fontSize: 26,
    fontWeight: FontWeight.bold,
    height: 1.25,
  );

  static const TextStyle etiqueta = TextStyle(
    color: AppColores.sobrePrincipal,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle fecha = TextStyle(
    color: AppColores.sobrePrincipalSuave,
    fontSize: 13,
  );

  static const TextStyle seccion = TextStyle(
    color: AppColores.oscuro,
    fontSize: 12,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );

  static const TextStyle cuerpo = TextStyle(
    color: AppColores.texto,
    fontSize: 17,
    height: 1.6,
  );

  static const TextStyle tituloBarra = TextStyle(
    color: AppColores.sobrePrincipal,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle tituloPantalla = TextStyle(
    color: AppColores.oscuro,
    fontSize: 26,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );

  static const TextStyle tituloLista = TextStyle(
    color: AppColores.texto,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle secundario = TextStyle(
    color: AppColores.textoSecundario,
    fontSize: 14,
    height: 1.4,
  );

  static const TextStyle boton = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}

/// =====================================================================
/// Configuración unificada de ThemeData moderno para toda la aplicación
/// =====================================================================
class AppTheme {
  static ThemeData get tema {
    final colorScheme = ColorScheme.dark(
      primary: AppColores.principal,
      secondary: AppColores.dorado,
      surface: AppColores.tarjeta,
      error: AppColores.error,
      onPrimary: Colors.white,
      onSurface: AppColores.texto,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColores.fondo,

      // Barra superior moderna y limpia (Dark Mode)
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColores.fondo,
        foregroundColor: AppColores.texto,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColores.texto),
        titleTextStyle: TextStyle(
          color: AppColores.texto,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),

      // Tarjetas con bordes redondeados y contraste confortable
      cardTheme: CardThemeData(
        color: AppColores.tarjeta,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
          side: const BorderSide(color: AppColores.divisor, width: 1),
        ),
      ),

      // Campos de texto modernos tipo cápsula rellena
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColores.tarjeta,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadios.campo),
          borderSide: const BorderSide(color: AppColores.divisor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadios.campo),
          borderSide: const BorderSide(color: AppColores.divisor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadios.campo),
          borderSide: const BorderSide(color: AppColores.principal, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadios.campo),
          borderSide: const BorderSide(color: AppColores.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadios.campo),
          borderSide: const BorderSide(color: AppColores.error, width: 1.8),
        ),
        labelStyle: const TextStyle(color: AppColores.textoSecundario),
        prefixIconColor: AppColores.principal,
      ),

      // Botones elevados con altura confortable y esquinas redondeadas
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColores.oscuro,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, AppEspacios.alturaBoton),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadios.campo),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // Botón flotante estilizado
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColores.oscuro,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // Barra de navegación inferior
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColores.tarjeta,
        elevation: 1,
        indicatorColor: AppColores.suave,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColores.principal,
            );
          }
          return const TextStyle(
            fontSize: 12,
            color: AppColores.textoSecundario,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColores.principal);
          }
          return const IconThemeData(color: AppColores.textoSecundario);
        }),
      ),

      // Diálogos redondeados en tema oscuro
      dialogTheme: DialogThemeData(
        backgroundColor: AppColores.tarjeta,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        ),
      ),

      // Modales inferiores en tema oscuro
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColores.tarjeta,
        surfaceTintColor: Colors.transparent,
      ),

      // Snackbars flotantes y suaves
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColores.tarjeta,
        contentTextStyle: const TextStyle(color: AppColores.texto),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColores.divisor),
        ),
      ),
    );
  }
}
