import 'package:flutter/material.dart';

import '../data/data_holder.dart';
import '../ins_lib/bot_bars/ins_bot_bar_style1.dart';
import '../ins_lib/theme/app_theme.dart';

/// ============================================================================
/// VISTA DE LISTA DE CONVERSACIONES (ConversacionesView)
/// ============================================================================
/// Muestra las conversaciones activas agrupadas por contacto y ordenadas por mensaje más reciente.
class ConversacionesView extends StatefulWidget {
  const ConversacionesView({super.key});

  @override
  State<ConversacionesView> createState() => _ConversacionesViewState();
}

class _ConversacionesViewState extends State<ConversacionesView> {
  int iNumeroConversaciones = 0;

  @override
  void initState() {
    super.initState();
    DataHolder.instance.iBotBarIndex = 2;
    DataHolder.instance.sMessagesBadgeText = "";
    _inicializarConversaciones();
  }

  /// BLOQUE 4: Al destruirse la pantalla se cancela la suscripción/listener de mensajes
  /// para evitar fugas de memoria y llamadas a setState() sobre un widget desmontado.
  @override
  void dispose() {
    final perfil = DataHolder.instance.perfilUsuario;
    perfil.removeListener(mensajeRecibido);
    super.dispose();
  }

  void _inicializarConversaciones() {
    final perfil = DataHolder.instance.perfilUsuario;
    perfil.addListener(mensajeRecibido);
    perfil.descargarMensajes();
    if (mounted) {
      setState(() {
        iNumeroConversaciones = DataHolder.instance.getConversaciones().length;
      });
    }
  }

  void mensajeRecibido(int iMensajesTotales) {
    if (!mounted) return;
    setState(() {
      iNumeroConversaciones = DataHolder.instance.getConversaciones().length;
    });
  }

  /// Despliega un diálogo para ingresar el email de un contacto e iniciar un nuevo chat
  void onPressedFloatingButton() {
    final TextEditingController emailController = TextEditingController();
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva Conversación'),
          content: Form(
            key: dialogFormKey,
            child: TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email del contacto',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa el correo del contacto';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Ingresa un correo válido';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (dialogFormKey.currentState!.validate()) {
                  final String emailContacto = emailController.text
                      .trim()
                      .toLowerCase();
                  DataHolder.instance.contactoChatSeleccionado = emailContacto;
                  Navigator.pop(context);
                  // Navegación por ruta nombrada pasando el contacto como parámetro (arguments)
                  Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: emailContacto,
                  ).then((_) {
                    if (mounted) {
                      setState(() {
                        iNumeroConversaciones = DataHolder.instance
                            .getConversaciones()
                            .length;
                      });
                    }
                  });
                }
              },
              child: const Text('Iniciar Chat'),
            ),
          ],
        );
      },
    );
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return '';
    final ahora = DateTime.now();
    if (fecha.day == ahora.day &&
        fecha.month == ahora.month &&
        fecha.year == ahora.year) {
      final h = fecha.hour.toString().padLeft(2, '0');
      final m = fecha.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else {
      final d = fecha.day.toString().padLeft(2, '0');
      final m = fecha.month.toString().padLeft(2, '0');
      return '$d/$m';
    }
  }

  Widget _buildItemConversacion(Conversacion conversacion) {
    final ultimoMsg = conversacion.ultimoMensaje;
    final fecha = ultimoMsg.fecha?.toDate();

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppEspacios.md,
        vertical: AppEspacios.xs,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppEspacios.md,
          vertical: 4,
        ),
        leading: Badge(
          isLabelVisible: conversacion.mensajesNoLeidos > 0,
          backgroundColor: Colors.red,
          smallSize: 12,
          child: const CircleAvatar(
            backgroundColor: AppColores.suave,
            child: Icon(Icons.person, color: AppColores.oscuro),
          ),
        ),
        title: FutureBuilder<String>(
          future: DataHolder.instance.getNombreByUid(
            conversacion.contactoUidOrEmail,
          ),
          builder: (context, snapshot) {
            final String nombreContacto =
                snapshot.data ?? conversacion.contactoUidOrEmail;
            return Text(
              nombreContacto,
              style: AppTextos.tituloLista,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        subtitle: Text(
          ultimoMsg.cuerpo ?? 'Sin contenido',
          style: AppTextos.secundario,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatearFecha(fecha),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (conversacion.mensajesNoLeidos > 0) ...[
              const SizedBox(height: 4),
              Badge(
                label: Text(conversacion.mensajesNoLeidos.toString()),
                backgroundColor: AppColores.principal,
              ),
            ],
          ],
        ),
        onTap: () {
          DataHolder.instance.contactoChatSeleccionado =
              conversacion.contactoUidOrEmail;
          // Navegación mediante ruta nombrada declarada en MaterialApp con paso de parámetros (arguments)
          Navigator.pushNamed(
            context,
            '/chat',
            arguments: conversacion.contactoUidOrEmail,
          ).then((_) {
            if (mounted) {
              setState(() {
                iNumeroConversaciones = DataHolder.instance
                    .getConversaciones()
                    .length;
              });
            }
          });
        },
      ),
    );
  }

  /// Construye la vista en LISTA alimentada desde Firestore gestionando sus 3 estados:
  /// Carga, Error y Vacío (además de la lista con datos).
  Widget _buildListaConversaciones() {
    final perfil = DataHolder.instance.perfilUsuario;
    final lista = DataHolder.instance.getConversaciones();

    // 1. ESTADO DE CARGA (mientras conecta con Firestore y aún no hay datos en caché)
    if (perfil.cargandoMensajes && lista.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColores.oscuro),
            SizedBox(height: 12),
            Text(
              'Cargando conversaciones desde Firestore...',
              style: TextStyle(color: AppColores.textoSecundario),
            ),
          ],
        ),
      );
    }

    // 2. ESTADO DE ERROR (si falla la lectura en Firestore)
    if (perfil.errorMensajes != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppEspacios.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppColores.error,
              ),
              const SizedBox(height: AppEspacios.md),
              Text(
                perfil.errorMensajes!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColores.texto),
              ),
              const SizedBox(height: AppEspacios.md),
              ElevatedButton.icon(
                onPressed: _inicializarConversaciones,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    // 3. ESTADO VACÍO (cuando no existen conversaciones en Firestore)
    if (lista.isEmpty) {
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
                'No tienes conversaciones activas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColores.textoSecundario,
                ),
              ),
              const SizedBox(height: AppEspacios.sm),
              const Text(
                'Pulsa el botón + para iniciar un nuevo chat con cualquier usuario.',
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

    // 4. ESTADO CON DATOS (ListView.builder)
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppEspacios.md),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        return _buildItemConversacion(lista[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Conversaciones")),
      body: SafeArea(child: _buildListaConversaciones()),
      bottomNavigationBar: InsBotBarStyle1(
        blBadge1: DataHolder.instance.blNotificacionesBadge,
        sBadge2: DataHolder.instance.sMessagesBadgeText,
        iBarIndex: DataHolder.instance.iBotBarIndex,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onPressedFloatingButton,
        tooltip: 'Nueva Conversación',
        child: const Icon(Icons.add_comment_rounded),
      ),
    );
  }
}
