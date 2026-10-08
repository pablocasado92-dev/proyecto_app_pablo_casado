import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/data_holder.dart';
import '../fb_objects/perfil.dart';
import '../ins_lib/theme/app_theme.dart';

/// ============================================================================
/// FASE 3: VISTA DE EDICIÓN DE PERFIL (EditProfileView)
/// ============================================================================
/// Muestra los datos del usuario logueado en un formulario para modificarlos,
/// incluyendo la posibilidad de actualizar el avatar usando la cámara o galería.
class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController nombreController = TextEditingController();
  final TextEditingController edadController = TextEditingController();
  final TextEditingController alturaController = TextEditingController();

  final FirebaseFirestore db = FirebaseFirestore.instance;
  bool bGuardando = false;
  XFile? ficheroCargado;

  @override
  void initState() {
    super.initState();
    Perfil perfil = DataHolder.instance.perfilUsuario;
    nombreController.text = perfil.name ?? "";
    edadController.text = perfil.edad?.toString() ?? "";
    alturaController.text = perfil.altura?.toString() ?? "";
  }

  @override
  void dispose() {
    nombreController.dispose();
    edadController.dispose();
    alturaController.dispose();
    super.dispose();
  }

  String? validarNombre(String? valor) {
    if (valor == null || valor.trim().isEmpty) return "Escribe tu nombre";
    return null;
  }

  String? validarEdad(String? valor) {
    int? edad = int.tryParse(valor?.trim() ?? "");
    if (edad == null) return "La edad debe ser un número entero";
    if (edad < 0 || edad > 150) return "Edad no válida";
    return null;
  }

  String? validarAltura(String? valor) {
    double? altura = double.tryParse((valor ?? "").trim().replaceAll(",", "."));
    if (altura == null) return "La altura debe ser un número";
    if (altura <= 0) return "Altura no válida";
    return null;
  }

  Future<void> clickGuardar() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      bGuardando = true;
    });

    Perfil perfil = DataHolder.instance.perfilUsuario;

    if (ficheroCargado != null) {
      String uidUser = perfil.uid.isNotEmpty ? perfil.uid : FirebaseAuth.instance.currentUser!.uid;
      perfil.urlAvatar = await DataHolder.instance.storageAdmin.subirAvatar(ficheroCargado!, uidUser);
    }

    perfil.name = nombreController.text.trim();
    perfil.edad = int.parse(edadController.text.trim());
    perfil.altura = double.parse(alturaController.text.trim().replaceAll(",", "."));

    String uid = perfil.uid.isNotEmpty ? perfil.uid : FirebaseAuth.instance.currentUser!.uid;

    try {
      await db.collection("Perfiles").doc(uid).set(perfil.toFirestore(), SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Perfil actualizado")),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        bGuardando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo guardar: $error"), backgroundColor: AppColores.error),
      );
    }
  }

  Widget crearCabecera() {
    String email = FirebaseAuth.instance.currentUser?.email ?? "";
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppEspacios.lg, AppEspacios.lg, AppEspacios.lg, AppEspacios.xl + AppEspacios.lg),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColores.principal, AppColores.oscuro],
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadios.cabecera)),
      ),
      child: Column(
        children: [
          crearAvatar(),
          const SizedBox(height: AppEspacios.sm),
          const Text("Editar perfil", style: AppTextos.tituloCabecera),
          if (email.isNotEmpty) ...[
            const SizedBox(height: AppEspacios.xs),
            Text(email, style: const TextStyle(color: AppColores.sobrePrincipalSuave)),
          ],
        ],
      ),
    );
  }

  Widget crearAvatar() {
    Image? avatar = DataHolder.instance.perfilUsuario.avatar;
    double tamano = AppEspacios.iconoGrande + AppEspacios.xl;
    if (avatar == null) {
      return Icon(Icons.account_circle_rounded, size: tamano, color: AppColores.sobrePrincipal);
    }
    return ClipOval(
      child: SizedBox(width: tamano, height: tamano, child: avatar),
    );
  }

  void elegirAvatarCamara() async {
    ImagePicker imagePicker = ImagePicker();
    ficheroCargado = await imagePicker.pickImage(source: ImageSource.camera);
    if (ficheroCargado == null) return;

    final bytes = await ficheroCargado?.readAsBytes();
    if (!mounted) return;
    setState(() {
      DataHolder.instance.perfilUsuario.avatar = Image.memory(bytes!, fit: BoxFit.cover);
    });
  }

  void elegirAvatarGaleria() async {
    ImagePicker imagePicker = ImagePicker();
    ficheroCargado = await imagePicker.pickImage(source: ImageSource.gallery);
    if (ficheroCargado == null) return;

    final bytes = await ficheroCargado?.readAsBytes();
    if (!mounted) return;
    setState(() {
      DataHolder.instance.perfilUsuario.avatar = Image.memory(bytes!, fit: BoxFit.cover);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PERFIL"),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppEspacios.xl),
          child: Column(
            children: [
              crearCabecera(),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppEspacios.anchoFormulario + AppEspacios.xl),
                  child: Transform.translate(
                    offset: const Offset(0, -AppEspacios.xl),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppEspacios.md),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppEspacios.lg),
                          child: Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: nombreController,
                                  validator: validarNombre,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: "Nombre",
                                    prefixIcon: Icon(Icons.person_outline_rounded),
                                  ),
                                ),
                                const SizedBox(height: AppEspacios.md),
                                TextFormField(
                                  controller: edadController,
                                  validator: validarEdad,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Edad",
                                    prefixIcon: Icon(Icons.cake_outlined),
                                  ),
                                ),
                                const SizedBox(height: AppEspacios.md),
                                TextFormField(
                                  controller: alturaController,
                                  validator: validarAltura,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: "Altura (m)",
                                    prefixIcon: Icon(Icons.height_rounded),
                                  ),
                                ),
                                const SizedBox(height: AppEspacios.md),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: elegirAvatarCamara,
                                        child: const Text("Avatar Cámara"),
                                      ),
                                    ),
                                    const SizedBox(width: AppEspacios.md),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: elegirAvatarGaleria,
                                        child: const Text("Avatar Galería"),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppEspacios.lg),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: bGuardando ? null : () => Navigator.pop(context),
                                        child: const Text("Cancelar"),
                                      ),
                                    ),
                                    const SizedBox(width: AppEspacios.md),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: bGuardando ? null : clickGuardar,
                                        child: bGuardando
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColores.sobrePrincipal,
                                                ),
                                              )
                                            : const Text("Guardar"),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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
