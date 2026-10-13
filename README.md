# proyecto_app_pablo_casado (`proy1`)

Aplicación móvil y web desarrollada en Flutter con Firebase (Auth, Firestore y Storage) para la asignatura **Programación Multimedia y Dispositivos Móviles (PMDM)**.

---

## 🏛️ Arquitectura y Estructura del Proyecto

El proyecto está organizado en las siguientes capas y vistas:

```text
lib/
├── admins/            # Administradores auxiliares
│   ├── device_admin.dart
│   ├── firebase_admin.dart
│   └── storage_admin.dart
├── data/              # Estado global en memoria (Singleton)
│   └── data_holder.dart
├── fb_objects/        # Objetos modelo para Cloud Firestore
│   ├── conversacion.dart
│   ├── mensaje.dart
│   └── perfil.dart
├── ins_lib/           # Librería interna de temas y navegación
│   ├── bot_bars/ins_bot_bar_style1.dart
│   └── theme/app_theme.dart
└── views/             # Vistas de la aplicación
    ├── chat_screen.dart
    ├── conversaciones_view.dart
    ├── home_view.dart
    ├── login_screen.dart
    ├── onboarding_screen.dart
    ├── register_screen.dart
    └── splash_screen.dart
```

---

## 🧭 Rutas Nombradas de la Aplicación

| Ruta | Vista | Descripción |
| --- | --- | --- |
| `/` o `/splash` | `SplashScreen` | Carga inicial e inicialización de sesión |
| `/onboarding` | `OnboardingScreen` | Tarjetas introductorias deslizables |
| `/login` | `LoginScreen` | Inicio de sesión con Firebase Authentication |
| `/register` | `RegisterScreen` | Registro de nuevos usuarios |
| `/home` | `HomeView` | Panel principal del usuario logueado con datos de perfil |
| `/conversaciones` (o `/messages`) | `ConversacionesView` | Lista de conversaciones activas agrupadas por contacto |
| `/chat` | `ChatScreen` | Pantalla de conversación individual 1 a 1 en tiempo real |

---

## 🛠️ Requisitos e Instalación

1. Asegúrate de tener instalado **Flutter SDK** (^3.13.4 o superior).
2. Ejecuta `flutter pub get` para instalar las dependencias.
3. Inicia la app con `flutter run`.
