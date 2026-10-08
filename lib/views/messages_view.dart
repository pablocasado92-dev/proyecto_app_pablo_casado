import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/data_holder.dart';
import '../fb_objects/mensaje.dart';
import '../ins_lib/bot_bars/ins_bot_bar_style1.dart';
import '../ins_lib/theme/app_theme.dart';

/// ============================================================================
/// FASE 3: VISTA DE MENSAJES (MessagesView)
/// ============================================================================
/// Muestra la lista de mensajes en tiempo real descargados en `perfilUsuario.mensajes`.
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
    DataHolder.instance.perfilUsuario.marcarMensajesLeidos();
    DataHolder.instance.perfilUsuario.setOnMessageReceived(mensajeRecibido);
    iNumeroMensajes = DataHolder.instance.perfilUsuario.mensajes.length;
  }

  void mensajeRecibido(int iMensajesTotales) {
    if (!mounted) return;
    setState(() {
      iNumeroMensajes = iMensajesTotales;
    });
  }

  void onPressedFloatingButton() {
    Mensaje mensajeNuevo = Mensaje.initCampos(
      "",
      "Nuevo Mensaje ${iNumeroMensajes + 1}",
      "Cuerpo del mensaje recibido en tiempo real",
      false,
      Timestamp.now(),
    );

    DataHolder.instance.perfilUsuario.agregarNuevoMensaje(mensajeNuevo);
  }

  Widget creadorDeItem(BuildContext context, int indice) {
    Color color = AppColores.suave;
    String sUrlImg = "https://i.pinimg.com/originals/78/1a/51/781a5128e733c6a36aa6a10814e19548.gif";
    if (indice % 2 == 0) {
      color = AppColores.divisor;
      sUrlImg = "https://media.tenor.com/aGj-frNYMFEAAAAM/cat-cat-dance.gif";
    }

    final mensaje = DataHolder.instance.perfilUsuario.mensajes[indice];

    return GestureDetector(
      onTap: () {
        DataHolder.instance.mensajeSeleccionado = mensaje;
        Navigator.pushNamed(context, "/message_detail");
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppEspacios.md - AppEspacios.xs),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadios.imagen),
                child: Container(
                  color: color,
                  width: AppEspacios.imagenLista,
                  height: AppEspacios.imagenLista,
                  child: Image.network(
                    sUrlImg,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.mail_rounded, color: AppColores.oscuro),
                  ),
                ),
              ),
              const SizedBox(width: AppEspacios.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mensaje.titulo ?? "Sin título",
                      style: AppTextos.tituloLista,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppEspacios.xs),
                    Text(
                      mensaje.cuerpo ?? "Sin mensaje",
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
