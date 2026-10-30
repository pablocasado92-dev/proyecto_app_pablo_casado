# proyecto_app_pablo_casado — Entrega PMDM

Aplicación multiplataforma (**Android y Web**) desarrollada en **Flutter** e integrada con **Google Firebase (Authentication, Cloud Firestore y Storage)** para el módulo de **Programación Multimedia y Dispositivos Móviles (PMDM - 2º DAM)**.

---

## 🚀 1. Guía de Arranque en un Equipo Limpio

Sigue estos pasos en orden para clonar, configurar y poner en marcha el proyecto desde cero en cualquier ordenador sin configuraciones previas.

### 1.1. Prerrequisitos del Sistema
1. **Flutter SDK** (versión `^3.13.4` o superior, con Dart incluido).
2. **Git** instalado en el sistema.
3. **Android Studio** (con Android SDK y un emulador AVD creado) y/o **Google Chrome** (para ejecución en navegador web).
4. **Node.js** (opcional pero recomendado para instalar Firebase CLI y FlutterFire CLI).

### 1.2. Comprobar el Entorno
Abre una terminal y verifica que Flutter reconoce el SDK, el emulador Android y el navegador:
```bash
flutter doctor
```

### 1.3. Clonar el Repositorio e Instalar Dependencias
> **Nota importante:** El nombre real de la carpeta al clonar desde GitHub es `proyecto_app_pablo_casado`.
```bash
git clone https://github.com/pablocasado92-dev/proyecto_app_pablo_casado.git
cd proyecto_app_pablo_casado
flutter pub get
```

### 1.4. Configuración de Firebase en un Equipo Limpio (Paso Requerido)
Por seguridad y buenas prácticas, los ficheros con credenciales nativas (`lib/firebase_options.dart` y `android/app/google-services.json`) están excluidos en `.gitignore` y **no se suben al repositorio**.

Sin el archivo `lib/firebase_options.dart`, la aplicación **no compilará**, ya que `lib/main.dart` invoca:
```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

Para generar los ficheros necesarios en un equipo limpio, dispones de dos métodos:

#### Opción A (Recomendada y Automática): Con FlutterFire CLI
1. Instala Firebase CLI (si no lo tienes instalado) e inicia sesión:
   ```bash
   npm install -g firebase-tools
   firebase login
   ```
2. Activa la herramienta oficial FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```
3. Ejecuta la vinculación en la raíz del proyecto (`proyecto_app_pablo_casado`):
   ```bash
   flutterfire configure
   ```
   * Selecciona tu proyecto de Firebase en la lista interactiva (o crea uno nuevo).
   * Marca las plataformas objetivo (**android** y **web**).
   * **Resultado:** FlutterFire CLI generará automáticamente `lib/firebase_options.dart` con tus claves de proyecto y descargará/ubicará `android/app/google-services.json` en su carpeta correspondiente.

#### Opción B (Manual): Aportando los Ficheros Existentes
Si ya dispones de los archivos de configuración descargados de la Consola de Firebase:
1. Copia el archivo `firebase_options.dart` dentro de `lib/`:
   * Ruta destino: `lib/firebase_options.dart`
2. Copia el archivo `google-services.json` dentro de `android/app/`:
   * Ruta destino: `android/app/google-services.json`

---

### 1.5. Ejecutar la Aplicación
* **Para ejecutar en el Emulador Android:**
  1. Inicia tu emulador Android desde el *Device Manager* de Android Studio (o conecta un móvil físico por USB con depuración habilitada).
  2. Ejecuta:
     ```bash
     flutter run -d android
     ```
* **Para ejecutar en el Navegador Web (Chrome):**
  ```bash
  flutter run -d chrome
  ```

### 1.6. Comprobación de Análisis Estático y Tests
Para verificar que el código compila sin errores ni advertencias:
```bash
flutter analyze
flutter test
```

---

## 🔐 2. Conexión con Firebase y Archivos de Configuración

La aplicación se inicializa en `lib/main.dart` mediante `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` antes de arrancar `runApp()`.

### ¿Qué ficheros de configuración intervienen?
1. **`lib/firebase_options.dart`**: Archivo Dart generado automáticamente por **FlutterFire CLI** (`flutterfire configure`). Contiene las opciones multiplataforma (`DefaultFirebaseOptions`) necesarias para que tanto **Web** como **Android/iOS** identifiquen el proyecto de Firebase.
2. **`android/app/google-services.json`**: Archivo de configuración nativo exigido por el plugin de Gradle `com.google.gms.google-services` para compilar en Android.
3. **`ios/Runner/GoogleService-Info.plist`**: Archivo equivalente para compilaciones en iOS/macOS.
4. **`firebase.json` y `.firebaserc`**: Archivos de vinculación del proyecto con Firebase CLI y reglas de despliegue.

