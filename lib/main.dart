import 'package:flutter/material.dart';

// 1. IMPORTACIONES DE FIREBASE
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Archivo generado por flutterfire configure
import 'package:cloud_firestore/cloud_firestore.dart'; // Paquete para la base de datos

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
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