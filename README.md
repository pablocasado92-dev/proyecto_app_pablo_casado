# proyecto_app_pablo_casado (`proy1`)

Aplicación móvil y web desarrollada en Flutter con Firebase (Auth, Firestore y Storage) para la asignatura **Programación Multimedia y Dispositivos Móviles (PMDM)**.

---

## 🏛️ Arquitectura y Estructura del Proyecto

El proyecto está organizado por capas y componentes reutilizables:

```text
lib/
├── admins/            # Administradores de Firebase, Storage y Dispositivo
│   ├── device_admin.dart
│   ├── firebase_admin.dart
│   └── storage_admin.dart
├── data/              # Estado global y persistencia en memoria
│   └── data_holder.dart
├── fb_objects/        # Modelos de objetos para Cloud Firestore
│   ├── mensaje.dart
│   └── perfil.dart
├── ins_lib/           # Librería interna de temas y barras de navegación
│   ├── bot_bars/ins_bot_bar_style1.dart
│   └── theme/app_theme.dart
└── views/             # Vistas de la aplicación
    ├── edit_profile_view.dart
    ├── home_profile_gate.dart
    ├── home_view.dart
    ├── login_screen.dart
    ├── message_detail_view.dart
    ├── messages_view.dart
    ├── onboarding_screen.dart
    ├── profile_view.dart
    ├── register_screen.dart
    └── splash_screen.dart
```

---

## 🧭 Rutas Nombradas de la Aplicación

| Ruta | Vista | Descripción |
| --- | --- | --- |
| `/` o `/splash` | `SplashScreen` | Carga inicial y evaluación asíncrona de sesión/onboarding |
| `/onboarding` | `OnboardingScreen` | Tarjetas introductorias deslizables |
| `/login` | `LoginScreen` | Inicio de sesión con Firebase Authentication |
| `/register` | `RegisterScreen` | Registro de nuevos usuarios con validación |
| `/home` | `HomeProfileGate` -> `HomeView` | Puerta de acceso y pantalla principal del perfil |
| `/profile` | `ProfileView` | Formulario inicial de creación de perfil |
| `/edit_profile` | `EditProfileView` | Edición de datos y actualización de avatar comprimido |
| `/messages` | `MessagesView` | Lista en tiempo real de mensajes |
| `/message_detail` | `MessageDetailView` | Vista detallada de un mensaje seleccionado |

---

## 🛠️ Requisitos e Instalación

1. Asegúrate de tener instalado **Flutter SDK** (^3.13.4 o superior).
2. Ejecuta `flutter pub get` para instalar las dependencias.
3. Inicia la app con `flutter run`.