### ⚠️ ¿Qué ficheros NO se suben al repositorio (y por qué)?
En el archivo **`.gitignore`** están excluidos expresamente y desvinculados del historial (`git rm --cached`):
* `lib/firebase_options.dart`
* `android/app/google-services.json`
* `ios/Runner/GoogleService-Info.plist`
* `**/firebase_app_id_file.json`
* Claves privadas de cuentas de servicio (`*service-account*.json`, `*adminsdk*.json`) y archivos `.env`.

**Motivo:** Estos ficheros contienen identificadores nativos sensibles, claves de API y credenciales vinculadas a la infraestructura de Firebase. No subirlos a repositorios públicos evita fugas de credenciales y accesos no autorizados.

---

## 🏛️ 3. Estructura de Carpetas del Proyecto (`lib/`) y Justificación

El código fuente dentro de `lib/` está dividido siguiendo el principio de **Separación de Responsabilidades (SoC)**:

```text
lib/
├── views/             # 1. PANTALLAS (Capa de Presentación / UI)
│   ├── splash_screen.dart         # Pantalla inicial con imagen por URL y evaluación de sesión
│   ├── onboarding_screen.dart     # Carrusel de 3 pantallas deslizables (primera vez)
│   ├── login_screen.dart          # Acceso con correo y contraseña + tratamiento de errores
│   ├── register_screen.dart       # Registro en Auth + guardado de Perfil en Firestore
│   ├── home_view.dart             # Panel principal del usuario y cierre de sesión
│   ├── edit_profile_view.dart     # Sección en Cuadrícula (GridView) de la colección Perfiles + edición
│   ├── conversaciones_view.dart   # Sección en Lista (ListView) de conversaciones / mensajes
│   └── chat_screen.dart           # Chat 1 a 1 en tiempo real
├── fb_objects/        # 2. MODELOS DE DATOS (Capa de Dominio / DTOs con withConverter)
│   ├── perfil.dart                # Modelo Perfil + conversores fromFirestore / toFirestore
│   ├── mensaje.dart               # Modelo Mensaje + conversores fromFirestore / toFirestore
│   └── conversacion.dart          # Modelo agrupador de hilos de conversación
├── admins/            # 3. SERVICIOS (Capa de Acceso a Datos y Dispositivo)
│   ├── firebase_admin.dart        # Servicio de consulta de perfiles en Firestore con withConverter
│   ├── storage_admin.dart         # Servicio de compresión y subida de imágenes a Firebase Storage
│   └── device_admin.dart          # Servicio de consulta de dimensiones y plataforma (Web/Android)
├── data/              # 4. ESTADO COMPARTIDO (Singleton)
│   └── data_holder.dart           # Almacén central en memoria, cachés y limpieza al cerrar sesión
├── ins_lib/           # 5. COMPONENTES REUTILIZABLES Y SISTEMA DE DISEÑO
│   ├── bot_bars/ins_bot_bar_style1.dart # Barra de navegación inferior de 3 secciones con Badges
│   └── theme/app_theme.dart       # Tema global (AppTheme), paleta granate/borgoña y tipografía
├── firebase_options.dart          # Configuración multiplataforma de Firebase
└── main.dart                      # Punto de entrada y declaración de rutas nombradas en MaterialApp
```

### ¿Por qué está dividido así?
1. **Mantenibilidad y Orden**: Si hay que cambiar el diseño visual de una pantalla (por ejemplo, mejorar los colores o formularios en `views/` e `ins_lib/theme/`), se hace sin tocar ni romper las consultas a Firebase.
2. **Desacoplamiento y Tipado Fuerte (`fb_objects/`)**: Al aislar los modelos (`Perfil`, `Mensaje`, `Conversacion`) con sus conversores `fromFirestore` y `toFirestore`, las pantallas trabajan con objetos Dart seguros (`perfil.name`, `mensaje.cuerpo`) en lugar de mapas sueltos (`Map<String, dynamic>`) propensos a errores de escritura en las claves.
3. **Reutilización (`admins/` y `data/`)**: Varias pantallas necesitan consultar Firestore o acceder al perfil activo. Centralizarlo en servicios (`FirebaseAdmin`, `StorageAdmin`, `DeviceAdmin`) y en el Singleton `DataHolder` evita duplicar código en cada widget.

