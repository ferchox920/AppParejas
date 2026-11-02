# Desarrollo Android

Actualización: existe un APK de desarrollo conectado a Supabase con Internet habilitado. Consultar [cuentas y validación del MVP](CUENTAS_Y_VALIDACION.md) para las pruebas actuales de HTTPS, teclado, gestos y el pendiente de TalkBack. El resto de esta guía conserva los resultados de las primeras versiones locales.

Inicialización del 2 de octubre de 2026. Se conserva la elección de `DECISIONES_INIT.md`: Godot 4.7.2 estable, GDScript tipado y Compatibility. Supabase/PostgreSQL y Blender/GLB siguen previstos en la arquitectura; esta vista previa funciona con datos ficticios locales.

## Preparar Windows

Instalar JDK 17 y Android SDK con platform-tools, plataforma Android 36 y build-tools 36.0.0 para las plantillas de Godot 4.7.2. El APK directo no requiere un proyecto Gradle, NDK ni CMake. Cerrar el editor Godot antes de ejecutar el script de compilación, ya que configura las rutas de Java y Android en los ajustes locales del editor. Conserva una copia de esos ajustes en `build/android/editor-settings.before-android.tres`.

Instalar las plantillas oficiales de la versión fijada:

```powershell
./tools/Install-AndroidTemplates.ps1
```

El script verifica el SHA512 publicado por Godot y extrae las plantillas Android en `%APPDATA%/Godot/export_templates/4.7.2.stable`. El paquete descargado se conserva en `.tools/`, fuera de Git.

## Generar e instalar

Desde la raíz del repositorio:

```powershell
./tools/Build-Android.ps1
adb devices
./tools/Build-Android.ps1 -Install -DeviceSerial <serial-del-telefono>
```

El APK de depuración queda en `build/android/AppParejas-debug.apk`. Incluye ARM64 para teléfonos y x86_64; usa el identificador provisional `org.appparejas.preview`, versión 0.2.0. Los tests se excluyen del APK y el catálogo JSON se incluye explícitamente. No se habilita Internet en esta vista previa local. Declara CAMERA y pide permiso sólo al habilitar el escaneo; el lector requiere el adaptador descrito en [primera apertura](PRIMERA_APERTURA.md). La exportación utiliza la clave de depuración local de Godot, fuera de Git.

Si las herramientas están en otra ubicación:

```powershell
./tools/Build-Android.ps1 -JavaSdkPath 'C:/ruta/jdk-17' -AndroidSdkPath 'C:/ruta/Android/Sdk'
```

Para un teléfono, activar depuración USB y aceptar en su pantalla la autorización del equipo. `unauthorized` en `adb devices` significa que esa autorización está pendiente. Si hay varios dispositivos, indicar el serial con `-DeviceSerial`.

## Verificación realizada

- Pruebas del proyecto y del nuevo recorrido: resultados en [primera apertura](PRIMERA_APERTURA.md).
- APK exportado, alineado y firmado correctamente con las plantillas 4.7.2.
- Instalación e inicio en Pixel_8_API_35 (Android 15, x86_64).
- Bienvenida y semilla 3D renderizadas con Compatibility en el emulador.
- Instalación e inicio verificados en teléfono Samsung SM-S936U1 con Android 16 y GPU Adreno 830: bienvenida, navegación al jardín y pantalla de cualidades con texto aumentado. El registro de Godot no mostró errores durante esta prueba básica.
- Capturas y registro de exportación en `build/android/`, excluido de Git.

El emulador se cerró y las próximas pruebas se realizarán en el teléfono conectado. Las capturas del teléfono están en `build/android/Inicio-Celular.png`, `Jardin-Celular.png` y `Cualidades-Celular.png`; el registro está en `build/android/celular.log`. Esta prueba básica no mide consumo sostenido, tiempos de cuadro ni accesibilidad con TalkBack. Autenticación, llamadas HTTPS y backend siguen pendientes, según `FASE_INIT.md`.

