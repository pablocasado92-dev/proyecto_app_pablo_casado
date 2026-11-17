import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Barra de identidad cromática WUBRG de Magic: The Gathering
/// Muestra los círculos de colores de maná del mazo o comandante
class WubrgBadgeBar extends StatelessWidget {
  /// Lista de siglas de color ('W', 'U', 'B', 'R', 'G', 'C')
  final List<String> colores;

  /// Tamaño en píxeles de cada círculo de maná
  final double tamano;

  const WubrgBadgeBar({super.key, required this.colores, this.tamano = 18.0});

  @override
  Widget build(BuildContext context) {
    if (colores.isEmpty) {
      return _buildCirculoMana('C');
    }

    // Orden estándar MTG: W -> U -> B -> R -> G -> C
    const ordenWubrg = ['W', 'U', 'B', 'R', 'G', 'C'];
    final coloresOrdenados = List<String>.from(colores)
      ..sort((a, b) {
        final idxA = ordenWubrg.indexOf(a.toUpperCase());
        final idxB = ordenWubrg.indexOf(b.toUpperCase());
        return (idxA >= 0 ? idxA : 99).compareTo(idxB >= 0 ? idxB : 99);
      });

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: coloresOrdenados.map((c) {
        return Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: _buildCirculoMana(c),
        );
      }).toList(),
    );
  }

  Widget _buildCirculoMana(String simbolo) {
    final s = simbolo.toUpperCase().trim();
    final colorFondo = MtgColores.colorParaSimbolo(s);
    // Para el blanco marfil usamos texto oscuro para legibilidad
    final colorTexto = (s == 'W') ? Colors.black87 : Colors.white;

    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: colorFondo,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 0.8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        s,
        style: TextStyle(
          fontSize: tamano * 0.58,
          fontWeight: FontWeight.bold,
          color: colorTexto,
          height: 1.0,
        ),
      ),
    );
  }
}
