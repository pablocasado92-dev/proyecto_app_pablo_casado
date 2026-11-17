// =====================================================================
// mazos_view.dart — BIBLIOTECA DE MAZOS DE MAGIC: THE GATHERING
// ---------------------------------------------------------------------
// Permite a los duelistas gestionar, crear, editar y eliminar sus barajas
// de MTG clasificadas por formatos reglamentarios (Commander, Modern, etc.).
// Compatible con listas de cartas en texto plano (Moxfield / MTGGoldfish).
// =====================================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/data_holder.dart';
import '../fb_objects/mazo.dart';
import '../ins_lib/bot_bars/ins_bot_bar_style1.dart';
import '../ins_lib/theme/app_theme.dart';
import '../ins_lib/theme/wubrg_badge_bar.dart';

class MazosView extends StatefulWidget {
  const MazosView({super.key});

  @override
  State<MazosView> createState() => _MazosViewState();
}

class _MazosViewState extends State<MazosView> {
  bool _cargando = true;
  String? _error;
  List<Mazo> _misMazos = [];

  static const List<String> _formatosDisponibles = [
    'Commander',
    'Modern',
    'Standard',
    'Pioneer',
    'Pauper',
    'Premodern',
    'Draft/Limited',
  ];

  @override
  void initState() {
    super.initState();
    _cargarMazos();
  }

  /// Carga puntual bajo demanda (get puntual para coste 0 en Firebase Blaze)
  Future<void> _cargarMazos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final String uid =
        FirebaseAuth.instance.currentUser?.uid ??
        DataHolder.instance.perfilUsuario.uid;