---

## ✅ 4. Cumplimiento de los Criterios de la Entrega

### 4.1. Pantalla de Splash con Imagen por URL (`lib/views/splash_screen.dart`)
* Carga un GIF animado remoto mediante `Image.network(...)`.
* **Estado de carga (`loadingBuilder`)**: Mientras los paquetes de la imagen se descargan, muestra un `CircularProgressIndicator` centrado.
* **Estado de error (`errorBuilder`)**: Si no hay conexión a internet o el enlace falla, renderiza un icono de respaldo (`Icons.movie_creation_outlined`) junto al título de la aplicación, garantizando que **la pantalla nunca se quede en blanco**.

### 4.2. Onboarding de 3 Pantallas Deslizables (`lib/views/onboarding_screen.dart`)
* Implementado con un `PageView.builder` de 3 diapositivas con indicadores dinámicos, botón **"Siguiente / Comenzar"** y botón superior **"Saltar"**.
* **Flujo basado en el campo `primerLogin` de Firestore**: El Onboarding no depende de las preferencias locales del dispositivo, sino del estado del perfil del usuario en Firestore (`Perfiles/{uid}`).
  * Al registrarse o iniciar sesión por primera vez, el campo `primerLogin` del documento de perfil se establece a `true`.
  * La app redirige al **Onboarding justo antes de entrar a Home**.
  * Al completar o saltar el Onboarding, `OnboardingScreen` actualiza `primerLogin: false` en Firestore y en memoria, y navega directamente a la pantalla principal `/home`.
  * **Revisión y configuración desde el Perfil (`EditProfileView`)**: En el panel modal de edición de perfil, el usuario cuenta con un conmutador para activar/desactivar la bienvenida y un botón para volver a ver el Onboarding en cualquier momento.

### 4.3. Registro y Acceso con Tratamiento de Errores (`login_screen.dart` y `register_screen.dart`)
Ambos formularios validan los campos localmente (`Form` + `GlobalKey<FormState>`) y capturan las excepciones `FirebaseAuthException` mostrando un mensaje específico en un `SnackBar` para cada código de error:
* **En Registro (`register_screen.dart`)**:
  * `email-already-in-use` → *"Este correo electrónico ya está registrado."*
  * `weak-password` → *"La contraseña es demasiado débil."*
  * `invalid-email` → *"El formato del correo electrónico no es válido."*
* **En Inicio de Sesión (`login_screen.dart`)**:
  * `user-not-found` → *"No existe una cuenta con este correo electrónico."*
  * `wrong-password` → *"Contraseña incorrecta."*
  * `invalid-credential` → *"Credenciales incorrectas o usuario no encontrado."*
  * `invalid-email` → *"El formato del correo electrónico no es válido."*

### 4.4. Cerrar Sesión y Cancelación de Suscripciones (`dispose`)
* **Al destruir una pantalla (`dispose()`)**:
  * En `HomeView.dispose()`, `ConversacionesView.dispose()` y `ChatScreen.dispose()` se invoca `perfil.removeListener(...)` para desuscribir la pantalla de los eventos en tiempo real, y se liberan todos los `TextEditingController` y `ScrollController`.
* **Al cerrar sesión (`HomeView._signOut`)**:
  * Se invoca `DataHolder.instance.clearData()`, el cual llama a `_perfilUsuario?.dispose()`, ejecutando `_messagesSubscription?.cancel()` sobre el `StreamSubscription` de Firestore antes de hacer `FirebaseAuth.instance.signOut()` y redirigir a `/login` limpiando la pila de rutas (`Navigator.pushNamedAndRemoveUntil`).

### 4.5. Colecciones en Firestore y Conversión Tipada (`withConverter`)
La base de datos en Cloud Firestore cuenta con dos colecciones principales pobladas con documentos de prueba:
1. **`Perfiles`** (`Perfiles/{uid}`): Contiene los documentos de los usuarios registrados (`name`, `email`, `edad`, `urlAvatar`, `fechaRegistro`, `primerLogin`).
2. **`Mensajes`** (`Mensajes/{id}`): Contiene los documentos de contenido/mensajes listados en la aplicación (`cuerpo`, `remitenteUID`, `destinatarioUID`, `fecha`, `leido`).

