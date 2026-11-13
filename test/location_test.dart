import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_pablo_casado/fb_objects/perfil.dart';

void main() {
  group(
    'SPEC-002 / Bloque 5: Pruebas TDD de Geolocalización en Modelo Perfil',
    () {
      test('RF-06 / RF-07: Serialización y deserialización de GeoPoint y Timestamp de posición', () {
        final ahora = Timestamp.now();
        const double latEsperada = 40.416775;
        const double lngEsperada = -3.703790;
        final GeoPoint posicionEsperada = GeoPoint(latEsperada, lngEsperada);

        final perfil = Perfil(
          uid: 'user-geo-123',
          name: 'Pablo Geo',
          email: 'pablo.geo@example.com',
          posicion: posicionEsperada,
          fechaPosicion: ahora,
        );

        expect(perfil.posicion, isNotNull);
        expect(perfil.posicion!.latitude, closeTo(latEsperada, 0.0001));
        expect(perfil.posicion!.longitude, closeTo(lngEsperada, 0.0001));
        expect(perfil.fechaPosicion, equals(ahora));

        // Conversión a mapa de Firestore
        final map = perfil.toFirestore();
        expect(map.containsKey('posicion'), isTrue);
        expect(map['posicion'], isA<GeoPoint>());
        expect(
          (map['posicion'] as GeoPoint).latitude,
          closeTo(latEsperada, 0.0001),
        );
        expect(map.containsKey('fechaPosicion'), isTrue);
        expect(map['fechaPosicion'], equals(ahora));
      });

      test(
        'Edge Case: Perfil sin posición registrada (campos opcionales nulos)',
        () {
          final perfilSinUbicacion = Perfil(
            uid: 'user-sin-geo',
            name: 'Usuario Sin Geo',
          );

          expect(perfilSinUbicacion.posicion, isNull);
          expect(perfilSinUbicacion.fechaPosicion, isNull);

          final map = perfilSinUbicacion.toFirestore();
          expect(map.containsKey('posicion'), isFalse);
          expect(map.containsKey('fechaPosicion'), isFalse);
        },
      );
    },
  );
}