    if (uid.isEmpty) {
      setState(() {
        _cargando = false;
        _misMazos = [];
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("Mazos")
          .withConverter<Mazo>(
            fromFirestore: Mazo.fromFirestore,
            toFirestore: (Mazo m, _) => m.toFirestore(),
          )
          .where("propietarioUID", isEqualTo: uid)
          .get();

      final mazos = snapshot.docs.map((d) => d.data()).toList();
      mazos.sort((a, b) {
        final aTime =
            a.fechaActualizacion?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.fechaActualizacion?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      if (!mounted) return;
      setState(() {
        _misMazos = mazos;
        _cargando = false;
      });
    } catch (e) {
      debugPrint("Error al cargar mazos: $e");
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = "Error al cargar la biblioteca de mazos: $e";
      });
    }
  }

  /// Modal para crear una nueva baraja o editar una existente
  void _mostrarModalEditorMazo({Mazo? mazoExistente}) {
    final formKey = GlobalKey<FormState>();
    final tituloController = TextEditingController(
      text: mazoExistente?.titulo ?? '',
    );
    final comandanteController = TextEditingController(
      text: mazoExistente?.comandante ?? '',
    );
    final listaController = TextEditingController(
      text: mazoExistente?.listaTexto ?? '',
    );

    String formatoSeleccionado =
        mazoExistente?.formato ?? _formatosDisponibles.first;
    List<String> coloresSeleccionados = List<String>.from(
      mazoExistente?.colores ?? [],
    );
    bool esPublico = mazoExistente?.esPublico ?? true;
    bool guardando = false;

    // Símbolos estándar WUBRG + Incoloro (C)
    const simbolosWubrg = [
      {'sigla': 'W', 'nombre': 'Blanco'},
      {'sigla': 'U', 'nombre': 'Azul'},
      {'sigla': 'B', 'nombre': 'Negro'},
      {'sigla': 'R', 'nombre': 'Rojo'},
      {'sigla': 'G', 'nombre': 'Verde'},
      {'sigla': 'C', 'nombre': 'Incoloro'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColores.tarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadios.cabecera),
        ),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final int conteoCartas = Mazo.contarCartasDeTexto(
              listaController.text,
            );

            return Padding(
              padding: EdgeInsets.only(
                left: AppEspacios.md,
                right: AppEspacios.md,
                top: AppEspacios.md,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColores.divisor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            mazoExistente == null
                                ? Icons.add_circle_outline_rounded
                                : Icons.edit_note_rounded,
                            color: AppColores.oscuro,
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            mazoExistente == null
                                ? 'Nueva Baraja MTG'
                                : 'Editar Baraja',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColores.texto,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Título del Mazo
                      TextFormField(
                        controller: tituloController,
                        decoration: InputDecoration(
                          labelText: 'Nombre de la baraja',
                          hintText: 'ej. Atraxa Superfriends, Murktide Tempo',
                          prefixIcon: const Icon(Icons.style_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadios.campo,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Introduce un nombre para la baraja';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Formato reglamentario
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        dropdownColor: AppColores.tarjeta,
                        initialValue: formatoSeleccionado,
                        decoration: InputDecoration(
                          labelText: 'Formato MTG',
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadios.campo,
                            ),
                          ),
                        ),
                        items: _formatosDisponibles.map((f) {
                          return DropdownMenuItem(value: f, child: Text(f));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              formatoSeleccionado = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Identidad Cromática WUBRG
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Identidad Cromática (WUBRG):',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColores.textoSecundario,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: simbolosWubrg.map((simbolo) {
                              final sigla = simbolo['sigla']!;
                              final nombre = simbolo['nombre']!;
                              final seleccionada = coloresSeleccionados
                                  .contains(sigla);
                              final colorMana = MtgColores.colorParaSimbolo(
                                sigla,
                              );
                              final colorTexto = (sigla == 'W')
                                  ? Colors.black87
                                  : Colors.white;

                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    if (seleccionada) {
                                      coloresSeleccionados.remove(sigla);
                                    } else {
                                      // Si se selecciona un color específico y estaba solo 'C', remover 'C'
                                      if (sigla != 'C') {
                                        coloresSeleccionados.remove('C');
                                      } else {
                                        coloresSeleccionados.clear();
                                      }
                                      coloresSeleccionados.add(sigla);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: seleccionada
                                        ? colorMana
                                        : AppColores.suave,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: seleccionada
                                          ? AppColores.dorado
                                          : AppColores.divisor,
                                      width: seleccionada ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: colorMana,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white30,
                                            width: 0.8,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          sigla,
                                          style: TextStyle(
                                            color: colorTexto,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        nombre,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: seleccionada
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: seleccionada
                                              ? colorTexto
                                              : AppColores.texto,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Comandante (si aplica)
                      if (formatoSeleccionado == 'Commander') ...[
                        TextFormField(
                          controller: comandanteController,
                          decoration: InputDecoration(
                            labelText: 'Comandante principal',
                            hintText: 'ej. Atraxa, Praetors\' Voice',
                            prefixIcon: const Icon(Icons.shield_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadios.campo,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Lista de cartas (Moxfield / Texto plano)
                      TextFormField(
                        controller: listaController,
                        maxLines: 6,
                        onChanged: (_) {
                          setModalState(() {});
                        },
                        decoration: InputDecoration(
                          labelText:
                              'Lista de cartas (Formato Moxfield / Texto)',
                          hintText: '1 Sol Ring\n1 Command Tower\n4 Lightning Bolt...',
                          helperText:
                              '$conteoCartas cartas contabilizadas en la baraja',
                          helperStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColores.oscuro,
                          ),
                          prefixIcon: const Icon(
                            Icons.format_list_numbered_rounded,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadios.campo,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Baraja Pública
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Visible en comunidad (Pública)'),
                        subtitle: const Text(
                          'Permite a otros Planeswalkers ver tu baraja',
                        ),
                        value: esPublico,
                        activeTrackColor: AppColores.oscuro,
                        onChanged: (val) {
                          setModalState(() {
                            esPublico = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Botón Guardar
                      FilledButton.icon(
                        onPressed: guardando
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() {
                                  guardando = true;
                                });

                                final String uid =
                                    FirebaseAuth.instance.currentUser?.uid ??
                                    DataHolder.instance.perfilUsuario.uid;

                                try {
                                  final String docId =
                                      mazoExistente?.id ??
                                      FirebaseFirestore.instance
                                          .collection("Mazos")
                                          .doc()
                                          .id;

                                  final nuevoMazo = Mazo(
                                    id: docId,
                                    propietarioUID: uid,
                                    titulo: tituloController.text.trim(),
                                    formato: formatoSeleccionado,
                                    colores: coloresSeleccionados,
                                    comandante:
                                        comandanteController.text
                                            .trim()
                                            .isNotEmpty
                                        ? comandanteController.text.trim()
                                        : null,
                                    listaTexto: listaController.text.trim(),
                                    numCartas: Mazo.contarCartasDeTexto(
                                      listaController.text,
                                    ),
                                    esPublico: esPublico,
                                    fechaActualizacion: Timestamp.now(),
                                  );

                                  await FirebaseFirestore.instance
                                      .collection("Mazos")
                                      .doc(docId)
                                      .set(
                                        nuevoMazo.toFirestore(),
                                        SetOptions(merge: true),
                                      );

                                  if (modalCtx.mounted) {
                                    Navigator.pop(modalCtx);
                                  }

                                  await _cargarMazos();

                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        mazoExistente == null
                                            ? 'Baraja creada con éxito'
                                            : 'Baraja actualizada',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  debugPrint("Error guardando mazo: $e");
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error al guardar: $e'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                } finally {
                                  setModalState(() {
                                    guardando = false;
                                  });
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColores.oscuro,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: guardando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          guardando ? 'Guardando...' : 'Guardar Baraja',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Confirmación y borrado de mazo
  void _confirmarEliminarMazo(Mazo mazo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar baraja'),
        content: Text(
          '¿Deseas eliminar permanentemente la baraja "${mazo.titulo}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance
                    .collection("Mazos")
                    .doc(mazo.id)
                    .delete();

                await _cargarMazos();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Baraja eliminada'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al eliminar baraja: $e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de Mazos MTG'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recargar barajas',
            onPressed: _cargarMazos,
          ),
        ],
      ),
      bottomNavigationBar: InsBotBarStyle1(
        iBarIndex: 0,
        sBadge2: DataHolder.instance.sMessagesBadgeText,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarModalEditorMazo(),
        backgroundColor: AppColores.oscuro,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo Mazo'),
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _cargarMazos,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : _misMazos.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColores.suave,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.style_outlined,
                          size: 64,
                          color: AppColores.oscuro,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Aún no tienes barajas registradas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColores.texto,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Crea tu primer mazo de Commander, Modern o Standard y compártelo con tu Playgroup.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _mostrarModalEditorMazo(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColores.oscuro,
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Crear Mazo Ahora'),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _misMazos.length,
                itemBuilder: (context, index) {
                  final mazo = _misMazos[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColores.divisor),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColores.suave,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.style_rounded,
                          color: AppColores.oscuro,
                        ),
                      ),
                      title: Text(
                        mazo.titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColores.oscuro,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  mazo.formato,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                '${mazo.numCartas} cartas',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColores.textoSecundario,
                                ),
                              ),
                              if (mazo.colores.isNotEmpty)
                                WubrgBadgeBar(
                                  colores: mazo.colores,
                                  tamano: 16.0,
                                ),
                            ],
                          ),
                          if (mazo.comandante != null &&
                              mazo.comandante!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Comandante: ${mazo.comandante}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: AppColores.texto,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: AppColores.oscuro,
                            ),
                            tooltip: 'Editar',
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            onPressed: () =>
                                _mostrarModalEditorMazo(mazoExistente: mazo),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Eliminar',
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            onPressed: () => _confirmarEliminarMazo(mazo),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
