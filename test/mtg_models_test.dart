import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_pablo_casado/fb_objects/mazo.dart';
import 'package:proyecto_app_pablo_casado/fb_objects/partida.dart';
import 'package:proyecto_app_pablo_casado/fb_objects/perfil.dart';

void main() {
  group('MTG Models Unit Tests', () {
    test('Perfil - Serialización y deserialización de campos MTG', () {
      final perfil = Perfil(
        uid: 'user_mtg_01',
        name: 'Urza Planeswalker',
        edad: 30,
        email: 'urza@dominaria.com',
        formatosPreferidos: ['Commander', 'Modern'],
        nivelJuego: 'Competitivo',
        biografiaMTG: 'Creador de artefactos y jugador de Commander cEDH.',
      );

      final map = perfil.toFirestore();
      expect(map['name'], 'Urza Planeswalker');
      expect(map['formatosPreferidos'], ['Commander', 'Modern']);
      expect(map['nivelJuego'], 'Competitivo');
      expect(map['biografiaMTG'], contains('cEDH'));
    });

    test('Partida - Cálculo de plazas libres y estado lleno', () {
      final partida = Partida(
        id: 'mesa_01',
        titulo: 'Mesa Commander 4P',
        formato: 'Commander',
        creadorUID: 'urza',
        creadorNombre: 'Urza',
        maxJugadores: 4,
        jugadoresUIDs: ['urza', 'mishra'],
        fechaHora: Timestamp.now(),
        ubicacionNombre: 'Tienda Dominaria',
        posicion: const GeoPoint(40.4168, -3.7038),
        esTorneo: false,
      );

      expect(partida.plazasLibres, 2);
      expect(partida.estaLlena, isFalse);

      final map = partida.toFirestore();
      expect(map['titulo'], 'Mesa Commander 4P');
      expect(map['maxJugadores'], 4);
      expect(map['jugadoresUIDs'], ['urza', 'mishra']);
    });

    test('Mazo - Conteo de cartas en formato texto Moxfield / MTGGoldfish', () {
      const textoMazo = '''
// Commander
1 Atraxa, Praetors' Voice

// Tierras y Aceleración
1 Sol Ring
1 Command Tower
4 Plains
4 Island
4 Swamp
4 Forest
''';

      final total = Mazo.contarCartasDeTexto(textoMazo);
      // 1 + 1 + 1 + 4 + 4 + 4 + 4 = 19
      expect(total, 19);

      final mazo = Mazo(
        id: 'mazo_01',
        propietarioUID: 'urza',
        titulo: 'Atraxa Proliferate',
        formato: 'Commander',
        comandante: "Atraxa, Praetors' Voice",
        listaTexto: textoMazo,
      );

      final map = mazo.toFirestore();
      expect(map['titulo'], 'Atraxa Proliferate');
      expect(map['formato'], 'Commander');
      expect(map['numCartas'], 19);
      expect(map['esPublico'], isTrue);
    });
  });
}
