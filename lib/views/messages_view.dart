import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/data_holder.dart';
import '../fb_objects/mensaje.dart';
import '../ins_lib/bot_bars/ins_bot_bar_style1.dart';
import '../ins_lib/theme/app_theme.dart';

/// ============================================================================
/// VISTA DE CHAT / MENSAJES (MessagesView)
/// ============================================================================
/// Rediseño en formato conversación / chat en tiempo real con burbujas de diálogo
/// alineadas a la derecha (enviados) e izquierda (recibidos), con barra de entrada fija.
class MessagesView extends StatefulWidget {
  const MessagesView({super.key});

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> {
  final TextEditingController _mensajeInputController = TextEditingController();
  final TextEditingController _destinatarioController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int iNumeroMensajes = 0;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    DataHolder.instance.iBotBarIndex = 1;
    DataHolder.instance.sMessagesBadgeText = "";
    _inicializarMensajes();
  }

  @override
  void dispose() {
    _mensajeInputController.dispose();
    _destinatarioController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _inicializarMensajes() {
    final perfil = DataHolder.instance.perfilUsuario;
    perfil.setOnMessageReceived(mensajeRecibido);
    perfil.descargarMensajes();
    perfil.marcarMensajesLeidos();
    if (mounted) {
      setState(() {
        iNumeroMensajes = perfil.mensajes.length;
      });
      _scrollToBottom();
    }
  }

  void mensajeRecibido(int iMensajesTotales) {
    if (!mounted) return;
    setState(() {
      iNumeroMensajes = iMensajesTotales;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Envía un mensaje en la conversación de chat
  Future<void> _enviarMensajeChat() async {
    final String texto = _mensajeInputController.text.trim();
    final String destinatarioInput = _destinatarioController.text
        .trim()
        .toLowerCase();

    if (texto.isEmpty) return;

    if (destinatarioInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, indica el correo del destinatario en la barra superior.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    final String myUid = DataHolder.instance.perfilUsuario.uid.isNotEmpty
        ? DataHolder.instance.perfilUsuario.uid
        : (FirebaseAuth.instance.currentUser?.uid ?? "");

    String destUid = destinatarioInput;

    try {
      // Buscar si existe el perfil del destinatario en Firestore por su email
      var query = await FirebaseFirestore.instance
          .collection("Perfiles")
          .where("email", isEqualTo: destinatarioInput)
          .get();

      if (query.docs.isNotEmpty) {
        destUid = query.docs.first.id;
      }

      Mensaje mensajeNuevo = Mensaje.initCampos(
        "",
        texto,
        destUid, // destinatarioUID (UID o Email)
        myUid, // remitenteUID
        Timestamp.now(),
      );

      DataHolder.instance.perfilUsuario.agregarNuevoMensaje(mensajeNuevo);
      _mensajeInputController.clear();

      if (!mounted) return;
      setState(() {
        _isSending = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enviando mensaje: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatearHora(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Construye una burbuja de chat para cada mensaje
  Widget _buildChatBubble(Mensaje mensaje, bool esMio) {
    final colorBurbuja = esMio ? AppColores.principal : AppColores.suave;
    final colorTexto = esMio ? Colors.white : AppColores.texto;
    final alineacion = esMio
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bordes = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: esMio ? const Radius.circular(16) : const Radius.circular(4),
      bottomRight: esMio ? const Radius.circular(4) : const Radius.circular(16),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: alineacion,
        children: [
          // Si el mensaje es de otra persona, mostrar el remitente
          if (!esMio)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: FutureBuilder<String>(
                future: DataHolder.instance.getEmailByUid(mensaje.remitenteUID),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? (mensaje.remitenteUID ?? 'Anónimo'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),

          // Globo de texto del mensaje
          Material(
            elevation: 1,
            color: colorBurbuja,
            borderRadius: bordes,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SelectableText(
                    mensaje.cuerpo ?? '',
                    style: TextStyle(
                      color: colorTexto,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatearHora(mensaje.fecha),
                    style: TextStyle(
                      fontSize: 10,
                      color: esMio ? Colors.white70 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye la lista de burbujas de chat
  Widget _buildListaChat() {
    final perfil = DataHolder.instance.perfilUsuario;
    final myUid = perfil.uid.toLowerCase();
    final myEmail =
        (FirebaseAuth.instance.currentUser?.email ?? perfil.email ?? "")
            .toLowerCase();

    if (iNumeroMensajes == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppEspacios.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 80,
                color: AppColores.textoSecundario.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppEspacios.md),
              const Text(
                'No hay conversación iniciada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColores.textoSecundario,
                ),
              ),
              const SizedBox(height: AppEspacios.sm),
              const Text(
                'Escribe el email de un destinatario en la barra inferior y envía tu primer mensaje.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      itemCount: perfil.mensajes.length,
      itemBuilder: (context, index) {
        final mensaje = perfil.mensajes[index];
        final rem = (mensaje.remitenteUID ?? "").toLowerCase();

        // Evaluar si el mensaje fue enviado por el usuario actual
        final bool esMio =
            (myUid.isNotEmpty && rem == myUid) ||
            (myEmail.isNotEmpty && rem == myEmail);

        return _buildChatBubble(mensaje, esMio);
      },
    );
  }

  /// Barra fija de entrada de texto e interacción de chat en la parte inferior
  Widget _buildBarraEntradaChat() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Campo compacto para ingresar/confirmar el destinatario
            SizedBox(
              height: 38,
              child: TextField(
                controller: _destinatarioController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Para (correo del destinatario)...',
                  prefixIcon: const Icon(Icons.alternate_email, size: 18),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  filled: true,
                  fillColor: AppColores.suave,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Campo de escritura de mensaje + Botón circular de envío
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mensajeInputController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: AppColores.fondo,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Botón circular de enviar
                IconButton.filled(
                  onPressed: _isSending ? null : _enviarMensajeChat,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColores.principal,
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat de Mensajes"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(child: _buildListaChat()),
          _buildBarraEntradaChat(),
        ],
      ),
      bottomNavigationBar: InsBotBarStyle1(
        blBadge1: DataHolder.instance.blNotificacionesBadge,
        sBadge2: DataHolder.instance.sMessagesBadgeText,
        iBarIndex: DataHolder.instance.iBotBarIndex,
      ),
    );
  }
}
