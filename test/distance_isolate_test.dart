import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_pablo_casado/admins/location_admin.dart';
import 'package:proyecto_app_pablo_casado/fb_objects/perfil.dart';

void main() {
  group('SPEC-004 / Bloque 6: Cálculo de distancias y ordenación en Isolate', () {
    test('Fórmula de Haversine: calcula la distancia exacta entre Madrid y Barcelona (~505 km)', () {
      // Coordenadas conocidas:
      // Madrid (Puerta del Sol): 40.4168, -3.7038
      // Barcelona (Plaça de Catalunya): 41.3870, 2.1700
      final double distancia = LocationAdmin.calcularDistanciaHaversine(
        40.4168,
        -3.7038,
        41.3870,
        2.1700,
      );

      // Verificamos que la distancia esté en el rango esperado de 500 a 510 km
      expect(distancia, greaterThan(500.0));
      expect(distancia, lessThan(510.0));
    });

    test('Ordenación ascendente por proximidad al usuario', () {
      // Usuario base en Madrid
      const origenLat = 40.4168;
      const origenLng = -3.7038;

      // Contactos de prueba
      final perfilToledo = Perfil(
        uid: 'user_toledo',
        name: 'Carlos (Toledo)',
        posicion: const GeoPoint(39.8628, -4.0273), // ~70 km
      );

      final perfilBarcelona = Perfil(
        uid: 'user_bcn',
        name: 'Marta (Barcelona)',
        posicion: const GeoPoint(41.3870, 2.1700), // ~505 km
      );

      final perfilGetafe = Perfil(
        uid: 'user_getafe',
        name: 'Laura (Getafe)',
        posicion: const GeoPoint(40.3083, -3.7327), // ~12 km
      );

      final listaDesordenada = [perfilBarcelona, perfilToledo, perfilGetafe];

      final resultado = LocationAdmin.ordenarPerfilesSincrono(
        perfiles: listaDesordenada,
        origenLat: origenLat,
        origenLng: origenLng,
      );

      expect(resultado.length, equals(3));
      // El primero debe ser Getafe (~12 km)
      expect(resultado[0].perfil.name, equals('Laura (Getafe)'));
      expect(resultado[0].distanciaKm, lessThan(20.0));

      // El segundo debe ser Toledo (~70 km)
      expect(resultado[1].perfil.name, equals('Carlos (Toledo)'));
      expect(resultado[1].distanciaKm, greaterThan(50.0));
      expect(resultado[1].distanciaKm, lessThan(100.0));

      // El tercero debe ser Barcelona (~505 km)
      expect(resultado[2].perfil.name, equals('Marta (Barcelona)'));
      expect(resultado[2].distanciaKm, greaterThan(500.0));
    });
  });
}
