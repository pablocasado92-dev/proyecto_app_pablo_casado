import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_pablo_casado/fb_objects/perfil.dart';

void main() {
  group('Perfil - Bloque 4: Miniatura Base64 en Firestore', () {
    test('Serialización y deserialización de avatarBase64 en Perfil', () {
      // Cadena base64 simulada representativa de una miniatura pequeña
      const base64Mock =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      final perfil = Perfil(
        uid: 'user_123',
        name: 'Pablo',
        email: 'pablo@test.com',
        urlAvatar: 'https://storage.googleapis.com/test/avatar.jpg',
        avatarBase64: base64Mock,
      );

      final map = perfil.toFirestore();

      expect(map['avatarBase64'], equals(base64Mock));
      expect(
        map['urlAvatar'],
        equals('https://storage.googleapis.com/test/avatar.jpg'),
      );

      // Verificar deserialización con Map
      final perfilRecuperado = Perfil(
        uid: 'user_123',
        name: map['name'] as String?,
        avatarBase64: map['avatarBase64'] as String?,
        urlAvatar: map['urlAvatar'] as String?,
      );

      expect(perfilRecuperado.avatarBase64, equals(base64Mock));
      expect(
        perfilRecuperado.avatarBase64!.length,
        lessThan(300 * 1024),
      ); // Menor a 300 KB
    });
  });
}
