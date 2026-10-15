import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/data_holder.dart';
import '../ins_lib/theme/app_theme.dart';

/// ============================================================================
/// PANTALLA DE CHAT INDIVIDUAL (ChatScreen)
/// ============================================================================
/// Muestra el hilo de conversación 1 a 1 en tiempo real con el contacto seleccionado.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _mensajeInputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _inicializarChat();
  }

  @override
  void dispose() {
    final perfil = DataHolder.instance.perfilUsuario;
    perfil.removeListener(_onMessageChat);
    _mensajeInputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _inicializarChat() {
    final perfil = DataHolder.instance.perfilUsuario;
    perfil.addListener(_onMessageChat);
    _marcarMensajesDelContactoComoLeidos();
    _scrollToBottom();
  }

  void _onMessageChat(int _) {
    if (mounted) {
      _marcarMensajesDelContactoComoLeidos();
      setState(() {});
      _scrollToBottom();
    }
  }

  void _marcarMensajesDelContactoComoLeidos() {
    final String? contacto = DataHolder.instance.contactoChatSeleccionado;
    if (contacto == null || contacto.isEmpty) return;
    final contactClean = contacto.toLowerCase();
    final perfil = DataHolder.instance.perfilUsuario;

    for (Mensaje m in perfil.mensajes) {
      final String rem = (m.remitenteUID ?? "").toLowerCase();
      if (!m.leido &&
          (rem == contactClean ||
              contactClean.contains(rem) ||
              rem.contains(contactClean))) {
        m.leido = true;
        m.update();
      }
    }
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

  Future<void> _enviarMensaje() async {
    final String texto = _mensajeInputController.text.trim();
    final String? contacto = DataHolder.instance.contactoChatSeleccionado;

    if (texto.isEmpty || contacto == null || contacto.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    final String myUid = DataHolder.instance.perfilUsuario.uid.isNotEmpty
        ? DataHolder.instance.perfilUsuario.uid
        : (FirebaseAuth.instance.currentUser?.uid ?? "");

    try {
      Mensaje mensajeNuevo = Mensaje.initCampos(
        "",
        texto,
        contacto, // destinatarioUID (UID o Email del contacto)
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
          content: Text('Error al enviar mensaje: $e'),
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
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: alineacion,
        children: [
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

  List<Mensaje> _getMensajesConversacion(String contacto) {
    final perfil = DataHolder.instance.perfilUsuario;
    final myUid = perfil.uid.toLowerCase();
    final myEmail =
        (FirebaseAuth.instance.currentUser?.email ?? perfil.email ?? "")
            .toLowerCase();
    final contactClean = contacto.toLowerCase();

    final List<Mensaje> filtrados = [];

    for (Mensaje m in perfil.mensajes) {
      final dest = (m.destinatarioUID ?? "").toLowerCase();
      final rem = (m.remitenteUID ?? "").toLowerCase();

      final bool esEnviadoAlContacto =
          ((rem == myUid || rem == myEmail) && (dest == contactClean));
      final bool esRecibidoDelContacto =
          ((rem == contactClean) && (dest == myUid || dest == myEmail));

      if (esEnviadoAlContacto || esRecibidoDelContacto) {
        filtrados.add(m);
      }
    }

    filtrados.sort((a, b) {
      final aF = a.fecha?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bF = b.fecha?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aF.compareTo(bF);
    });

    return filtrados;
  }

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
        child: Row(
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
            IconButton.filled(
              onPressed: _isSending ? null : _enviarMensaje,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? contacto = DataHolder.instance.contactoChatSeleccionado;
    final perfil = DataHolder.instance.perfilUsuario;
    final myUid = perfil.uid.toLowerCase();
    final myEmail =
        (FirebaseAuth.instance.currentUser?.email ?? perfil.email ?? "")
            .toLowerCase();

    final List<Mensaje> mensajesChat = contacto != null
        ? _getMensajesConversacion(contacto)
        : [];

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: DataHolder.instance.getNombreByUid(contacto),
          builder: (context, snapshot) {
            return Text(snapshot.data ?? (contacto ?? "Chat"));
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: mensajesChat.isEmpty
                ? Center(
                    child: Text(
                      'Inicia la conversación enviando un mensaje',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 12, bottom: 16),
                    itemCount: mensajesChat.length,
                    itemBuilder: (context, index) {
                      final m = mensajesChat[index];
                      final rem = (m.remitenteUID ?? "").toLowerCase();
                      final bool esMio =
                          (myUid.isNotEmpty && rem == myUid) ||
                          (myEmail.isNotEmpty && rem == myEmail);
                      return _buildChatBubble(m, esMio);
                    },
                  ),
          ),
          _buildBarraEntradaChat(),
        ],
      ),
    );
  }
}
