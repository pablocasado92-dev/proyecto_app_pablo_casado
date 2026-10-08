import 'package:flutter/material.dart';

import '../data/data_holder.dart';
import '../fb_objects/mensaje.dart';
import '../ins_lib/theme/app_theme.dart';

/// ============================================================================
/// FASE 3: VISTA DE DETALLE DE MENSAJE (MessageDetailView)
/// ============================================================================
/// Muestra el contenido detallado del mensaje almacenado en `DataHolder.mensajeSeleccionado`.
class MessageDetailView extends StatelessWidget {
  const MessageDetailView({super.key});

  String formatearFecha(DateTime fecha) {
    String dosCifras(int n) => n.toString().padLeft(2, '0');
    return "${dosCifras(fecha.day)}/${dosCifras(fecha.month)}/${fecha.year}  ·  ${dosCifras(fecha.hour)}:${dosCifras(fecha.minute)}";
  }

  Widget crearCabecera(Mensaje mensaje) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppEspacios.lg, AppEspacios.md, AppEspacios.lg, AppEspacios.xl + AppEspacios.lg),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColores.principal, AppColores.oscuro],
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadios.cabecera)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              crearIcono(),
              const Spacer(),
              crearEtiquetaLeido(mensaje.leido),
            ],
          ),
          const SizedBox(height: AppEspacios.lg),
          Text(
            mensaje.titulo ?? "",
            style: AppTextos.tituloCabecera,
          ),
          const SizedBox(height: AppEspacios.sm),
          crearFecha(mensaje),
        ],
      ),
    );
  }

  Widget crearIcono() {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: AppColores.tarjeta,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: const Icon(Icons.mail_rounded, color: AppColores.oscuro, size: 28),
    );
  }

  Widget crearFecha(Mensaje mensaje) {
    if (mensaje.enviado == null) {
      return const SizedBox.shrink();
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppEspacios.xs,
      children: [
        const Icon(Icons.schedule_rounded, color: AppColores.sobrePrincipalSuave, size: 16),
        Text(
          formatearFecha(mensaje.enviado!.toDate()),
          style: AppTextos.fecha,
        ),
      ],
    );
  }

  Widget crearEtiquetaLeido(bool leido) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppEspacios.md - AppEspacios.xs, vertical: AppEspacios.xs + 2),
      decoration: BoxDecoration(
        color: AppColores.pastilla,
        borderRadius: BorderRadius.circular(AppRadios.pastilla),
        border: Border.all(color: AppColores.pastillaBorde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(leido ? Icons.done_all_rounded : Icons.mark_email_unread_outlined, color: AppColores.sobrePrincipal, size: 14),
          const SizedBox(width: AppEspacios.xs + 2),
          Text(leido ? "Leído" : "No leído", style: AppTextos.etiqueta),
        ],
      ),
    );
  }

  Widget crearCuerpo(Mensaje mensaje) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppEspacios.md + AppEspacios.xs),
      padding: const EdgeInsets.all(AppEspacios.lg),
      decoration: BoxDecoration(
        color: AppColores.tarjeta,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppEspacios.sm - 2),
                decoration: BoxDecoration(
                  color: AppColores.suave,
                  borderRadius: BorderRadius.circular(AppEspacios.sm),
                ),
                child: const Icon(Icons.notes_rounded, color: AppColores.oscuro, size: 18),
              ),
              const SizedBox(width: AppEspacios.sm + 2),
              const Text("MENSAJE", style: AppTextos.seccion),
            ],
          ),
          const Divider(height: AppEspacios.xl, color: AppColores.divisor),
          SelectableText(
            mensaje.cuerpo ?? "",
            style: AppTextos.cuerpo,
          ),
        ],
      ),
    );
  }

  Widget animarEntrada(Widget hijo) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, valor, child) {
        return Opacity(
          opacity: valor,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - valor)),
            child: hijo,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Mensaje mensaje = DataHolder.instance.mensajeSeleccionado!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle del mensaje"),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppEspacios.xl),
          child: Column(
            children: [
              crearCabecera(mensaje),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppEspacios.anchoMaximo),
                  child: Transform.translate(
                    offset: const Offset(0, -AppEspacios.lg),
                    child: animarEntrada(crearCuerpo(mensaje)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
