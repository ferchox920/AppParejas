# AppParejas

Aplicación móvil para construir una semilla compartida a partir de lo que dos personas quieren cultivar en su vínculo. El proyecto está en desarrollo del MVP: acceso y vínculo reales disponibles; selección compartida, acuerdo, siembra y brote reales pendientes.

El [seguimiento general del MVP](AVANCE_MVP.md) define los objetivos, su estado, los criterios de cierre y el orden de los próximos bloques. Consultarlo al iniciar trabajo y actualizarlo al terminar cada bloque.

Ya existe una integración de desarrollo con Supabase para acceso por correo e invitaciones autenticadas. Su configuración es local; sin ella se abre la demostración. Consultar [cuentas y validación del MVP](CUENTAS_Y_VALIDACION.md) para evidencia y pendientes de cierre.

La implementación usa **Godot 4.7.2 con GDScript y Compatibility**. Incluye primera apertura persistente, introducción, invitaciones locales con PIN y QR, revisión y aceptación explícita, selección de cualidades y jardín 3D. El modo de demostración está identificado: no crea cuentas, vínculos ni siembras reales. Consultar [primera apertura y conexiones pendientes](PRIMERA_APERTURA.md).

## Android

La base está preparada para generar un APK de depuración:

```powershell
./tools/Install-AndroidTemplates.ps1
./tools/Build-Android.ps1
```

Para instalarlo y abrirlo en un dispositivo autorizado: `./tools/Build-Android.ps1 -Install -DeviceSerial <serial>`. Consultar [la guía Android](ANDROID.md) para requisitos y resultados. La instalación, bienvenida y jardín se verificaron en el teléfono Samsung SM-S936U1 con Android 16. Las próximas pruebas usan el teléfono; el emulador está cerrado.

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

Para explorar automáticamente el recorrido completo de demostración con el renderizador real: `./tools/Explore-AppParejas.ps1`. Usa datos de prueba aislados y no envía correos. Consultar [autoexploración y refinamiento](AUTOEXPLORACION.md) para resultados y límites de esta comprobación.

## Organización

| Carpeta | Contenido |
| --- | --- |
| `app/` | Proyecto Godot, escenas, dominio, interfaz y pruebas |
| `tools/` | Versión fijada del motor y scripts de apertura y verificación |
| `docs/` | Estado de la fase inicial y decisiones de implementación |
| `entregables/` | Fuentes funcionales y técnicas, y diseños de Figma |
| `sources/` | Referencias sincronizadas de ChatGPT de sólo lectura, excluidas de Git |

Consultar el [seguimiento general del MVP](AVANCE_MVP.md) antes de considerar completa esta base. La exportación Android, el acceso por correo y el vínculo bilateral funcionan en desarrollo. Siguen pendientes validación móvil completa, sesión segura, elecciones compartidas, acuerdo, siembra, crecimiento y salida. El [estado de la fase inicial](FASE_INIT.md) y la [primera apertura](PRIMERA_APERTURA.md) conservan el registro histórico y la demostración.

## Referencias y recursos

- [Diseño editable en Figma](https://www.figma.com/design/53oHlGwhPienbccVt3xyVc).
- [Godot oficial para Windows](https://godotengine.org/download/windows/).
- [Documentación de SubViewportContainer](https://docs.godotengine.org/en/stable/classes/class_subviewportcontainer.html).
- Fuentes DM Sans y Lora del repositorio oficial de Google Fonts, con sus licencias OFL incluidas en `app/assets/fonts/`.

El repositorio conserva el código, los documentos funcionales y técnicos, los recursos visuales y las pruebas. La configuración privada, las herramientas descargadas y los artefactos de desarrollo permanecen fuera de Git.
