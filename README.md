# 🎂 Celebria

**Recordatorio de Cumpleaños para Android**

Celebria es una app Android personal para nunca olvidar un cumpleaños.  
Diseño futurista oscuro, bilingüe ES/EN, sin publicidad y sin conexión requerida para su uso principal.

[![Versión](https://img.shields.io/badge/versión-1.2.2-00e5ff?style=flat-square)](https://github.com/pedroespinal/Celebria/releases/latest)
[![Plataforma](https://img.shields.io/badge/plataforma-Android-00ff88?style=flat-square)](https://github.com/pedroespinal/Celebria/releases/latest)
[![Python](https://img.shields.io/badge/Python-3-yellow?style=flat-square)](https://www.python.org/)
[![Flet](https://img.shields.io/badge/Flet-0.85.1-7c3aed?style=flat-square)](https://flet.dev/)

---

## 📥 Descargar

| Canal | Link |
|-------|------|
| ⬇ APK más reciente | [GitHub Releases](https://github.com/pedroespinal/Celebria/releases/latest) |
| 📋 Historial de versiones | [Todos los releases](https://github.com/pedroespinal/Celebria/releases) |

> **Nota:** Al instalar un APK descargado directamente, Android pedirá permiso para instalar apps de fuentes externas. Es normal — acepta y continúa.

---

## ✨ Características

- 🎂 Popup de felicitación al abrir la app el día del cumpleaños, con melodía festiva generada en memoria
- 👥 Contactos con nombre, fecha, teléfono, email, notas y tipo de relación (Familia / Amigo / Trabajo / Otro)
- 📸 **Foto por contacto** — avatar personalizado o círculo con inicial en el color de la relación
- 🎁 **Nota de regalo** — guarda ideas de regalo por contacto
- 📊 **Estadísticas rápidas** — resumen total, cumpleaños próximos, distribución por relación y por mes
- 📱 **Importar desde Agenda** — lee archivos `.vcf` y extrae contactos con cumpleaños registrados
- 📋 Secciones automáticas: **Hoy · Esta Semana · Próximamente · Todos**
- 🔍 Búsqueda en tiempo real (teclado siempre abierto) + filtro por tipo de relación
- 📆 Calendario mensual con días de cumpleaños destacados
- 💬 Botón WhatsApp directo por contacto
- 📤 Exportar / Importar contactos en JSON (carpeta Descargas)
- 🌙 Tema oscuro / claro con toggle instantáneo
- 🌐 Bilingüe Español / Inglés con cambio en tiempo real
- 🔄 Verificador de actualizaciones automático al abrir la app
- 🔒 Sistema de versión mínima forzada vía `version.json`

---

## 🛠 Stack técnico

| Componente       | Tecnología                        |
|------------------|-----------------------------------|
| Lenguaje         | Python 3                          |
| UI Framework     | Flet 0.85.1 → Flutter → Android   |
| Base de datos    | SQLite (local, sin servidor)      |
| Audio            | flet_audio 0.85.1                 |
| Build            | `flet build apk`                  |
| Release          | PowerShell + GitHub Releases API  |
| Credenciales     | Windows Credential Manager        |

---

## 📁 Estructura del proyecto

```
C:\Celebria\
├── main.py          # App completa en un solo archivo (~2520 líneas)
├── requirements.txt # flet-audio==0.85.1
├── version.json     # Control de versiones para actualizaciones in-app
├── release.ps1      # Script de release completamente automatizado
├── test.ps1         # Script de prueba local en modo escritorio
├── README.md        # Este archivo
└── .gitignore
```

---

## 🔧 Cómo compilar

```powershell
# Requisitos previos: Python 3, Flet 0.85.1, Flutter SDK, Android SDK
Set-Location "C:\Celebria"

# Variables necesarias para evitar crash de Unicode en Windows
$env:PYTHONIOENCODING = "utf-8"
$env:PYTHONUTF8      = "1"
$env:NO_COLOR        = "1"
chcp 65001

flet build apk --artifact "Celebria-X.Y.Z"
# APK generado en: build\apk\Celebria-X.Y.Z.apk
```

---

## 🚀 Cómo publicar un release

```powershell
.\release.ps1 -Version "X.Y.Z" -Notes "Descripción del cambio"

# Omitir prueba local (si ya se probó manualmente):
.\release.ps1 -Version "X.Y.Z" -Notes "Descripción" -SkipTest
```

El script hace todo automáticamente en 6 pasos:

1. Prueba local — abre la app en escritorio para verificar antes de compilar
2. Actualiza `APP_VERSION` en `main.py`
3. Actualiza `version.json` (`latest` + `download_url`)
4. Compila el APK con `flet build apk --artifact "Celebria-X.Y.Z"`
5. Hace `git commit` + `git tag` + `git push` a GitHub
6. Crea el release en GitHub vía API y sube el APK como asset

> Requiere token OAuth de GitHub almacenado en Windows Credential Manager  
> bajo la clave `git:https://github.com`

---

## 🔄 Sistema de actualizaciones forzadas

La app lee `version.json` al arrancar para verificar si hay una versión nueva:

```json
{
  "latest":       "1.2.0",
  "minimum":      "1.0.0",
  "download_url": "https://github.com/pedroespinal/Celebria/releases/download/v1.2.0/Celebria-v1.2.0.apk"
}
```

| Campo          | Actualizado por     | Propósito                                      |
|----------------|---------------------|------------------------------------------------|
| `latest`       | `release.ps1`       | Versión más reciente disponible                |
| `minimum`      | **Manual**          | Versión mínima soportada                       |
| `download_url` | `release.ps1`       | Link directo al APK                            |

**Lógica:**
- `instalada < minimum` → diálogo obligatorio, sin opción de cerrar
- `minimum ≤ instalada < latest` → diálogo sugerido con opción "Ahora no"
- `instalada == latest` → silencioso

Para forzar una actualización: editar `minimum` directamente en GitHub y hacer push.  
No requiere recompilar la app.

---

## ⚠ Quirks conocidos

- `flet build apk` requiere `chcp 65001` + `NO_COLOR=1` en Windows para evitar crash de Unicode por la librería `rich`
- Controles de servicio (`flet_audio`, `FilePicker`) se envuelven en `Container(visible=False)` → Flutter usa `Offstage`: el control funciona pero no se renderiza (evita la barra roja de error en desktop)
- Los links externos (WhatsApp, descarga de APK) usan la propiedad `url=` del Container en vez de `page.launch_url()` para compatibilidad con Android 11+
- `page.launch_url()` falla silenciosamente si se llama desde un hilo secundario (`threading.Timer`); debe llamarse desde el event handler de Flet
- En Flet 0.85.1, `FilePicker.pick_files()` es **sincrónico** — devuelve `list[FilePickerFile]` directamente; `ft.FilePickerResultEvent` no existe en esta versión
- Las fotos de contactos se almacenan en `~/.celebria/photos/` (desktop) o `FLET_APP_STORAGE_DATA/photos/` (Android)

---

## 👤 Autor

**Pedro Espinal** — Todos los derechos reservados © 2025
