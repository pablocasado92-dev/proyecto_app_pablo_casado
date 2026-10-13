import 'package:flutter/material.dart';

import '../../data/data_holder.dart';

/// =====================================================================
/// InsBotBarStyle1 — BARRA DE NAVEGACIÓN INFERIOR REUTILIZABLE
/// ---------------------------------------------------------------------
/// Componente de barra de navegación inferior con 2 pestañas:
///   0 Principal -> "/home"
///   1 Mensajes  -> "/conversaciones"
/// =====================================================================
class InsBotBarStyle1 extends StatefulWidget {
  final bool blBadge1;
  final String sBadge2;
  final int iBarIndex;

  const InsBotBarStyle1({
    super.key,
    this.blBadge1 = false,
    required this.sBadge2,
    required this.iBarIndex,
  });

  @override
  State<InsBotBarStyle1> createState() => _InsBotBarStyle1State();
}

class _InsBotBarStyle1State extends State<InsBotBarStyle1> {
  late int _iBarIndex;

  @override
  void initState() {
    super.initState();
    _iBarIndex = widget.iBarIndex;
  }

  void _onItemSelected(int index) {
    if (index == _iBarIndex) return;

    switch (index) {
      case 0:
        Navigator.popAndPushNamed(context, "/home");
        break;
      case 1:
        Navigator.popAndPushNamed(context, "/conversaciones");
        break;
    }
    setState(() {
      _iBarIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hayMensajesSinLeer = DataHolder.instance.tieneMensajesSinLeer();

    return NavigationBar(
      onDestinationSelected: _onItemSelected,
      selectedIndex: _iBarIndex,
      destinations: <Widget>[
        const NavigationDestination(
          selectedIcon: Icon(Icons.home_rounded),
          icon: Icon(Icons.home_outlined),
          label: 'Principal',
        ),
        NavigationDestination(
          selectedIcon: Badge(
            isLabelVisible: hayMensajesSinLeer,
            backgroundColor: Colors.red,
            smallSize: 10,
            child: const Icon(Icons.chat_bubble_rounded),
          ),
          icon: Badge(
            isLabelVisible: hayMensajesSinLeer,
            backgroundColor: Colors.red,
            smallSize: 10,
            child: const Icon(Icons.chat_bubble_outline_rounded),
          ),
          label: 'Mensajes',
        ),
      ],
    );
  }
}
