# proyecto_app_pablo_casado (`proy1`)

Aplicación móvil y web desarrollada en Flutter con Firebase (Auth, Firestore y Storage) para la asignatura **Programación Multimedia y Dispositivos Móviles (PMDM)**.

---

## 🏛️ Arquitectura y Estructura Simplificada del Proyecto

El proyecto se compone exactamente de las **6 vistas principales** requeridas:

```text
lib/
├── admins/            # Administradores auxiliares
│   ├── device_admin.dart
│   ├── firebase_admin.dart
│   └── storage_admin.dart
├── data/              # Estado global en memoria (Singleton)
│   └── data_holder.dart
├── fb_objects/        # Modelos para Cloud Firestore
│   ├── mensaje.dart
│   └── perfil.dart
├── ins_lib/           # Librería de temas y navegación
│   ├── bot_bars/ins_bot_bar_style1.dart
│   └── theme/app_theme.dart
└── views/             # Las 6 Vistas de la aplicación
    ├── home_view.dart
    ├── login_screen.dart
    ├── messages_view.dart
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
| `/messages` | `MessagesView` | Lista de mensajes en tiempo real con modal de detalle |

---

## 🛠️ Requisitos e Instalación

1. Asegúrate de tener instalado **Flutter SDK** (^3.13.4 o superior).
2. Ejecuta `flutter pub get` para instalar las dependencias.
3. Inicia la app con `flutter run`.