La versión 0.2.0 agrega primera apertura. Se prueba en el mismo teléfono: introducción, acceso de demostración, invitación con PIN/QR, hoja nativa de compartir, desplazamiento y reapertura en espera. El registro y nuevas capturas quedan en `build/android/`; consultar [el alcance y contrato de integraciones](PRIMERA_APERTURA.md). La prueba de compartir abre la hoja y la cierra sin enviar mensajes.

## Adaptación de pantalla

La interfaz usa `canvas_items` con proporción `expand`: 390 × 844 es la referencia mínima de diseño, no un marco fijo con bandas negras. El preset activa `screen/edge_to_edge` y fondo crema. El fondo cubre la ventana completa y `ScreenLayout` convierte el área segura física de Android a márgenes lógicos para proteger los controles de la cámara, barra de estado y gestos. Los márgenes se recalculan al cambiar el tamaño o retomar la app, sin reiniciar la navegación. Las barras mantienen sus controles del sistema con iconos oscuros sobre el fondo claro.

Las pruebas de geometría incluyen conversión física/lógica, área segura ausente y ventanas donde Android ya descontó las barras para evitar duplicar el espacio reservado.

La barra vertical de desplazamiento está oculta (`SCROLL_MODE_SHOW_NEVER`); el desplazamiento táctil sigue habilitado. El APK actualizado se instaló en el Samsung y se verificó que el fondo ocupa toda la pantalla, las barras de Android tienen iconos legibles y no aparece el indicador vertical de la app.

## Arranque con identidad propia

`application/boot_splash/image` usa `app/assets/boot_splash.png`, una captura de nuestra pantalla de preparación renderizada por Godot con Lora, DM Sans y el símbolo botánico. Reemplaza la imagen predeterminada del motor durante su inicialización. Fondo crema y escala proporcional; no se agrega tiempo mínimo de exposición.

Al estar disponible la escena, `FirstOpenFlow.start()` muestra la misma vista de preparación mientras carga el almacenamiento y espera la respuesta de `InvitationService.bootstrap`. El futuro adaptador de API debe responder por `completed`; hasta entonces se conserva la carga, y un fallo o tiempo límite ofrece recuperación. La bienvenida con acciones aparece cuando finaliza esa operación, si es primera apertura; quien ya tiene recorrido guardado retoma su etapa.

Para regenerar el PNG al modificar el diseño, ejecutar `app/tests/capture_first_open.gd` con el renderizador real y copiar `.artifacts/first_open/captures/loading_390_100.png` a `app/assets/boot_splash.png`. No usar una captura del escritorio o del teléfono con barras del sistema.

## Gesto de volver de Android

Se desactiva `application/config/quit_on_go_back` y se fija `SceneTree.quit_on_go_back = false` al iniciar la escena. La solicitud `NOTIFICATION_WM_GO_BACK_REQUEST` se procesa de forma diferida para poder reconstruir los controles después de que termine la propagación. Gesto y botón del sistema usan esta navegación: cualidades vuelve al jardín, escaneo a PIN/link, acceso a su ruta de conexión, introducción al paso anterior y revisión descarta la referencia sin aceptar el vínculo. Bienvenida y jardín permanecen abiertos; una operación pendiente conserva su pantalla.

Verificación: 230 comprobaciones del proyecto y 1009 de primera apertura, sin fallos, incluyendo la propagación de la solicitud de volver. APK regenerado e instalado en el Samsung conectado. La comprobación manual del gesto queda pendiente porque el teléfono estaba bloqueado; no se verificó el gesto físico en esta sesión.

La [documentación de SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-property-quit-on-go-back) describe el cierre automático al volver, independiente de `auto_accept_quit`.

## Referencias técnicas

- [Exportación Android de Godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html).
- [Código del exportador de la versión fijada](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/export/export_plugin.cpp): SDK objetivo 36.
- [Plantillas y hashes oficiales de Godot 4.7.2](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable).
