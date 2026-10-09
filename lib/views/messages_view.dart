import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    DataHolder.instance.iBotBarIndex = 1;
    DataHolder.instance.sMessagesBadgeText = "";
    _inicializarMensajes();
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
    }
  }

  void mensajeRecibido(int iMensajesTotales) {
    if (!mounted) return;
    setState(() {
      iNumeroMensajes = iMensajesTotales;
    });
  }

  /// Despliega un diálogo para ingresar el email del destinatario y el cuerpo del mensaje
  void onPressedFloatingButton() {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController cuerpoController = TextEditingController();
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nuevo Mensaje'),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email del destinatario',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa el correo del destinatario';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Ingresa un correo válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: cuerpoController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Contenido del mensaje',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Escribe el contenido del mensaje';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (dialogFormKey.currentState!.validate()) {
                            setDialogState(() {
                              isSending = true;
                            });

                            final String rawEmail = emailController.text.trim();
                            final String destinatarioEmail = rawEmail.toLowerCase();
                            final String cuerpoTexto = cuerpoController.text.trim();

                            final String myUid = DataHolder.instance.perfilUsuario.uid.isNotEmpty
                                ? DataHolder.instance.perfilUsuario.uid
                                : (FirebaseAuth.instance.currentUser?.uid ?? "");

                            String destUid = destinatarioEmail;
                            bool perfilEncontrado = false;

                            try {
                              // Buscar el destinatario en Firestore por su correo electrónico
                              var query = await FirebaseFirestore.instance
                                  .collection("Perfiles")
                                  .where("email", isEqualTo: destinatarioEmail)
                                  .get();

                              if (query.docs.isEmpty) {
                                query = await FirebaseFirestore.instance
                                    .collection("Perfiles")
                                    .where("email", isEqualTo: rawEmail)
                                    .get();
                              }

                              if (query.docs.isNotEmpty) {
                                destUid = query.docs.first.id; // UID del destinatario encontrado
                                perfilEncontrado = true;
                              }

                              Mensaje mensajeNuevo = Mensaje.initCampos(
                                "",
                                cuerpoTexto,
                                destUid, // destinatarioUID (UID o Email)
                                myUid,   // remitenteUID
                                Timestamp.now(),
                              );

                              DataHolder.instance.perfilUsuario.agregarNuevoMensaje(mensajeNuevo);

                              if (!context.mounted) return;
                              Navigator.pop(context);

                              final String textoConfirmacion = perfilEncontrado
                                  ? 'Mensaje enviado a $rawEmail'
                                  : 'Mensaje enviado a $rawEmail (guardado por correo)';

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(textoConfirmacion)),
                              );
                            } catch (e) {
                              setDialogState(() {
                                isSending = false;
                              });
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al enviar mensaje: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );
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
                  const Expanded(
                    child: Text(
                      "Detalle del Mensaje",
                      style: AppTextos.tituloLista,
                    ),
                  ),
                ],
              ),
              const Divider(height: AppEspacios.lg),
              
              // Mapeo dinámico del UID del remitente a su email en Firestore
              FutureBuilder<String>(
                future: DataHolder.instance.getEmailByUid(mensaje.remitenteUID),
                builder: (context, snapshot) {
                  final String deTexto = snapshot.data ?? (mensaje.remitenteUID ?? 'Anónimo');
                  return Text("De: $deTexto", style: AppTextos.secundario);
                },
              ),
              const SizedBox(height: AppEspacios.xs),

              // Mapeo dinámico del UID del destinatario a su email en Firestore
              FutureBuilder<String>(
                future: DataHolder.instance.getEmailByUid(mensaje.destinatarioUID),
                builder: (context, snapshot) {
                  final String paraTexto = snapshot.data ?? (mensaje.destinatarioUID ?? '');
                  if (paraTexto.isEmpty) return const SizedBox.shrink();
                  return Text("Para: $paraTexto", style: AppTextos.secundario);
                },
              ),
              const SizedBox(height: AppEspacios.md),

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
                      mensaje.cuerpo ?? "Sin contenido",
                      style: AppTextos.tituloLista,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppEspacios.xs),

                    // Mapeo dinámico del UID del remitente a su email desde Firestore
                    FutureBuilder<String>(
                      future: DataHolder.instance.getEmailByUid(mensaje.remitenteUID),
                      builder: (context, snapshot) {
                        final String emailRemitente = snapshot.data ?? (mensaje.remitenteUID ?? 'Anónimo');
                        return Text(
                          "De: $emailRemitente",
                          style: AppTextos.secundario,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
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
    // Si la lista está vacía, se muestra un estado visual indicándolo claramente
    if (iNumeroMensajes == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppEspacios.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mark_email_read_outlined,
                size: 80,
                color: AppColores.textoSecundario.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppEspacios.md),
              const Text(
                'No tienes ningún mensaje',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColores.textoSecundario,
                ),
              ),
              const SizedBox(height: AppEspacios.sm),
              const Text(
                'Pulsa el botón + para enviar un mensaje a otro usuario.',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onPressedFloatingButton,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Mensaje'),
        tooltip: 'Nuevo Mensaje',
      ),
    );
  }
}
