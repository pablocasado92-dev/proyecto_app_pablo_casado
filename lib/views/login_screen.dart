import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/data_holder.dart';
import '../ins_lib/theme/app_theme.dart';

/// ============================================================================
/// BLOQUE 3: PANTALLA DE INICIO DE SESIÓN (LoginScreen)
/// ============================================================================
/// Esta vista gestiona el proceso de autenticación de usuarios existentes
/// mediante correo electrónico y contraseña utilizando Firebase Authentication.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Clave global para identificar y validar el formulario
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto para capturar el email y la contraseña
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Variables de estado local para la UI
  bool _obscurePassword = true; // Controla la visibilidad de la contraseña
  bool _isLoading = false; // Indica si se está procesando la solicitud

  @override
  void dispose() {
    // Liberación de memoria de los controladores al destruir el widget
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Procesa el inicio de sesión del usuario en Firebase Auth
  Future<void> _handleLogin() async {
    // 1. Validar que los campos del formulario cumplen las reglas
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Mostrar indicador de carga
      });

      try {
        // 2. Llamada asíncrona a Firebase Auth para iniciar sesión
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 3. Almacenar el email y descargar el perfil del usuario desde Firestore
        DataHolder().userEmail = _emailController.text.trim();
        await DataHolder.instance.descargarPerfil();

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // 4. Navegar a la pantalla principal (HomeView) reemplazando la ruta actual
        Navigator.pushReplacementNamed(context, '/home');
      } on FirebaseAuthException catch (e) {
        // Manejo de errores específicos de Firebase Authentication
        setState(() {
          _isLoading = false;
        });

        String errorMessage = 'Error al iniciar sesión';
        if (e.code == 'user-not-found') {
          errorMessage = 'No existe una cuenta con este correo electrónico.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Contraseña incorrecta.';
        } else if (e.code == 'invalid-credential') {
          errorMessage = 'Credenciales incorrectas o usuario no encontrado.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'El formato del correo electrónico no es válido.';
        } else {
          errorMessage = e.message ?? errorMessage;
        }

        if (!mounted) return;
        // Mostrar mensaje de error al usuario
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      } catch (e) {
        // Captura de otros errores no esperados
        setState(() {
          _isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Sesión'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icono superior descriptivo con contenedor suave
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: AppColores.suave,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 44,
                        color: AppColores.oscuro,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '¡Bienvenido de nuevo!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColores.oscuro,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Inicia sesión para continuar en tu cuenta',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColores.textoSecundario),
                  ),
                  const SizedBox(height: 32),

                  // Campo de Texto: Correo Electrónico
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu correo';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Ingresa un correo válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo de Texto: Contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu contraseña';
                      }
                      if (value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Botón Principal de Iniciar Sesión
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Iniciar Sesión'),
                  ),
                  const SizedBox(height: 16),

                  // Enlace hacia la pantalla de Registro mediante ruta nombrada
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '¿No tienes una cuenta? ',
                        style: TextStyle(color: AppColores.textoSecundario),
                      ),
                      TextButton(
                        onPressed: () {
                          // Navegación estandarizada por ruta nombrada
                          Navigator.pushNamed(context, '/register');
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColores.oscuro,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        child: const Text('Regístrate'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
