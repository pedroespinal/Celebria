# 🎂 Celebria

**Recordatorio de Cumpleaños para Android**

Celebria es una app Android personal para nunca olvidar un cumpleaños.  
Diseño futurista oscuro, bilingüe ES/EN, sin publicidad y sin conexión requerida para su uso principal.

[![Versión](https://img.shields.io/badge/versión-1.0.8-00e5ff?style=flat-square)](https://github.com/pedroespinal/Celebria/releases/latest)
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
- 📊 Countdown de días, cálculo de edad exacta, íconos y colores por relación
- 📋 Secciones automáticas: **Hoy · Esta Semana · Este Mes · Todos**
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
├── main.py          # App completa en un solo archivo (~1900 líneas)
├── requirements.txt # flet-audio==0.85.1
├── version.json     # Control de versiones para actualizaciones in-app
├── release.ps1      # Script de release completamente automatizado
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

flet build apk
# APK generado en: build\apk\Celebria.apk
```

---

## 🚀 Cómo publicar un release

```powershell
.\release.ps1 -Version "X.Y.Z" -Notes "Descripción del cambio"
```

El script hace todo automáticamente en 6 pasos:

1. Actualiza `APP_VERSION` en `main.py`
2. Actualiza `version.json` (`latest` + `download_url`)
3. Compila el APK con `flet build apk`
4. Hace `git commit` + `git tag` + `git push` a GitHub
5. Crea el release en GitHub vía API
6. Sube el APK como asset del release

> Requiere token OAuth de GitHub almacenado en Windows Credential Manager  
> bajo la clave `git:https://github.com`

---

## 🔄 Sistema de actualizaciones forzadas

La app lee `version.json` al arrancar para verificar si hay una versión nueva:

```json
{
  "latest":       "1.0.8",
  "minimum":      "1.0.0",
  "download_url": "https://github.com/pedroespinal/Celebria/releases/download/v1.0.8/Celebria-v1.0.8.apk"
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
- `flet_audio` se envuelve en `Container(visible=False)` → Flutter usa `Offstage`: el audio funciona pero el control no se renderiza (evita la barra roja de error)
- Los links externos (WhatsApp, descarga de APK) usan la propiedad `url=` del Container en vez de `page.launch_url()` para compatibilidad con Android 11+

---

## 👤 Autor

**Pedro Espinal** — Todos los derechos reservados © 2025
