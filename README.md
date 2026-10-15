# proyecto_app_pablo_casado (`proy1`)

Aplicación móvil y web desarrollada en **Flutter** integrada con **Firebase (Authentication, Cloud Firestore y Storage)** para la asignatura **Programación Multimedia y Dispositivos Móviles (PMDM)**.

---

# 🚀 PARTE 1: Guía de Puesta en Marcha en un Equipo Limpio

Sigue estos pasos para clonar, configurar y ejecutar la aplicación desde cero en cualquier ordenador sin instalaciones previas del proyecto.

### 1. Prerrequisitos del Sistema
Asegúrate de contar con las siguientes herramientas instaladas en tu equipo:
- **Flutter SDK** (Versión 3.13.4 o superior).
- **Dart SDK** (Incluido con Flutter).
- **Android Studio** o **Visual Studio Code** con las extensiones oficiales de Flutter y Dart.
- Un **Emulador Android (AVD)** configurado o un dispositivo físico Android con la *Depuración por USB* activada.

### 2. Comprobar el Estado del Entorno
Abre una terminal y ejecuta el siguiente comando para verificar que Flutter esté configurado correctamente:
```bash
flutter doctor
```

### 3. Descargar el Proyecto e Instalar Dependencias
1. Clona o descarga el repositorio en tu equipo:
   ```bash
   git clone <URL_DEL_REPOSITORIO>
   cd proy1
   ```
2. Descarga todas las dependencias necesarias definidas en el `pubspec.yaml`:
   ```bash
   flutter pub get
   ```

### 4. Configuración de Firebase y Archivos Sensibles
El proyecto requiere conectar con Firebase Authentication y Cloud Firestore. 

> ⚠️ **IMPORTANTE DE SEGURIDAD**: Los archivos de configuración nativos **`android/app/google-services.json`** y **`ios/Runner/GoogleService-Info.plist`** contienen claves de proyecto privadas e identificadores de servicio sensibles. Por ello, están incluidos en el archivo **`.gitignore`** y **NO se deben subir al repositorio remoto Git**.

Para ejecutar en un proyecto propio de Firebase:
- Crea un proyecto en la consola de Firebase.
- Descarga tu propio `google-services.json` en `android/app/` (o configura `firebase_options.dart` mediante FlutterFire CLI).

### 5. Ejecución de la Aplicación
Con el emulador Android o dispositivo físico conectado, ejecuta:
```bash
flutter run
```

### 6. Verificación de Código y Pruebas
Puedes comprobar que el proyecto no tiene ningún error de análisis ni fallos de pruebas ejecutando:
```bash
flutter analyze
flutter test
```

---

# 🎓 PARTE 2: Guía Didáctica y Explicación de la Arquitectura (PMDM)

Esta sección explica detalladamente el funcionamiento interno del programa, los patrones de diseño aplicados y la integración con servicios en la nube.

---

## 🏛️ 1. Estructura y Organización del Código (`lib/`)

El proyecto sigue una estructura limpia por capas en la carpeta `lib/`:

```text
lib/
├── admins/            # Administradores auxiliares de servicios
│   ├── device_admin.dart     # Consultas de pantalla y plataforma del dispositivo
│   ├── firebase_admin.dart   # Conexión directa con Firestore y Firebase Auth
│   └── storage_admin.dart    # Gestión de subida y compresión de imágenes
├── data/              # Estado global en memoria (Patrón Singleton)
│   └── data_holder.dart      # Almacén central de sesión, caché y lógica de chats
├── fb_objects/        # Clases Modelo para Cloud Firestore
│   ├── conversacion.dart     # Modelo de hilo de chat por contacto
│   ├── mensaje.dart          # Modelo DTO de mensaje de texto
│   └── perfil.dart           # Modelo de perfil de usuario y escucha reactiva
├── ins_lib/           # Componentes reusables de diseño y navegación
│   ├── bot_bars/ins_bot_bar_style1.dart # Barra de navegación inferior de 3 pestañas
│   └── theme/app_theme.dart  # Tokens de diseño (colores, espacios, tipografía)
├── views/             # Pantallas/Vistas de la aplicación
│   ├── chat_screen.dart           # Pantalla de chat 1 a 1 en tiempo real
│   ├── conversaciones_view.dart   # Bandeja de entrada con lista de chats
│   ├── edit_profile_view.dart     # Pantalla de Perfil en Cuadrícula (GridView)
│   ├── home_view.dart             # Panel principal del usuario autenticado
│   ├── login_screen.dart          # Inicio de sesión con Firebase Auth
│   ├── onboarding_screen.dart     # Tarjetas introductorias deslizables (SharedPreferences)
│   ├── register_screen.dart       # Registro con desplegable de edad (1-100 años)
│   └── splash_screen.dart         # Carga inicial y decisión inteligente de sesión
└── main.dart          # Punto de entrada y tabla de rutas nombradas
```

---

## 🧠 2. Gestión del Estado Global (`DataHolder` - Patrón Singleton)

En Flutter, los widgets se crean y destruyen dinámicamente. Para evitar perder la información del usuario al cambiar de vista, utilizamos el **Patrón Singleton** en la clase `DataHolder` (`lib/data/data_holder.dart`).

### ¿Cómo funciona?
Garantiza que exista **una única instancia** de `DataHolder` accesible desde cualquier pantalla del programa mediante `DataHolder.instance`:

- **`perfilUsuario`**: Almacena el perfil activo con su lista viva de mensajes (`List<Mensaje>`).
- **`contactoChatSeleccionado`**: Guarda el contacto activo con el que el usuario está chateando al abrir `ChatScreen`.
- **Cachés de Rendimiento (`_userNameCache` y `_userEmailCache`)**: Guardan en memoria los nombres y correos consultados previamente en Firestore para no saturar la base de datos con peticiones repetidas.

---

## 🗄️ 3. Base de Datos NoSQL en Cloud Firestore

La aplicación almacena la información en **Cloud Firestore** organizada en dos colecciones principales:

1. **Colección `Perfiles`**: Cada documento tiene como ID el `UID` de Firebase Auth (`Perfiles/{uid}`) y guarda `{ name, email, edad, urlAvatar, fechaRegistro }`.
2. **Colección `Mensajes`**: Colección plana de documentos (`Mensajes/{id_autogenerado}`) que guardan `{ cuerpo, destinatarioUID, remitenteUID, fecha, leido }`.

### Mapeo de Objetos (`fromFirestore` y `toFirestore`)
Cada clase modelo en `lib/fb_objects/` convierte los mapas de Firestore (`Map<String, dynamic>`) a objetos fuertemente tipados de Dart y viceversa.

---

## ⚡ 4. Chat en Tiempo Real y Programación Reactiva (*Streams y Listeners*)

### ¿Cómo recibe la app los mensajes sin recargar manualmente?
En `Perfil.descargarMensajes()`, la app abre un canal **`StreamSubscription`** continuo conectado a Cloud Firestore:

```dart
_messagesSubscription = db.collection("Mensajes").limit(100).snapshots().listen((event) {
  // 1. Filtra los mensajes dirigidos o enviados por el usuario
  // 2. Ordena la lista por fecha cronológica
  // 3. Notifica a los oyentes mediante la lista unificada de listeners
  _notifyMessageListeners(mensajes.length);
});
```

### Patrón Observador Unificado (`addListener` y `removeListener`)
Para gestionar las actualizaciones de interfaz de manera limpia y sin ejecuciones duplicadas:
- La clase `Perfil` mantiene una única lista viva de suscriptores (`_messageListeners`).
- Cada pantalla registrada (`HomeView`, `ConversacionesView`, `ChatScreen`) añade su función/lambda callback en `initState()` usando `perfil.addListener(callback)` y la elimina en `dispose()` mediante `perfil.removeListener(callback)` para evitar fugas de memoria.
- Cada evento de llegada de mensajes notifica **exactamente una sola vez** a las pantallas suscritas activas.

### Algoritmo de Agrupación por Conversaciones (`getConversaciones()`)
El método `DataHolder.instance.getConversaciones()` toma la lista plana de mensajes y:
1. Los clasifica en hilos individuales por contacto (`Conversacion`).
2. Cuenta cuántos mensajes recibidos están pendientes de leer (`leido == false`).
3. Ordena los chats de forma descendente por la fecha de su último mensaje, colocando en la parte superior el chat más reciente.

---

## 🔴 5. Barra Inferior de 3 Secciones y Sistema de Puntos Rojos (`Badge`)

La barra inferior reutilizable (`InsBotBarStyle1`) ofrece **3 pestañas principales de navegación**:

1. **Pestaña 0 - Principal (`/home`)**: Panel principal del usuario autenticado.
2. **Pestaña 1 - Perfil (`/edit_profile`)**: Pantalla organizada en **Cuadrícula (`GridView.count`)** de celdas compactas para modificar Nombre, Edad (menú desplegable de 1 a 100 años) y Foto de Avatar con guardado persistente en Firestore.
3. **Pestaña 2 - Mensajes (`/conversaciones`)**: Lista de conversaciones activas.

### Indicadores de Notificación (`Badge`):
- **Avatar de Conversación**: Muestra un punto rojo (`Badge` color `Colors.red`) sobre la foto de perfil del contacto mientras existan mensajes no leídos en esa conversación.
- **Barra Inferior**: `DataHolder.instance.tieneMensajesSinLeer()` consulta en tiempo real si hay mensajes pendientes en toda la app y activa un punto rojo sobre la pestaña **Mensajes** en todas las pantallas.
- **Marcado al Leer**: Al entrar a `ChatScreen`, los mensajes recibidos de ese contacto se marcan automáticamente como leídos en Firestore (`leido = true`), removiendo los puntos rojos de la app.

---

## 🧭 6. Rutas Nombradas de la Aplicación

| Ruta | Vista | Descripción |
| --- | --- | --- |
| `/` o `/splash` | `SplashScreen` | Muestra el GIF animado de carga y evalúa si hay sesión activa en Firebase Auth |
| `/onboarding` | `OnboardingScreen` | Tarjetas introductorias deslizables con persistencia local (`SharedPreferences`) |
| `/login` | `LoginScreen` | Autenticación con email y contraseña mediante Firebase Auth (errores tratados) |
| `/register` | `RegisterScreen` | Creación de cuenta, menú desplegable de edad (1-100 años) y documento de perfil en Firestore |
| `/home` | `HomeView` | Panel principal del usuario con datos de perfil y botón de cerrar sesión |
| `/edit_profile` | `EditProfileView` | Pantalla de Perfil en Cuadrícula (`GridView`) con desplegable de edad y guardado en Firestore |
| `/conversaciones` (o `/messages`) | `ConversacionesView` | Bandeja de entrada con la lista de chats ordenados por fecha e indicadores no leídos |
| `/chat` | `ChatScreen` | Hilo de conversación 1 a 1 en tiempo real con burbujas alineadas y barra fija de envío |