**Uso de `.withConverter<T>`:**
Tanto `Perfil` (`lib/fb_objects/perfil.dart`) como `Mensaje` (`lib/fb_objects/mensaje.dart`) implementan sus constructores `factory ...fromFirestore(...)` y métodos `toFirestore()`. Las lecturas y escrituras en `FirebaseAdmin`, `Perfil`, `Mensaje`, `RegisterScreen` y `EditProfileView` encadenan `.withConverter<Perfil>(...)` y `.withConverter<Mensaje>(...)` para trabajar siempre con instancias tipadas y nunca con mapas sueltos.

### 4.6. Rutas Declaradas en `MaterialApp` y Paso de Parámetros
Todas las rutas están declaradas en la tabla `routes` de `MaterialApp` (`lib/main.dart`):
* `/`, `/splash`, `/onboarding`, `/login`, `/register`, `/home`, `/edit_profile`, `/perfiles`, `/conversaciones`, `/messages`, `/chat`.
* **Paso de parámetros por ruta nombrada**: Al pulsar sobre una conversación en `ConversacionesView` o sobre el botón *Chatear* de un perfil en la cuadrícula de `EditProfileView`, se navega usando:
  ```dart
  Navigator.pushNamed(context, '/chat', arguments: contactoUidOrEmail);
  ```
  Y en `ChatScreen.build()` se recupera el parámetro con:
  ```dart
  final String? argContacto = ModalRoute.of(context)?.settings.arguments as String?;
  ```

### 4.7. Barra Inferior de 3 Secciones (Lista y Cuadrícula con Estados de Carga, Vacío y Error)
El widget reutilizable `InsBotBarStyle1` conecta las 3 secciones principales:
1. **Principal (`/home` - `HomeView`)**: Panel de bienvenida con tarjeta resumen del usuario, avatar, chip de edad y accesos directos.
2. **Perfiles en Conversación (`/edit_profile` / `/perfiles` - `EditProfileView` — Sección en CUADRÍCULA)**:
   * **Muestra elementos de la colección `Perfiles` filtrados por conversaciones activas**: Utiliza un `GridView.builder` (2 columnas) que filtra la colección `Perfiles` para mostrar únicamente a los contactos con los que el usuario tiene chats iniciados en `Mensajes`.
   * **Badge de estado de conexión**: Cada tarjeta cuenta en su esquina superior izquierda con un indicador visual de estado (**🟢 En línea / ⚪ Desconectado**), sincronizado con el campo `conectado` del perfil.
   * **Gestión de los 3 Estados en la Colección**:
     * **Estado de carga**: Muestra un `CircularProgressIndicator` centrado con texto *"Cargando perfiles con conversaciones activas..."*.
     * **Estado de error**: Muestra un icono de advertencia, el detalle del error y un botón interactivo de *Reintentar*.
     * **Estado vacío**: Muestra un aviso ilustrativo cuando el usuario aún no tiene conversaciones iniciadas (*"Sin conversaciones iniciadas"*), con un botón directo para ir a la sección de Mensajes.
   * **Edición interactiva**: Incluye un panel modal (`showModalBottomSheet`) con formulario completo (nombre, edad en dropdown, avatar con preview y conmutador de onboarding) persistido en Firestore mediante `.withConverter<Perfil>`.
3. **Mensajes (`/conversaciones` - `ConversacionesView` — Sección en LISTA)**:
   * Utiliza `ListView.builder` alimentado en tiempo real desde la colección `Mensajes` de Firestore.
   * Gestiona explícitamente el **estado de carga**, **estado de error** (con botón de reintento) y **estado vacío** (*"No tienes conversaciones activas"*).

---

## 🎨 5. Sistema de Diseño y Tema Visual Aplicado (`AppTheme`)

Se ha centralizado la apariencia de la aplicación en `lib/ins_lib/theme/app_theme.dart` mediante la clase `AppTheme.tema`:
* Se aplica una **paleta elegante en tonos granate borgoña (`AppColores.oscuro`), granate vibrante (`AppColores.principal`) y fondo crema cálido (`AppColores.fondo`)**.
* Estilo unificado para `AppBar`, tarjetas (`CardThemeData` con bordes redondeados suaves), campos de texto rellenos (`InputDecorationTheme`) y botones (`ElevatedButtonThemeData`).

---

## 🧪 6. Tabla de Pruebas: Emulador Android vs Navegador Web

Se ha probado la aplicación de extremo a extremo tanto en **Emulador Android (API 34 / Pixel)** como en **Navegador Web (Google Chrome)**:

