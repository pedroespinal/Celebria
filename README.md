# 🎂 Celebria

**Recordatorio de Cumpleaños para Android**

Celebria es una app Android personal para nunca olvidar un cumpleaños.  
Paleta Fiesta (teal + coral + dorado), dark y light mode, bilingüe ES/EN, sin publicidad y sin conexión requerida para su uso principal.

[![Versión](https://img.shields.io/badge/versión-1.9.2-ff6b6b?style=flat-square)](https://github.com/pedroespinal/Celebria/releases/latest)
[![Plataforma](https://img.shields.io/badge/plataforma-Android-6bcb77?style=flat-square)](https://github.com/pedroespinal/Celebria/releases/latest)
[![Flutter](https://img.shields.io/badge/Flutter-Dart-ffd93d?style=flat-square)](https://flutter.dev/)

---

## 📥 Descargar

| Canal | Link |
|-------|------|
| ⬇ APK más reciente | [GitHub Releases](https://github.com/pedroespinal/Celebria/releases/latest) |
| 📋 Historial de versiones | [Todos los releases](https://github.com/pedroespinal/Celebria/releases) |

> **Nota:** Al instalar un APK descargado directamente, Android pedirá permiso para instalar apps de fuentes externas. Es normal — acepta y continúa.

---

## ✨ Características

- 🔔 **Notificaciones push** — programa automáticamente hasta **2 años por adelantado** para que lleguen aunque no abras la app; N días antes + opción de notificar también el día del cumpleaños
- 🔔✅ **Detección automática de notificaciones apagadas** — si el sistema las bloqueó, aparece un aviso nativo al abrir la app con acceso directo a Configuración
- ⏰ **Selector de hora exacto** — elige hora (00–23) y cualquier minuto (:00 a :59) para las notificaciones
- 🧪 **Notificación de prueba** — botón en Configuración para enviar un push real de inmediato y confirmar que Android las muestra
- 🎂 Popup de felicitación al abrir la app el día del cumpleaños, con melodía festiva generada en memoria
- 💬 **Botón WhatsApp** — envía un mensaje de felicitación pre-redactado con un toque en el popup de cumpleaños
- 📱 **Widget en pantalla de inicio** — muestra el próximo cumpleaños con nombre, fecha y días restantes, se actualiza automáticamente
- 👥 Contactos con nombre, fecha, teléfono, email, notas y tipo de relación (Familia / Amigo / Trabajo / Otro)
- 📸 **Foto por contacto** — avatar personalizado o círculo con inicial en el color de la relación
- 🎁 **Nota de regalo** — guarda ideas de regalo por contacto
- 📊 **Estadísticas rápidas** — resumen total, cumpleaños próximos, distribución por relación y por mes
- 📱 **Importar desde Agenda** — lee archivos `.vcf` y extrae contactos con cumpleaños registrados
- 📋 Secciones automáticas: **Hoy · Esta Semana · Próximamente · Todos**
- 🔍 Búsqueda en tiempo real (teclado siempre abierto) + filtro por tipo de relación
- 📆 Calendario mensual con días de cumpleaños destacados
- 📤 Exportar / Importar contactos en JSON
- 🎨 **Paleta Fiesta** — dark mode teal oscuro + light mode crema cálida, con acentos coral, dorado y lima
- 🌙 Tema oscuro / claro con toggle instantáneo
- 🌐 Bilingüe Español / Inglés con cambio en tiempo real (incluyendo footer y About)
- 🔄 Verificador de actualizaciones automático al abrir la app (aparece en Home)
- 🔒 Sistema de versión mínima forzada vía `version.json`

---

## 🛠 Stack técnico

Celebria es 100% **Flutter/Dart** (reescrita desde cero en julio 2026 — antes era un híbrido
Python/Flet + Flutter, ver nota histórica al final).

| Componente       | Tecnología                                      |
|------------------|-------------------------------------------------|
| Lenguaje         | Dart                                             |
| UI Framework     | Flutter (Android nativo)                        |
| Estado           | `provider` (ChangeNotifier simple)              |
| Base de datos    | SQLite vía `sqflite` (local, sin servidor)      |
| Audio            | `audioplayers`                                  |
| Push notifications | `flutter_local_notifications` + `timezone` + `flutter_timezone` |
| Archivos         | `file_picker` (fotos, JSON, VCF)                |
| Build            | `flutter build apk --release` (un solo paso)    |
| Release          | PowerShell + GitHub Releases API                |
| Credenciales     | Windows Credential Manager                      |

---

## 📁 Estructura del proyecto

```
C:\Celebria\
├── version.json                       # Control de versiones para actualizaciones in-app
├── release.ps1                        # Script de release completamente automatizado
├── make_icon.py                       # Genera assets/icon.png (herramienta de diseño, no forma parte de la app)
├── README.md                          # Este archivo
├── assets/
│   └── icon.png                       # Ícono fuente (cake + campana, paleta Fiesta)
└── flutter/                           # TODO el proyecto Flutter — único código fuente de la app
    ├── pubspec.yaml                   # Dependencias + versión (version: X.Y.Z+buildNumber)
    ├── assets/
    │   └── birthday.wav               # Melodía de cumpleaños
    ├── lib/
    │   ├── main.dart                  # Entry point, MaterialApp, birthday/update-check al abrir
    │   ├── notification_helper.dart   # Notificaciones: scheduleFromDB(), llamado directo tras cada escritura a la DB
    │   ├── core/                      # constants, palette, i18n, date_utils, vcf_parser
    │   ├── data/db.dart                # Wrapper sqflite (singleton — ver AppDb.raw)
    │   ├── models/contact.dart
    │   ├── state/app_state.dart       # ChangeNotifier compartido (contactos, idioma, tema)
    │   ├── widgets/                   # app_shell (bottom-nav), contact_card, buttons, avatar
    │   └── screens/                   # home, add_edit, detail, calendar, settings, stats, help, birthday
    └── android/
        ├── app/src/main/
        │   ├── AndroidManifest.xml    # Permisos: POST_NOTIFICATIONS, BOOT_COMPLETED, VIBRATE + receivers
        │   ├── kotlin/com/flet/celebria/
        │   │   ├── MainActivity.kt    # Detecta notificaciones/alarmas desactivadas → popup nativo
        │   │   ├── BootReceiver.kt    # Reprograma notificaciones tras reinicio del teléfono
        │   │   └── BirthdayWidget.kt  # Widget de pantalla de inicio (AppWidgetProvider)
        │   └── res/                   # layout/xml del widget, íconos generados por flutter_launcher_icons
        └── app/build.gradle.kts       # applicationId com.flet.celebria (mantenido para continuidad de updates)
```

---

## 🔔 Cómo funcionan las notificaciones push

Las notificaciones se reprograman **al instante tras cualquier cambio** — agregar o
editar un contacto, cambiar la hora o los días de anticipación en Configuración — y
también al abrir la app. El código Dart lee la base de datos SQLite directamente
(mismo proceso, sin intermediarios) y agenda hasta **4 slots por contacto** (2 años × 2 tipos):

| Slot | Cuándo llega                                    |
|------|-------------------------------------------------|
| 1    | N días antes del cumpleaños — año corriente     |
| 2    | El día del cumpleaños — año corriente (si activo) |
| 3    | N días antes del cumpleaños — año siguiente     |
| 4    | El día del cumpleaños — año siguiente (si activo) |

Esto significa que **no necesitas abrir la app cada año** para recibir recordatorios —
quedan programados 2 años por adelantado.

Cada notificación intenta programarse primero con `AndroidScheduleMode.exactAllowWhileIdle`
(hora exacta, incluso en modo Doze); si el permiso de alarmas exactas no está concedido,
cae automáticamente a `inexactAllowWhileIdle` (llega dentro de una ventana de minutos,
sin requerir ese permiso).

> **Fix crítico en v1.9.2:** hasta esta versión las notificaciones programadas (no las
> inmediatas de prueba) nunca llegaban a entregarse — `AndroidManifest.xml` no declaraba
> los receivers que el plugin de notificaciones necesita para eso, y una versión vieja
> del plugin tenía además un bug que hacía fallar el guardado silenciosamente. Ambos se
> arreglaron y se verificaron con pruebas reales (notificación programada disparándose a
> su hora exacta, y sobreviviendo un reinicio completo del teléfono).

**"También notificar el día del cumpleaños":** se activa desde Configuración → Notificaciones.
Cuando está ON, se programa un segundo recordatorio la mañana misma del cumpleaños.

**Requisito en Android 13+:** la app pedirá permiso `POST_NOTIFICATIONS` la primera
vez que se abre. Si el usuario lo deniega, no llegará ninguna notificación.
Para activarlo después: Ajustes → Apps → Celebria → Permisos → Notificaciones → ON.

**Aviso automático si las notificaciones están apagadas:** al abrir la app, Celebria
detecta nativamente si las notificaciones (o el permiso de alarmas exactas en
Android 12+) están desactivadas, y muestra un popup con un botón que abre
directo la pantalla de Configuración correspondiente. El aviso respeta un
enfriamiento de 12 h para no repetirse en cada apertura.

---

## 📱 Widget de pantalla de inicio

El widget muestra el **próximo cumpleaños** directamente en el home screen de Android.

**Cómo agregarlo:**
1. Mantén presionado un espacio vacío en tu pantalla de inicio
2. Toca **Widgets** → busca **Celebria**
3. Arrástralo a donde quieras (tamaño mínimo 2×2 celdas)

**Qué muestra:**
- Nombre completo del contacto
- Fecha de cumpleaños (dd/mm)
- Días restantes o "¡Hoy!" si es el día

**Actualizaciones:** el widget se refresca automáticamente cada 30 minutos. También se actualiza cuando abres la app o cuando el teléfono reinicia.

> **Nota técnica:** el widget lee la base de datos SQLite directamente desde Kotlin sin depender de que la app esté abierta. Funciona completamente en segundo plano.

---

## 🔧 Cómo compilar

Un solo paso — ya no hay empaquetado de Python ni build de dos fases.

```powershell
# Requisitos previos:
# - Flutter SDK en PATH
# - Android SDK con licencias aceptadas
# - Java 17

$env:PATH = "C:\Users\D0nGibaFok\flutter\3.41.7\bin;" + $env:PATH
Set-Location "C:\Celebria\flutter"
flutter build apk --release
# APK en: flutter\build\app\outputs\flutter-apk\app-release.apk
```

> **Nota:** `release.ps1` maneja este proceso completo automáticamente, incluyendo el versionado.

---

## 🚀 Cómo publicar un release

```powershell
.\release.ps1 -Version "X.Y.Z" -Notes "Descripción del cambio"
```

El script hace todo automáticamente:

1. Verifica que la versión sea mayor que la actual (`flutter/lib/core/constants.dart`)
2. Actualiza `appVersion` en `constants.dart` y `version:` en `flutter/pubspec.yaml`
3. Actualiza `version.json` (`latest` + `download_url`)
4. `flutter build apk --release`
5. Limpia `build\apk\` — deja solo el APK de la versión actual
6. `git commit` + `git tag` + `git push`
7. Crea el release en GitHub vía API y sube el APK

> Requiere token OAuth de GitHub almacenado en Windows Credential Manager  
> bajo la clave `git:https://github.com`

---

## 🔄 Sistema de actualizaciones forzadas

La app lee `version.json` al arrancar para verificar si hay una versión nueva:

```json
{
  "latest":       "1.7.1",
  "minimum":      "1.0.0",
  "download_url": "https://github.com/pedroespinal/Celebria/releases/download/v1.7.1/Celebria-v1.7.1.apk"
}
```

| Campo          | Actualizado por     | Propósito                                      |
|----------------|---------------------|------------------------------------------------|
| `latest`       | `release.ps1`       | Versión más reciente disponible                |
| `minimum`      | **Manual**          | Versión mínima soportada                       |
| `download_url` | `release.ps1`       | Link directo al APK (referencia)               |

**Lógica:**
- `instalada < minimum` → diálogo obligatorio, sin opción de cerrar
- `minimum ≤ instalada < latest` → diálogo sugerido con opción "Ahora no"
- `instalada == latest` → silencioso

El botón "Descargar" abre la **página de releases** de GitHub (no la URL directa del APK) para garantizar que Chrome en Android complete la descarga correctamente.

Para forzar una actualización: editar `minimum` directamente en GitHub y hacer push.  
No requiere recompilar la app.

---

## ⚠ Quirks conocidos

- **`flutter_local_notifications` NO declara en su propio manifest los receivers que necesita para entregar notificaciones programadas** (`ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`, `ActionBroadcastReceiver`) — hay que copiarlos a mano en `AndroidManifest.xml` (ver el `example/` del paquete). Sin esto, `zonedSchedule()` no lanza ningún error y `AlarmManager` sí dispara la alarma a su hora — pero Android no tiene a quién entregarle el broadcast, así que la notificación nunca llega. Esta fue la causa raíz real de que las notificaciones programadas no funcionaran hasta v1.9.2 — el botón de prueba (`show()` inmediato) no necesita estos receivers, por eso parecía que todo andaba bien.
- Usar `flutter_local_notifications: ^19.5.0` o superior, no `18.x` — versiones anteriores a 19.0.0 tienen un bug de GSON conocido (`PlatformException("Missing type parameter")`) que hace fallar silenciosamente `zonedSchedule()`/`cancelAll()` en cada llamada. No subir directo a `20.x`+: esa versión convierte los parámetros posicionales a nombrados (breaking change) y `21.x` sube el `minSdk` a API 24.
- `flutter_local_notifications` requiere `isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` en `build.gradle.kts` — sin esto Gradle falla con `checkReleaseAarMetadata`
- `notification_helper.dart` **nunca** debe abrir su propia conexión sqflite ni cerrarla — debe usar `AppDb.instance.raw`, que comparte la ÚNICA conexión de la app. `sqflite` cachea conexiones por ruta (`singleInstance: true` por defecto), así que un `openDatabase()` independiente al mismo archivo devuelve la MISMA conexión — cerrarla rompe toda la app por el resto de la sesión
- Cualquier widget cuyo `build()` retorne `Expanded(...)` (como `OptionButton`) NUNCA debe envolverse en `Padding` desde afuera — `Expanded` requiere ser hijo directo de un `Row`/`Column`. En modo release este error se ve como un simple **recuadro gris sin texto** (no el overlay rojo/amarillo de debug) — revisar `adb logcat` buscando "DiagnosticsProperty" si aparece
- `NotificationHelper.initialize()` se llama tras el primer frame (`WidgetsBinding.instance.addPostFrameCallback`), no antes de `runApp()` — llamarlo antes puede fallar con `PlatformException` (null Activity) en `requestNotificationsPermission()`
- **Nunca** llamar `requestExactAlarmsPermission()` automáticamente — confirmado en dispositivo real que esto redirige a una pantalla de Configuración de pantalla completa sin ninguna acción del usuario. El permiso de alarmas exactas es opt-in vía el popup nativo en `MainActivity.kt`
- Las fotos de contactos se almacenan en `ApplicationDocumentsDirectory/photos/`
- Exportar JSON usa `FilePicker.platform.saveFile(bytes:)`; importar usa `pickFiles(withData: true)`

---

## 📜 Nota histórica — reescritura de julio 2026

Hasta la v1.8.4, Celebria era un híbrido **Python (Flet 0.85.1) + overlay Flutter/Dart** para
las notificaciones nativas — un diseño que causó varios bugs difíciles de diagnosticar
(el más grave: Python no tenía forma de avisarle a Dart que la base de datos había cambiado,
así que las notificaciones solo se recalculaban al reiniciar la app por completo). En julio
2026 se reescribió toda la app en Flutter/Dart puro, eliminando Python y Flet totalmente.
Todas las funciones se mantuvieron — no fue un recorte de features, sino una migración de
plataforma que además simplificó el pipeline de build (de 2 fases a 1) y redujo el tamaño
del APK de ~72MB a ~51MB.

**Nota adicional — v1.9.2:** incluso después de la reescritura, las notificaciones
programadas seguían sin llegar nunca. La causa real (ver "Quirks conocidos" arriba) no
tenía nada que ver con Python/Flet ni con el código Dart de la app: el `AndroidManifest.xml`
jamás declaró los receivers que `flutter_local_notifications` necesita para entregar una
alarma programada, y el plugin en sí tenía un bug de serialización que fallaba en silencio.
Arreglado y verificado con pruebas reales en v1.9.2.

---

## 👤 Autor

**Pedro Espinal** — Todos los derechos reservados © 2026
