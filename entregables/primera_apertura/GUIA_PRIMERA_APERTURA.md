# AppParejas · Primera apertura

2 de octubre de 2026 · Propuesta de diseño para revisar.

El recorrido se agregó al archivo existente de Figma, en la página **03 · Primera apertura**. La conexión MCP alcanzó el límite del plan Starter; se editó mediante la interfaz de Figma con la sesión disponible. Las pantallas conservan textos nativos (Lora y DM Sans) y vectores editables. Los nuevos marcos tienen 390 × 844 px y composición fija; todavía no reutilizan instancias de la biblioteca ni auto layout.

- [Página editable](https://www.figma.com/design/53oHlGwhPienbccVt3xyVc?node-id=19-133)
- [Guía dentro de Figma](https://www.figma.com/design/53oHlGwhPienbccVt3xyVc?node-id=22-114)
- [Prototipo desde la carga](https://www.figma.com/proto/53oHlGwhPienbccVt3xyVc/AppParejas-%C2%B7-Plantillas-V1?node-id=19-138&scaling=scale-down&content-scaling=fixed&page-id=19%3A133&starting-point-node-id=19%3A138)

## Pantallas

| Pantalla | Nodo |
| --- | --- |
| 00 · Carga inicial | 19:138 |
| 01 · Bienvenida | 19:158 |
| 02 · Introducción — elegir | 19:187 |
| 03 · Introducción — cultivar | 19:222 |
| 04 · Conectar con mi pareja | 19:249 |
| 05 · Invitar — link, PIN y QR | 19:272 |
| 06 · Unirme con un PIN | 19:599 |
| 07 · Escanear un QR | 19:625 |
| 08 · Revisar y aceptar invitación | 19:647 |
| 09 · Esperando aceptación | 19:671 |
| 10 · Vínculo confirmado | 19:697 |
| 11 · Invitación no disponible | 19:724 |
| 12 · Error de carga | 19:747 |
| 13 · PIN incorrecto | 19:769 |

## Recorrido

La carga conduce a bienvenida. Se presentan la elección individual de 3 a 5 cualidades, su encuentro en una semilla compartida, el acuerdo para sembrar y el crecimiento sin rachas. Se puede saltar directamente a conectar, o acceder desde bienvenida a una invitación recibida.

Invitar ofrece compartir link, copiar link y mostrar PIN o QR. Unirse ofrece ingresar PIN o escanear QR; abrir un link recibido debe conducir a revisar la invitación. Antes de aceptar se muestra quién invita. El envío de una invitación lleva al estado de espera; sólo la aceptación confirma el vínculo.

El prototipo conecta la ruta principal, ambas alternativas, revisión y aceptación, acceso por PIN y QR simulado, espera y recuperaciones de error. Las conexiones se agregaron a los controles del recorrido, no a toda la pantalla. La carga tiene una transición de 800 ms exclusivamente para demostrar la secuencia.

## Límites del ejemplo y reglas de implementación

- Alex y los PIN son datos ficticios. El QR es ilustrativo, no contiene una invitación válida.
- Compartir link simula el paso a espera. Copiar link no realiza una operación de portapapeles; tampoco se abre una hoja de compartir real.
- Habilitar cámara simula el reconocimiento y conduce a revisión. No solicita permisos ni usa la cámara.
- El PIN es texto de ejemplo, no un campo que consulta un servicio. Los errores son marcos separados para revisar su presentación.
- La aceptación es una transición visual; no crea una cuenta ni un vínculo real. Espera no se actualiza con la acción real de otra persona.
- El botón de selección de cualidades señala la siguiente etapa, pero no conecta con la pantalla existente de la otra página. Volver más tarde tampoco persiste una sesión.
- En producción, mostrar bienvenida e introducción una vez; recuperar la sesión y llevar a su jardín a quien ya está vinculado. La carga termina con la operación real, sin espera artificial.
- Resolver un link, PIN o QR debe mostrar la invitación antes de confirmar. No vincular automáticamente al escanear o abrir un link.
- La autenticación y los consentimientos necesarios para materializar el vínculo quedan para el siguiente diseño de acceso a cuenta. No se implementaron cambios en Godot.
- Completar permisos de cámara denegados, invitación ya utilizada, cuenta ya vinculada, renovación/revocación y cancelación de invitación; componentizar controles y adaptar auto layout, texto aumentado y anchos menores.

## Verificación

Se comprobaron las capas de texto nativo durante la importación y la persistencia de los 14 marcos en el archivo. En Presentar se probó la transición de carga a bienvenida y los botones de bienvenida, introducción, conexión e invitación. Las conexiones de los estados adicionales se comprobaron en el panel de interacciones; no se hizo una prueba completa de todas las ramas. Se revisaron capturas del recorrido principal, sin recortes ni superposiciones de texto visibles.

`Figma_invitacion.jpg` conserva una captura de la pantalla de invitación en el prototipo revisado.
