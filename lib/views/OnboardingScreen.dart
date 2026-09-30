import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

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

  Future<void> _completeOnboarding() async {
    // Guardar en SharedPreferences que el usuario ya vio el onboarding
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (!mounted) return;

    // Navegar a la pantalla principal y reemplazar la ruta actual
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MyHomePage(title: 'Flutter Demo Home Page'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Botón Saltar arriba
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
            // Páginas deslizables (PageView)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (index) {
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
            // Indicadores de puntos y Botón Siguiente / Comenzar
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicadores (dots)
                  Row(
                    children: List.generate(
                      _items.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
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
                  // Botón Siguiente o Comenzar
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
                        horizontal: 24,
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
            ),
          ],
        ),
      ),
    );
  }
}

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
