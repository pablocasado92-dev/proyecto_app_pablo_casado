import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

// 1. IMPORTACIONES DE FIREBASE
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Archivo generado por flutterfire configure
import 'package:cloud_firestore/cloud_firestore.dart'; // Paquete para la base de datos
import 'package:shared_preferences/shared_preferences.dart';

// Importación de pantallas
import 'views/splash_screen.dart';
import 'views/onboarding_screen.dart';
import 'views/login_screen.dart';
import 'views/register_screen.dart';

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
        '/home': (context) => const MyHomePage(title: 'Flutter Demo Home Page'),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  // Función modificada para incrementar el contador Y guardar en Firestore
  void _incrementCounter() async {
    setState(() {
      _counter++;
    });

    // --- PRUEBA CON CLOUD FIRESTORE ---
    // Guarda una nueva entrada en la colección 'clicks' cada vez que pulsas el botón
    try {
      await FirebaseFirestore.instance.collection('clicks').add({
        'contador': _counter,
        'fecha': DateTime.now(),
      });
      print('¡Dato guardado con éxito en Firestore!');
    } catch (e) {
      print('Error al guardar en Firestore: $e');
    }
  }

  // Opcional: Función para reiniciar el onboarding (útil para pruebas)
  Future<void> _resetOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', false);
    
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Onboarding reiniciado. Reinicia la app para verlo de nuevo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reiniciar Onboarding',
            onPressed: () => _resetOnboarding(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Has pulsado el botón este número de veces:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                '💡 Tip: Puedes pulsar el botón de recarga (🔄) en la barra superior para restablecer el Onboarding y volver a verlo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
