import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

// 1. IMPORTACIONES DE FIREBASE
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Archivo generado por flutterfire configure

// Importación de pantallas
import 'views/splash_screen.dart';
import 'views/onboarding_screen.dart';
import 'views/login_screen.dart';
import 'views/register_screen.dart';
import 'views/home_view.dart';

// 2. CONVERTIR main() EN ASÍNCRONA (async)
void main() async {
  // 3. ASEGURAR QUE FLUTTER ESTÉ INICIALIZADO
  WidgetsFlutterBinding.ensureInitialized();

  // 4. INICIALIZAR FIREBASE EN TU APLICACIÓN
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

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
      // La app siempre arranca en la Splash Screen, que evaluará las rutas
      initialRoute: '/',
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
