# Primera apertura implementada

Implementación del 2 de octubre de 2026 sobre Godot 4.7.2, GDScript y Compatibility. Conserva la escena principal, el catálogo, el selector y el jardín existentes. Se revisaron README, decisiones, escenas y las guías de primera apertura e identidad antes de modificar la aplicación.

## Alcance disponible

Carga real de archivos y recuperación del servicio, sin espera mínima artificial; bienvenida; introducción de dos pasos; acceso local explícito; rutas para invitar o unirse; PIN y QR generados; revisión con nombre de quien invita; aceptación explícita; espera, cancelación y confirmación; continuación al selector existente. Las aperturas siguientes recuperan la etapa pendiente y, después de continuar, el jardín.

**El proveedor actual es una demostración local.** No autentica cuentas ni conecta dos teléfonos. Toda pantalla lo identifica. Alex es un personaje ficticio; la aceptación simulada sólo se ejecuta al pulsar su botón de prueba. El esquema `appparejas-demo://invitation/` no es una URL pública. Los PIN se buscan únicamente en el almacenamiento del dispositivo que los creó.

Copiar utiliza el portapapeles de la plataforma. Compartir abre la hoja nativa de Android mediante AndroidRuntime y un Intent ACTION_SEND. En escritorio ofrece copiar como recuperación. El QR contiene exactamente el link local generado, con zona blanca de cuatro módulos.

La cámara solicita el permiso real de Android y contempla denegación, reintento, ajustes y alternativa por PIN. **Este APK todavía no contiene un lector nativo de QR**: con permiso concedido informa que falta esa integración, sin fingir un escaneo.

## Cómo probar

1. Abrir con `./tools/Start-AppParejas.ps1`, o generar e instalar en el teléfono con `./tools/Build-Android.ps1 -Install -DeviceSerial <serial>`.
2. Primera apertura: conocer el espacio y completar o saltar la introducción. Cerrar y abrir para comprobar que no vuelve a imponerse.
3. Invitar: ingresar un nombre de demostración, ver PIN y QR, copiar o compartir. Ir a estado y reabrir: debe seguir esperando, sin vínculo confirmado. Usar «Simular aceptación de demo» para probar la confirmación; continuar a cualidades y luego al jardín.
4. Para la ruta receptora, antes de confirmar un vínculo, entrar en «Tengo una invitación». Pulsar «Preparar ejemplo local» y después «Usar invitación de ejemplo». Debe mostrar la revisión de Alex sin aceptar automáticamente. «Ahora no» vuelve sin vincular; «Aceptar invitación de demo» confirma explícitamente.
5. También se puede ingresar el PIN o pegar el link de un ejemplo creado en ese mismo dispositivo. Una invitación recibida antes del acceso queda guardada y se revisa después de ingresar el nombre.
6. Ingresar un PIN inexistente y recuperar con otra invitación. Probar escanear, denegar cámara y recuperar mediante PIN o ajustes. Vencimiento, cancelación, falta de conexión, archivos dañados y respuestas tardías tienen cobertura automatizada.
7. Usar «Texto más grande» (150%) y desplazar con el dedo. El recorrido no anima la carga; el jardín conserva la preferencia de movimiento reducido.

Para repetir desde cero, usar una instalación de prueba independiente o borrar **sólo los datos de AppParejas preview** desde ajustes Android, sabiendo que elimina toda la demostración. La aplicación no borra datos automáticamente ante errores de lectura.

## Estado y arquitectura

| Archivo | Responsabilidad |
| --- | --- |
| `app/src/domain/first_open_state.gd` | Introducción, sesión, invitación y vínculo separados; ruta pendiente, preferencias y selección |
| `app/src/application/first_open_flow.gd` | Navegación, aceptación explícita, reintentos, tiempo límite y descarte de respuestas tardías |
| `app/src/infrastructure/first_open_store.gd` | JSON versionado, validado y escritura mediante archivo temporal |
| `app/src/infrastructure/invitation_service.gd` | Interfaz asíncrona intercambiable |
| `app/src/infrastructure/local_invitation_service.gd` | Demostración persistente, PIN aleatorio, token aleatorio y vencimiento local de 72 horas |
| `app/src/infrastructure/platform_capabilities.gd` | Portapapeles, compartir, permisos, entrada de enlaces y conexión con lector futuro |
| `app/src/ui/first_open_view.gd` | Pantallas adaptables con Lora, DM Sans e identidad botánica |

`user://first_open.json` guarda introducción `new/completed/skipped`, identidad ficticia, referencia pendiente, invitación saliente, confirmación y preferencias. `user://demo_invitations.json` guarda ejemplos locales. No se guardan credenciales ni JWT. Si se cambia de proveedor, hay que migrar el esquema: el almacenamiento actual acepta exclusivamente datos marcados como demo.

Abrir un link, resolver un PIN o recibir `qr_scanned` sólo llama a `receive_reference`, nunca a `accept`. La aceptación revalida estado y vencimiento. Crear, compartir o copiar conserva una invitación pendiente. Consultar estado y volver a primer plano actualizan la espera. La confirmación se recupera del proveedor en cada apertura.