| Caso de Prueba | Qué se probó | Qué se esperaba | Qué pasó (Resultado) | Diferencias entre Android y Navegador Web |
| :--- | :--- | :--- | :--- | :--- |
| **1. Splash Screen (Con red)** | Carga del GIF remoto desde URL en `SplashScreen`. | Mostrar indicador de carga y luego renderizar el GIF animado durante 2.5 s antes de redirigir. | ✅ Correcto en ambas plataformas. | En Web la descarga tras la primera vez es casi instantánea por la caché del navegador; en Android se aprecia mejor el `loadingBuilder`. |
| **2. Splash Screen (Error de URL / Sin red)** | Simulación de fallo de carga de la imagen remota. | Que la app no quede en blanco y ejecute `errorBuilder` mostrando el icono alternativo. | ✅ Correcto. Se muestra el icono de respaldo. | Comportamiento visual idéntico en ambas plataformas. |
| **3. Onboarding y Persistencia** | Deslizar las 3 tarjetas, pulsar *Saltar* o *Comenzar*, y reiniciar la app. | Que la primera vez muestre el Onboarding y en siguientes logins lo omita leyendo `primerLogin`. | ✅ Correcto. Se actualiza la variable y no vuelve a salir al relogear. | Comportamiento idéntico en ambas plataformas, ya que el estado del campo `primerLogin` se sincroniza directamente en Cloud Firestore. |
| **4. Registro y Errores de Auth** | Registro con correo existente, contraseña de <6 caracteres y registro válido. | Mostrar `SnackBar` con el mensaje específico de cada error; con datos válidos, crear usuario y documento en `Perfiles`. | ✅ Correcto. Errores capturados y documento creado con `.withConverter<Perfil>`. | En Android se despliega automáticamente el teclado virtual ajustando el scroll (`SingleChildScrollView`); en Web se usa el teclado físico. |
| **5. Login con Credenciales** | Inicio de sesión con contraseña errónea y con credenciales válidas. | Mensaje de credenciales incorrectas en fallo; redirección a `/home` en acierto. | ✅ Correcto en ambas plataformas. | En Web el navegador ofrece autocompletar usuario/contraseña nativamente. |
| **6. Sección en Lista (`ConversacionesView`)** | Listado de conversaciones desde Firestore en sus estados de carga, vacío y con datos. | Mostrar aviso si no hay chats, y tarjetas ordenadas por fecha con badge de no leídos. | ✅ Correcto. La lista se actualiza en tiempo real al recibir documentos en `Mensajes`. | El scroll en Android tiene efecto de rebote táctil (*overscroll*), mientras que en Web responde a rueda del ratón o trackpad. |
| **7. Sección en Cuadrícula (`EditProfileView` / `Perfiles`)** | Listado de perfiles vinculados a conversaciones activas en `GridView.builder` (2 columnas) con badge de conexión (En línea/Desconectado), estados de carga, vacío y error, más edición del propio perfil. | Mostrar las celdas en cuadrícula únicamente de los contactos con chats activos (avatar, nombre, edad o email, estado de conexión y botón para chatear); permitir al usuario editar su propio perfil y refrescar la cuadrícula. | ✅ Correcto. Carga reactiva de los elementos filtrados de la colección, manejo de estados y guardado persistente con `.withConverter<Perfil>`. | En Web las tarjetas se expanden horizontalmente adaptándose al ancho del navegador; en Android la cuadrícula vertical de 2 columnas aprovecha la pantalla móvil. |
| **8. Navegación por Rutas y Parámetros** | Pulsar una conversación o el botón *Chatear* de un perfil para abrir `/chat`. | Navegar mediante `Navigator.pushNamed` pasando el contacto en `arguments` y cargar su hilo de mensajes. | ✅ Correcto. `ChatScreen` recibe el parámetro y marca los mensajes como leídos. | En Web la URL de la barra de direcciones del navegador cambia reflejando la ruta nombrada (`/#/chat`). |
| **9. Cierre de Sesión y `dispose()`** | Cambiar entre pantallas y pulsar el botón de cerrar sesión en `/home`. | Cancelar listeners en `dispose()`, cancelar el `StreamSubscription` de Firestore y volver a `/login`. | ✅ Correcto. Sin errores de `setState() called after dispose()` ni lecturas residuales. | Comportamiento idéntico del ciclo de vida de widgets en ambas plataformas. |
