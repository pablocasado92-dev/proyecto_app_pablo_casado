import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================================
/// BLOQUE 2: PANTALLA DE INTRODUCCIÓN / ONBOARDING (OnboardingScreen)
/// ============================================================================
/// Esta vista muestra 3 tarjetas deslizables de bienvenida la primera vez que
/// se abre la aplicación. Guarda una marca en SharedPreferences al finalizar
/// o al pulsar "Saltar", asegurando que no vuelva a aparecer en inicios posteriores.
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
      description: 'Descubre todas las funcionalidades increíbles que tenemos preparadas para ti.',
      icon: Icons.explore,
      color: Colors.deepPurple,
    ),
    OnboardingItem(
      title: 'Conéctate con la Nube',
      description: 'Sincroniza tus datos en tiempo real gracias a nuestra integración con Firebase y Firestore.',
      icon: Icons.cloud_sync,
      color: Colors.indigo,
    ),
    OnboardingItem(
      title: 'Empieza a Disfrutar',
      description: 'Todo está listo para comenzar. ¡Pulsa el botón de abajo y descubre la experiencia!',
      icon: Icons.rocket_launch,
      color: Colors.deepOrange,
    ),
  ];

  /// Marca el onboarding como visto en SharedPreferences y navega al Login
  Future<void> _completeOnboarding() async {
    // 1. Guardar de forma persistente que el usuario ya vio el onboarding
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (!mounted) return;

    // 2. Navegar a la pantalla de Login mediante ruta nombrada
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Botón Superior Derecho para Saltar el Onboarding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentPage < _items.length - 1)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: const Text(
                        'Saltar',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                          child: Icon(
                            item.icon,
                            size: 100,
                            color: item.color,
                          ),
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
                          : const SizedBox(width: 70), // Espaciador para mantener alineación
                      
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _currentPage == _items.length - 1 ? 'Comenzar' : 'Siguiente',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
