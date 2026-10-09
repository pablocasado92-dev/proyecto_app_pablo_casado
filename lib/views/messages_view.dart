import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/data_holder.dart';
import '../fb_objects/mensaje.dart';
import '../ins_lib/bot_bars/ins_bot_bar_style1.dart';
import '../ins_lib/theme/app_theme.dart';

/// ============================================================================
/// VISTA DE MENSAJES (MessagesView)
/// ============================================================================
/// Muestra la lista de mensajes en tiempo real leídos de la colección "Mensajes".
class MessagesView extends StatefulWidget {
  const MessagesView({super.key});

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> {
  int iNumeroMensajes = 0;

  @override
  void initState() {
    super.initState();
    DataHolder.instance.iBotBarIndex = 2;
    DataHolder.instance.sMessagesBadgeText = "";
    _inicializarMensajes();
  }

  void _inicializarMensajes() {
    final perfil = DataHolder.instance.perfilUsuario;
    perfil.marcarMensajesLeidos();
    perfil.setOnMessageReceived(mensajeRecibido);
    setState(() {
      iNumeroMensajes = perfil.mensajes.length;
    });
  }

  void mensajeRecibido(int iMensajesTotales) {
    if (!mounted) return;
    setState(() {
      iNumeroMensajes = iMensajesTotales;
    });
  }

  void onPressedFloatingButton() {
    final String myUid = DataHolder.instance.perfilUsuario.uid;

    Mensaje mensajeNuevo = Mensaje.initCampos(
      "",
      "Nuevo mensaje en la colección Mensajes #${iNumeroMensajes + 1}",
      myUid, // destinatarioUID
      myUid, // remitenteUID
      Timestamp.now(),
      titulo: "Mensaje #${iNumeroMensajes + 1}",
    );

    DataHolder.instance.perfilUsuario.agregarNuevoMensaje(mensajeNuevo);
  }

  void _mostrarDetalleMensaje(BuildContext context, Mensaje mensaje) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadios.cabecera)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppEspacios.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.mail_rounded, color: AppColores.oscuro, size: 28),
                  const SizedBox(width: AppEspacios.sm),
                  Expanded(
                    child: Text(
                      mensaje.titulo ?? "Detalle del Mensaje",
                      style: AppTextos.tituloLista,
                    ),
                  ),
                ],
              ),
              const Divider(height: AppEspacios.lg),
              if (mensaje.remitenteUID != null && mensaje.remitenteUID!.isNotEmpty) ...[
                Text("De: ${mensaje.remitenteUID}", style: AppTextos.secundario),
                const SizedBox(height: AppEspacios.xs),
              ],
              SelectableText(
                mensaje.cuerpo ?? "Sin contenido",
                style: AppTextos.cuerpo,
              ),
              const SizedBox(height: AppEspacios.lg),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cerrar"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget creadorDeItem(BuildContext context, int indice) {
    Color colorIcono = AppColores.oscuro;
    Color colorFondo = AppColores.suave;
    if (indice % 2 == 0) {
      colorFondo = AppColores.divisor;
    }

    final perfil = DataHolder.instance.perfilUsuario;
    if (indice >= perfil.mensajes.length) {
      return const SizedBox.shrink();
    }

    final mensaje = perfil.mensajes[indice];

    return GestureDetector(
      onTap: () {
        DataHolder.instance.mensajeSeleccionado = mensaje;
        _mostrarDetalleMensaje(context, mensaje);
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppEspacios.md - AppEspacios.xs),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadios.imagen),
                child: Container(
                  color: colorFondo,
                  width: AppEspacios.imagenLista,
                  height: AppEspacios.imagenLista,
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    color: colorIcono,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: AppEspacios.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mensaje.titulo ?? (mensaje.cuerpo ?? "Sin título"),
                      style: AppTextos.tituloLista,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppEspacios.xs),
                    Text(
                      mensaje.cuerpo ?? "Sin contenido",
                      style: AppTextos.secundario,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColores.textoSecundario),
            ],
          ),
        ),
      ),
    );
  }

  Widget creadorDeSeparador(BuildContext context, int indice) {
    return const SizedBox(height: AppEspacios.md - AppEspacios.xs);
  }

  Widget crearLista() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppEspacios.md, AppEspacios.md, AppEspacios.md, AppEspacios.xl * 3),
      itemCount: iNumeroMensajes,
      itemBuilder: creadorDeItem,
      separatorBuilder: creadorDeSeparador,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mensajes"),
      ),
      body: SafeArea(
        bottom: false,
        child: crearLista(),
      ),
      bottomNavigationBar: InsBotBarStyle1(
        blBadge1: DataHolder.instance.blNotificacionesBadge,
        sBadge2: DataHolder.instance.sMessagesBadgeText,
        iBarIndex: DataHolder.instance.iBotBarIndex,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onPressedFloatingButton,
        tooltip: 'Añadir Mensaje',
        child: const Icon(Icons.add),
      ),
    );
  }
}
