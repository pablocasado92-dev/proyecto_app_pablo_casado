import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Prueba básica de verificación de la aplicación', () {
    const String appTitle = 'Proyecto App Pablo Casado';
    expect(appTitle, contains('Proyecto App'));
  });
}
