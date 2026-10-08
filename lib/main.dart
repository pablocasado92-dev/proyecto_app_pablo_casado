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
import 'views/home_profile_gate.dart';
import 'views/profile_view.dart';
import 'views/edit_profile_view.dart';
import 'views/messages_view.dart';
import 'views/message_detail_view.dart';

/// ============================================================================
/// PUNTO DE ENTRADA PRINCIPAL DE LA APLICACIÓN
/// ============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

/// Comportamiento de desplazamiento para soporte multitáctil y de escritorio
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
      
      // La app arranca en la SplashScreen que evalúa la navegación inicial
      initialRoute: '/',
      
      // TABLA DE RUTAS NOMBRADAS DE LA APLICACIÓN
      routes: {
        '/': (context) => const SplashScreen(),
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => HomeProfileGate(homeBuilder: (context) => const HomeView()),
        '/profile': (context) => const ProfileView(),
        '/edit_profile': (context) => const EditProfileView(),
        '/messages': (context) => const MessagesView(),
        '/message_detail': (context) => const MessageDetailView(),
      },
    );
  }
}
