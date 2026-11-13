import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_pablo_casado/fb_objects/mensaje.dart';
import 'package:proyecto_app_pablo_casado/fb_objects/perfil.dart';

void main() {
  group(
    'SPEC-001 / Bloque 1: Pruebas de integración de perfil con Google Auth',
    () {
      test(
        'RF-05: Mapeo correcto de Perfil a partir de credenciales de Google',
        () {
          final ahora = Timestamp.now();
          final perfilGoogle = Perfil(
            uid: 'google-user-12345',
            name: 'Estudiante Google',
            email: 'estudiante@gmail.com',
            urlAvatar: 'https://lh3.googleusercontent.com/a/avatar_ejemplo',
            fechaRegistro: ahora,
            primerLogin: false,
            conectado: true,
            ultimaConexion: ahora,
          );

          expect(perfilGoogle.uid, equals('google-user-12345'));
          expect(perfilGoogle.name, equals('Estudiante Google'));
          expect(perfilGoogle.email, equals('estudiante@gmail.com'));
          expect(
            perfilGoogle.urlAvatar,
            startsWith('https://lh3.googleusercontent.com'),
          );
          expect(perfilGoogle.primerLogin, isFalse);
          expect(perfilGoogle.conectado, isTrue);

          final map = perfilGoogle.toFirestore();
          expect(map['name'], equals('Estudiante Google'));
          expect(map['email'], equals('estudiante@gmail.com'));
          expect(
            map['urlAvatar'],
            equals('https://lh3.googleusercontent.com/a/avatar_ejemplo'),
          );
          expect(map['primerLogin'], isFalse);
          expect(map['conectado'], isTrue);
        },
      );

      test('Edge Case: Usuario de Google sin avatar (photoURL nulo)', () {
        final perfilSinFoto = Perfil(
          uid: 'google-sin-foto',
          name: 'Usuario Sin Foto',
          email: 'sinfoto@gmail.com',
          urlAvatar: null,
          primerLogin: false,
          conectado: true,
        );

        expect(perfilSinFoto.urlAvatar, isNull);
        final map = perfilSinFoto.toFirestore();
        expect(map.containsKey('urlAvatar'), isTrue);
        expect(map['urlAvatar'], isNull);
      });

      test('RF-08 / Bug-03: Validación del modelo Mensaje con destinatario Email y respuesta por UID', () {
        final m1 = Mensaje.initCampos(
          'm1',
          'Mensaje enviado con email',
          'contacto@gmail.com',
          'mi-uid-123',
          Timestamp.now(),
        );

        final m2 = Mensaje.initCampos(
          'm2',
          'Mensaje respondido con UID',
          'mi-uid-123',
          'uid-contacto-456',
          Timestamp.now(),
        );

        expect(m1.destinatarioUID, equals('contacto@gmail.com'));
        expect(m1.remitenteUID, equals('mi-uid-123'));
        expect(m2.destinatarioUID, equals('mi-uid-123'));
        expect(m2.remitenteUID, equals('uid-contacto-456'));
      });
    },
  );
}
