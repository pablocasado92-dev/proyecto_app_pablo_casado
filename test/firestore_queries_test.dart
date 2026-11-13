import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_pablo_casado/admins/queries_admin.dart';
import 'package:proyecto_app_pablo_casado/fb_objects/perfil.dart';

void main() {
  group(
    'Bloque 2: Consultas que responden preguntas (0486 AD RA4.e · RA4.g)',
    () {
      test('DTO ResultadoPaginacionPerfil preserva estado de paginación', () {
        final perfiles = [
          Perfil(uid: 'u1', name: 'Ana', edad: 25),
          Perfil(uid: 'u2', name: 'Bernardo', edad: 30),
        ];

        final resultado = ResultadoPaginacionPerfil(
          perfiles: perfiles,
          ultimoDocumento: null,
          hayMas: true,
        );

        expect(resultado.perfiles.length, equals(2));
        expect(resultado.ultimoDocumento, isNull);
        expect(resultado.hayMas, isTrue);
      });

      test(
        'Consulta 1: where doble condición (conectado == true && edad >= 18)',
        () {
          final dataset = [
            Perfil(
              uid: 'u1',
              name: 'Menor Conectado',
              edad: 16,
              conectado: true,
            ),
            Perfil(
              uid: 'u2',
              name: 'Adulto Desconectado',
              edad: 25,
              conectado: false,
            ),
            Perfil(
              uid: 'u3',
              name: 'Adulto Conectado 1',
              edad: 18,
              conectado: true,
            ),
            Perfil(
              uid: 'u4',
              name: 'Adulto Conectado 2',
              edad: 35,
              conectado: true,
            ),
          ];

          final filtrados = dataset
              .where((p) => p.conectado && (p.edad != null && p.edad! >= 18))
              .toList();

          expect(filtrados.length, equals(2));
          expect(filtrados.map((p) => p.uid), containsAll(['u3', 'u4']));
          expect(filtrados.map((p) => p.uid), isNot(contains('u1')));
          expect(filtrados.map((p) => p.uid), isNot(contains('u2')));
        },
      );

      test('Consulta 2: orderBy con limit (Top 5 más recientes)', () {
        final ahora = DateTime.now();
        final dataset = List.generate(
          10,
          (i) => Perfil(
            uid: 'u_$i',
            name: 'Usuario $i',
            fechaRegistro: Timestamp.fromDate(
              ahora.subtract(Duration(days: i)),
            ),
          ),
        );

        // Ordenar descendente por fechaRegistro y tomar 5
        final ordenados = List<Perfil>.from(dataset)
          ..sort((a, b) {
            final fa = a.fechaRegistro!.toDate();
            final fb = b.fechaRegistro!.toDate();
            return fb.compareTo(fa);
          });

        final top5 = ordenados.take(5).toList();

        expect(top5.length, equals(5));
        expect(top5.first.uid, equals('u_0')); // El más reciente
        expect(top5.last.uid, equals('u_4'));
      });

      test('Consulta 3: Rango de fechas (últimos 30 días)', () {
        final ahora = DateTime.now();
        final inicio = ahora.subtract(const Duration(days: 30));

        final dataset = [
          Perfil(
            uid: 'antiguo',
            fechaRegistro: Timestamp.fromDate(
              ahora.subtract(const Duration(days: 45)),
            ),
          ),
          Perfil(
            uid: 'dentro1',
            fechaRegistro: Timestamp.fromDate(
              ahora.subtract(const Duration(days: 10)),
            ),
          ),
          Perfil(
            uid: 'dentro2',
            fechaRegistro: Timestamp.fromDate(
              ahora.subtract(const Duration(days: 2)),
            ),
          ),
          Perfil(
            uid: 'muy_antiguo',
            fechaRegistro: Timestamp.fromDate(
              ahora.subtract(const Duration(days: 90)),
            ),
          ),
        ];

        final enRango = dataset.where((p) {
          if (p.fechaRegistro == null) return false;
          final f = p.fechaRegistro!.toDate();
          return f.isAfter(inicio) && f.isBefore(ahora);
        }).toList();

        expect(enRango.length, equals(2));
        expect(enRango.map((p) => p.uid), containsAll(['dentro1', 'dentro2']));
        expect(enRango.map((p) => p.uid), isNot(contains('antiguo')));
      });

      test('Consulta 4: Paginación determinista en lotes de tamaño 5', () {
        final totalDocs = List.generate(
          12,
          (i) => Perfil(
            uid: 'id_$i',
            name: 'User ${(i + 1).toString().padLeft(2, '0')}',
          ),
        );

        // Página 1: primeros 5
        final pagina1 = totalDocs.take(5).toList();
        expect(pagina1.length, equals(5));
        expect(pagina1.first.name, equals('User 01'));
        expect(pagina1.last.name, equals('User 05'));

        // Página 2: siguientes 5
        final pagina2 = totalDocs.skip(5).take(5).toList();
        expect(pagina2.length, equals(5));
        expect(pagina2.first.name, equals('User 06'));
        expect(pagina2.last.name, equals('User 10'));

        // Página 3: restantes 2
        final pagina3 = totalDocs.skip(10).take(5).toList();
        expect(pagina3.length, equals(2));
        expect(pagina3.first.name, equals('User 11'));
        expect(pagina3.last.name, equals('User 12'));
      });
    },
  );

  group('Bloque 3: Modificar y borrar (0486 AD RA4.f)', () {
    test('Modelo Perfil serializa campos modificados para update', () {
      final perfil = Perfil(
        uid: 'user_mod_1',
        name: 'Nombre Actualizado',
        edad: 32,
        conectado: true,
      );

      final map = perfil.toFirestore();
      expect(map['name'], equals('Nombre Actualizado'));
      expect(map['edad'], equals(32));
      expect(map['conectado'], isTrue);
    });
  });
}
