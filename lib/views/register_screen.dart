import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/data_holder.dart';
import '../ins_lib/theme/app_theme.dart';

/// ============================================================================
/// PANTALLA DE REGISTRO DE USUARIOS (RegisterScreen)
/// ============================================================================
/// Esta vista permite crear una nueva cuenta de usuario en Firebase Authentication,
/// registrando su documento de perfil en la colección "Perfiles" de Firestore.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Clave global para validaciones de formulario
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto para los campos del formulario
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Selección de edad mediante menú desplegable (1 a 100 años)
  int? _selectedEdad;

  // Estados locales para la visibilidad de contraseña y carga
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Procesa el registro de un nuevo usuario en Firebase Auth y Firestore
  Future<void> _handleRegister() async {
    // 1. Validar que el formulario sea correcto
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Activar el indicador de carga
      });

      try {
        // 2. Crear el nuevo usuario en Firebase Authentication
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        final String uid = userCredential.user!.uid;

        // 3. Guardar el nombre completo (displayName) en el perfil de Firebase Auth
        await userCredential.user?.updateDisplayName(
          _nameController.text.trim(),
        );

        // 4. Crear el documento de perfil en la colección "Perfiles" de Firestore
        // utilizando conversión tipada (.withConverter<Perfil>) e indicando primerLogin = true
        final nuevoPerfil = Perfil(
          uid: uid,
          name: _nameController.text.trim(),
          edad: _selectedEdad,
          email: _emailController.text.trim(),
          fechaRegistro: Timestamp.now(),
          primerLogin: true,
        );

        await FirebaseFirestore.instance
            .collection("Perfiles")
            .doc(uid)
            .withConverter<Perfil>(
              fromFirestore: Perfil.fromFirestore,
              toFirestore: (Perfil p, _) => p.toFirestore(),
            )
            .set(nuevoPerfil);

        // 5. Asignar el perfil en el DataHolder global y activar escuchas
        DataHolder.instance.perfilUsuario = nuevoPerfil;
        await nuevoPerfil.descargarMensajes();

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // 6. Notificar éxito y navegar al Onboarding justo antes de ir a Home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Registro exitoso en Firebase!')),
        );

        Navigator.pushReplacementNamed(context, '/onboarding');
      } on FirebaseAuthException catch (e) {
        // Captura de errores específicos devueltos por el servidor de Firebase Auth
        setState(() {
          _isLoading = false;
        });

        String errorMessage = 'Error en el registro';
        if (e.code == 'email-already-in-use') {
          errorMessage = 'Este correo electrónico ya está registrado.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'La contraseña es demasiado débil.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'El formato del correo electrónico no es válido.';
        } else {
          errorMessage = e.message ?? errorMessage;
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      } catch (e) {
        // Captura de otros errores imprevistos
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

  /// BLOQUE 1: Registro / Inicio de sesión rápido con cuenta de Google
  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await DataHolder.instance.firebaseAdmin
          .iniciarSesionConGoogle();

      // RF-04: Si el usuario canceló o cerró el diálogo de Google, salir silenciosamente
      if (credential == null || credential.user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Sincronizar en memoria y descargar perfil de Firestore
      DataHolder().userEmail = credential.user!.email ?? '';
      try {
        await DataHolder.instance.descargarPerfil().timeout(
          const Duration(seconds: 4),
        );
      } catch (e) {
        debugPrint("Error descargando perfil tras registro con Google: $e");
      }

      // Activar presencia online
      DataHolder.instance.iniciarPresencia();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Navegar según el estado del usuario (Onboarding o Home)
      if (DataHolder.instance.perfilUsuario.primerLogin) {
        Navigator.pushReplacementNamed(context, '/onboarding');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error con Google: ${e.message ?? e.code}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrarse con Google: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: AppColores.suave,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 44,
                        color: AppColores.oscuro,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Crea tu cuenta',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColores.oscuro,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Completa tus datos para comenzar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Campo de Texto: Nombre Completo
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu nombre';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Menú Desplegable: Selección de Edad (16 a 99 años)
                  DropdownButtonFormField<int>(
                    initialValue: _selectedEdad,
                    decoration: const InputDecoration(
                      labelText: 'Edad',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    items: List.generate(84, (index) {
                      final edad = 16 + index; // Rango de 16 a 99 años
                      return DropdownMenuItem<int>(
                        value: edad,
                        child: Text('$edad años'),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        _selectedEdad = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Por favor selecciona tu edad';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

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
                        return 'Por favor ingresa una contraseña';
                      }
                      if (value.length < 6) {
                        return 'Debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo de Texto: Confirmar Contraseña
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: const Icon(Icons.lock_reset_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor confirma tu contraseña';
                      }
                      if (value != _passwordController.text) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Botón Principal de Registro
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Registrarse'),
                  ),
                  const SizedBox(height: 20),

                  // Separador visual: "o regístrate con"
                  Row(
                    children: const [
                      Expanded(child: Divider(color: AppColores.divisor)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          'o regístrate con',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColores.textoSecundario,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColores.divisor)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // BLOQUE 1: Botón de Registro con Google
                  OutlinedButton(
                    onPressed: _isLoading ? null : _handleGoogleSignUp,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(
                        color: AppColores.divisor,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'G',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Registrarse con Google',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColores.oscuro,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Enlace hacia la pantalla de Inicio de Sesión
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '¿Ya tienes una cuenta? ',
                        style: TextStyle(color: AppColores.textoSecundario),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColores.oscuro,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Inicia Sesión'),
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
