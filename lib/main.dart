// Importaciones de Firebase
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'data/data_holder.dart';
import 'firebase_options.dart'; // Opciones de configuración generadas por FlutterFire CLI
import 'ins_lib/theme/app_theme.dart';
import 'views/chat_screen.dart';
import 'views/conversaciones_view.dart';
import 'views/edit_profile_view.dart';
import 'views/home_view.dart';
import 'views/login_screen.dart';
import 'views/onboarding_screen.dart';
import 'views/register_screen.dart';
// Importación de vistas
import 'views/splash_screen.dart';

/// ============================================================================
/// PUNTO DE ENTRADA PRINCIPAL DE LA APLICACIÓN
/// ============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

/// Widget raíz de la aplicación con gestión global del ciclo de vida (presencia)
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (FirebaseAuth.instance.currentUser == null) return;

    if (state == AppLifecycleState.resumed) {
      DataHolder.instance.iniciarPresencia();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      DataHolder.instance.detenerPresencia();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proyecto App Pablo Casado',
      debugShowCheckedModeBanner: false,
      scrollBehavior: MyCustomScrollBehavior(),
      theme: AppTheme.tema,

      // La app arranca en la SplashScreen que evalúa la navegación inicial
      initialRoute: '/',

      // TABLA DE RUTAS NOMBRADAS DE LA APLICACIÓN
      routes: {
        '/': (context) => const SplashScreen(),
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeView(),
        '/edit_profile': (context) => const EditProfileView(),
        '/perfiles': (context) => const EditProfileView(),
        '/conversaciones': (context) => const ConversacionesView(),
        '/messages': (context) => const ConversacionesView(),
        '/chat': (context) => const ChatScreen(),
      },
    );
  }
}
