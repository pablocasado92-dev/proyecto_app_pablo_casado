import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/data_holder.dart';
import '../ins_lib/theme/app_theme.dart';

/// ============================================================================
/// BLOQUE 2: PANTALLA DE INTRODUCCIÓN / ONBOARDING (OnboardingScreen)
/// ============================================================================
/// Esta vista muestra 3 tarjetas deslizables de bienvenida en el primer inicio
/// de sesión del usuario. Actualiza el campo primerLogin a false en Firestore
/// al finalizar o pulsar "Saltar" y navega directamente a Home.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Controlador del PageView para gestionar el desplazamiento entre páginas
  final PageController _pageController = PageController();

  // Índice de la página actualmente visible
  int _currentPage = 0;

  // Lista de elementos que componen las páginas del Onboarding
  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: 'Bienvenido a la App',
      description:
          'Tu espacio para conectar, comunicarte y gestionar tu perfil.',
      icon: Icons.chat_bubble_outline_rounded,
      color: AppColores.oscuro,
    ),
    OnboardingItem(
      title: 'Mensajería en Tiempo Real',
      description:
          'Chatea al instante con tus contactos de forma rápida y segura.',
      icon: Icons.cloud_sync_outlined,
      color: AppColores.oscuro,
    ),
    OnboardingItem(
      title: 'Personaliza tu Perfil',
      description:
          'Configura tu nombre, edad y foto de avatar con total libertad.',
      icon: Icons.person_pin_circle_outlined,
      color: AppColores.oscuro,
    ),
  ];

  /// Marca primerLogin como false en Firestore y DataHolder, y navega a Home
  Future<void> _completeOnboarding() async {
    final perfil = DataHolder.instance.perfilUsuario;
    perfil.primerLogin = false;

    // Actualizar el valor en Firestore para que no vuelva a aparecer en logins posteriores
    if (perfil.uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection("Perfiles")
            .doc(perfil.uid)
            .update({'primerLogin': false});
      } catch (e) {
        debugPrint("Error actualizando primerLogin en Firestore: $e");
      }
    }

    if (!mounted) return;

    // Navegar directamente a la pantalla principal Home
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Botón Superior Derecho para Saltar el Onboarding
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentPage < _items.length - 1)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: const Text(
                        'Saltar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Área de Páginas Deslizables (PageView)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                physics: const AlwaysScrollableScrollPhysics(),
                onPageChanged: (index) {
                  // Actualizar el estado con el nuevo índice de página
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icono circular representativo
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon, size: 100, color: item.color),
                        ),
                        const SizedBox(height: 48),

                        // Título de la página
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: item.color,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Descripción explicativa
                        Text(
                          item.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Indicadores de Puntos Centrados y Botones de Navegación Inferior
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Indicadores animados de puntos (Dots) centrados
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _items.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? _items[_currentPage].color
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Fila de Botones: Anterior / (Siguiente o Comenzar)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Botón Anterior (visible a partir de la segunda página)
                      _currentPage > 0
                          ? TextButton(
                              onPressed: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: const Text('Anterior'),
                            )
                          : const SizedBox(
                              width: 70,
                            ), // Espaciador para mantener alineación
                      // Botón Siguiente / Comenzar
                      ElevatedButton(
                        onPressed: () {
                          if (_currentPage < _items.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _completeOnboarding();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _items[_currentPage].color,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(120, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _currentPage == _items.length - 1
                              ? 'Comenzar'
                              : 'Siguiente',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modelo de datos sencillo para representar cada tarjeta del Onboarding
class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
