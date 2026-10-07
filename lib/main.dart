import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

// Importaciones de Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Opciones de configuración generadas por FlutterFire CLI

// Importación de las vistas de la aplicación
import 'views/splash_screen.dart';
import 'views/onboarding_screen.dart';
import 'views/login_screen.dart';
import 'views/register_screen.dart';
import 'views/home_view.dart';

/// ============================================================================
/// PUNTO DE ENTRADA PRINCIPAL DE LA APLICACIÓN
/// ============================================================================
/// La función main devuelve un `Future<void>` y es asíncrona (async) para permitir
/// la inicialización previa de los servicios de Flutter y Firebase mediante await.
Future<void> main() async {
  // 1. Garantizar que la infraestructura de widgets de Flutter está inicializada
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializar la conexión con Firebase utilizando las opciones del entorno
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Lanzar la aplicación principal
  runApp(const MyApp());
}

/// Permite el desplazamiento (drag) mediante ratón, trackpad, touch y stylus
/// en todas las plataformas (útil para pruebas en navegador y escritorio)
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Widget raíz de la aplicación
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proyecto App Pablo Casado',
      debugShowCheckedModeBanner: false,
      scrollBehavior: MyCustomScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      
      // La app arranca siempre en la ruta raíz '/', donde la SplashScreen evalúa la navegación
      initialRoute: '/',
      
      // TABLA DE RUTAS NOMBRADAS DE LA APLICACIÓN
      routes: {
        '/': (context) => const SplashScreen(),
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeView(),
      },
    );
  }
}