## Conexiones externas pendientes

### Cuentas y backend de invitaciones

Crear un adaptador `InvitationService`, asignarlo a `first_open.service` antes de agregar la escena al árbol y reemplazar el acceso demo por Supabase Auth. Implementar `request(operation, payload, request_id)` y emitir una sola respuesta `completed(request_id, result)`; no introducir esperas artificiales. Operaciones: `bootstrap`, `access`, `create`, `resolve`, `status`, `accept`, `cancel`. `fixture` y `simulate_accept` son exclusivas de la demo y deben retirarse de la interfaz de producción.

Respuestas exitosas contienen `ok: true` y, según operación, `session`, `invitation` o `pair`. Invitación: `id`, `pin`, `link`, `inviter_id`, `inviter_name`, `expires_at`, `status`, `demo`. Vínculo: `id`, `status: confirmed`, `continued`, `demo`. Errores conocidos: `offline`, `invalid_pin`, `expired`, `cancelled`, `used`, `self_invitation`, `already_linked`, `auth`, `storage`, `unavailable`.

Faltan proyecto Supabase, URL y clave pública autorizados, acceso real, persistencia segura de sesión, permiso Internet, tablas/RLS y funciones transaccionales de invitación/aceptación. El servidor debe identificar al actor desde el JWT, controlar vencimiento con su reloj y proteger PIN con límites de intentos. Nunca incluir service-role en el APK. El estado y los rótulos demo deben adaptarse expresamente al habilitar producción; cambiar sólo el proveedor no convierte esta vista previa en una aplicación real.

### Cámara y QR

Agregar un plugin Android compatible con Godot 4.7.2 y exportación Gradle que registre el singleton `AppParejasPlatform`. Contrato preparado: métodos `scan_qr()` y `cancel_scan()`; señales `qr_scanned(reference: String)` y `scan_failed(code: String)`. Entregar callbacks al hilo de Godot. Cerrar la cámara al cancelar o salir; emitir `camera_denied` al denegar, `scanner_unavailable` ante integración ausente, y validar el contenido mediante el servicio antes de mostrar revisión. El permiso CAMERA ya está declarado en el preset y se solicita al pulsar habilitar, no en la apertura.

### Enlaces Android

El puente lee `Activity.getIntent().getDataString()` al cargar y retomar, y escucha `invitation_received(reference: String)` del plugin opcional. Faltan un dominio HTTPS autorizado, su `/.well-known/assetlinks.json` con paquete y certificado correctos, un intent-filter VIEW/BROWSABLE/DEFAULT con autoVerify y rutas restringidas en el manifiesto Gradle. El plugin debe reenviar `onNewIntent` mediante `invitation_received`. Actualizar la validación del esquema demo por la del dominio autorizado. Sin esa configuración, tocar el link en otra app no abre automáticamente esta APK: la ruta disponible es pegarlo dentro de AppParejas. No se inventó dominio ni invitación pública.

## Verificación

`./tools/Test-AppParejas.ps1` pasó **1.221 verificaciones, 0 fallos** (230 existentes y 991 de primera apertura), con almacenamiento aislado. Incluye reapertura, introducción completada/saltada, ambas rutas, invitación antes del acceso, rechazo y aceptación explícitos, idempotencia, cancelación, vencimiento entre revisión y aceptación, PIN erróneo, desconexión/reintento, archivo incompatible y tiempo límite.

La comprobación de disposición cubre 12 estados a 360 y 390 px, con texto al 100% y 150%, sin desborde horizontal y botones de al menos 56 px. `app/tests/capture_first_open.gd` genera 48 capturas con el renderizador real en `.artifacts/first_open/captures/`; se revisaron pantallas representativas y el QR se decodificó independientemente. TalkBack, rendimiento sostenido y lectores de QR nativos quedan por verificar.

En el Samsung SM-S936U1 con Android 16 se verificaron apertura, introducción, acceso demo, invitación/QR, hoja nativa de compartir, copiar/pegar el link, desplazamiento táctil, reapertura en espera, cancelación, solicitud nativa de cámara y recuperación al denegar el permiso mediante PIN/link. También revisión de Alex, aceptación explícita, continuación al selector y reapertura en jardín. El registro `build/android/primera-apertura-celular.log` no mostró errores de Godot durante estas pruebas. Las evidencias están en `build/android/`, excluido de Git; no se enviaron mensajes al probar compartir.

La API de Figma rechazó el acceso a contexto/captura por el límite de consultas del plan Starter. Se aplicaron las guías locales, la referencia local de invitación y el símbolo botánico original; queda pendiente comparar directamente cada pantalla con la página 03 cuando se restablezca el acceso.

Fuentes de integración: [AndroidRuntime](https://docs.godotengine.org/en/stable/classes/class_androidruntime.html), [permisos OS](https://docs.godotengine.org/en/stable/classes/class_os.html), [exportación Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html). El generador QR conserva licencia MIT y procedencia en `app/third_party/qr/README.md`.
