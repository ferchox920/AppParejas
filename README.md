# AppParejas

Aplicación móvil para construir una semilla compartida a partir de lo que dos personas quieren cultivar en su vínculo. El proyecto se encuentra en la fase inicial de desarrollo.

La implementación usa **Godot 4.7.2 con GDScript y Compatibility**. Incluye primera apertura persistente, introducción, invitaciones locales con PIN y QR, revisión y aceptación explícita, selección de cualidades y jardín 3D. El modo de demostración está identificado: no crea cuentas, vínculos ni siembras reales. Consultar [primera apertura y conexiones pendientes](docs/PRIMERA_APERTURA.md).

## Android

La base está preparada para generar un APK de depuración:

```powershell
./tools/Install-AndroidTemplates.ps1
./tools/Build-Android.ps1
```

Para instalarlo y abrirlo en un dispositivo autorizado: `./tools/Build-Android.ps1 -Install -DeviceSerial <serial>`. Consultar [la guía Android](docs/ANDROID.md) para requisitos y resultados. La instalación, bienvenida y jardín se verificaron en el teléfono Samsung SM-S936U1 con Android 16. Las próximas pruebas usan el teléfono; el emulador está cerrado.

## Abrir la vista previa en escritorio

En Windows, desde la raíz del repositorio:

```powershell
./tools/Start-AppParejas.ps1
```

Para abrir el editor:

```powershell
./tools/Start-AppParejas.ps1 -Editor
```

El script descarga el motor portátil oficial sólo si no está disponible, verifica el SHA256 registrado y lo deja en `.tools/`, excluido de Git. También se puede abrir `app/project.godot` directamente con Godot 4.7.2. Para usar una instalación existente, pasar `-GodotPath` o definir `APPPAREJAS_GODOT`.

En macOS o Linux, instalar la misma versión oficial y ejecutar `godot --path app`. El descargador incluido es para Windows.

## Qué se puede probar

- Completar o saltar la introducción y retomar la etapa pendiente al reabrir.
- Invitar, copiar o compartir desde Android, consultar y cancelar una invitación local.
- Preparar un ejemplo receptor, revisar quién invita y aceptar explícitamente.
- Recuperar errores de PIN y permiso de cámara; el lector nativo de QR sigue pendiente.
- Explorar una semilla y cambiar la vista al primer brote.
- Girar, acercar, alejar y restablecer la cámara.
- Elegir entre 3 y 5 cualidades del catálogo de 20, agrupadas en cinco familias.
- Mezclar la elección propia de prueba con una segunda elección ficticia fija.
- Consultar las definiciones, activar movimiento reducido y aumentar el texto.

Las formas usan geometría simple para validar la escena; aún no implementan los veinte motivos visuales del mapa ni modelos finales de Blender. La mezcla local se utiliza sólo para esta vista previa. La receta autorizada y el crecimiento por tiempo corresponderán al servidor.

## Verificar la implementación

```powershell
./tools/Test-AppParejas.ps1
```

El script importa el proyecto y ejecuta las pruebas con el motor real. En otras plataformas:

```sh
godot --headless --path app --editor --quit
godot --headless --path app --script res://tests/run_tests.gd
godot --headless --path app --script res://tests/first_open_tests.gd
```

Las verificaciones cubren catálogo, selección, jardín y el recorrido de primera apertura, persistencia, aceptación explícita, errores y disposición a 360/390 px con texto aumentado. Los resultados y archivos temporales se guardan fuera del seguimiento de Git.

## Organización

| Carpeta | Contenido |
| --- | --- |
| `app/` | Proyecto Godot, escenas, dominio, interfaz y pruebas |
| `tools/` | Versión fijada del motor y scripts de apertura y verificación |
| `docs/` | Estado de la fase inicial y decisiones de implementación |
| `entregables/` | Fuentes funcionales y técnicas, y diseños de Figma |
| `sources/` | Referencias sincronizadas de ChatGPT de sólo lectura, excluidas de Git |

Consultar [el estado de la fase inicial](docs/FASE_INIT.md) y [la primera apertura](docs/PRIMERA_APERTURA.md) antes de considerar esta base un MVP. La exportación e instalación en el teléfono funcionan. Medición sostenida, lectores de pantalla, lector nativo de QR, enlaces públicos, autenticación y backend siguen pendientes.

## Referencias y recursos

- [Diseño editable en Figma](https://www.figma.com/design/53oHlGwhPienbccVt3xyVc).
- [Godot oficial para Windows](https://godotengine.org/download/windows/).
- [Documentación de SubViewportContainer](https://docs.godotengine.org/en/stable/classes/class_subviewportcontainer.html).
- Fuentes DM Sans y Lora del repositorio oficial de Google Fonts, con sus licencias OFL incluidas en `app/assets/fonts/`.

El repositorio de desarrollo está en `D:/PersonalProyect/AppParejas`. La base y los documentos se recuperaron del proyecto de ChatGPT; las referencias originales se conservaron intactas. No se configuró un remoto ni se publicó en GitHub.
