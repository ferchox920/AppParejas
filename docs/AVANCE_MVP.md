# Avance general de AppParejas

Última actualización: **6 de noviembre de 2026**. Última evidencia de ejecución: **6 de noviembre de 2026**.

Este es el documento principal para decidir qué desarrollar, revisar los objetivos cumplidos y registrar el avance del MVP. Las guías técnicas vinculadas conservan los detalles y las pruebas. Actualizar este documento al terminar cada bloque de trabajo.

## Objetivo del MVP

Dos personas, cada una desde su cuenta, crean un vínculo, eligen entre 3 y 5 cualidades, consienten compartirlas, revisan una semilla común, aprueban la misma versión del acuerdo, confirman la siembra y recuperan el primer brote. El servidor protege la privacidad, los consentimientos y las transiciones. Cualquiera puede desvincularse.

La V1 termina con el primer brote. Quedan fuera chat, pagos, monedas, actividades, puntuaciones, rachas y notificaciones automáticas. La planta no penaliza la ausencia.

Android es la plataforma en desarrollo y verificación, con Samsung y computadora como clientes de prueba. La inclusión de iOS en el primer lanzamiento sigue por confirmar; si se incluye, requiere entorno macOS/Xcode y validación con VoiceOver.

## Dónde estamos

La aplicación Android tiene acceso por código de correo, vínculo bilateral, selección privada y revelación con Supabase de desarrollo. El acuerdo, la siembra y el primer brote están validados con backend local en el emulador. Quedan por comprobar en Supabase de desarrollo.

La sesión segura de Android se probó en el emulador contra Supabase de desarrollo con cuentas sintéticas. Queda por repetir la recuperación con la cuenta principal del registro histórico.

El refinamiento autónomo del 4 de octubre corrigió recuperación de errores, respuestas tardías, asociación de códigos de invitación, validación de sesión y conservación del formulario/texto aumentado. Pasaron 1347 pruebas de código y 33 comprobaciones del recorrido visual en escritorio. Android emulado conserva cuatro fallos visuales; el Samsung estaba bloqueado. Ver [autoexploración](AUTOEXPLORACION.md). Estos resultados no cierran la validación móvil ni el acceso real tras reabrir.

Después del desbloqueo se repitió la exploración en Samsung: 33 comprobaciones sin fallos y sin errores gráficos en el registro. Se corrigió el ancho de los controles del jardín al 200%; las pruebas de código actuales suman **1349 sin fallos**. El gesto desde el jardín demo mantiene la app abierta y el toque muestra el brote. Los pendientes del vínculo real y TalkBack se conservan.

No asignamos un porcentaje global: un catálogo o jardín de demostración no demuestra que el mismo recorrido funcione entre dos cuentas. El avance se mide por criterios de aceptación cumplidos y evidencia.

## Estados y regla de cierre

| Estado | Significado |
| --- | --- |
| Pendiente | No hay implementación funcional del objetivo real. |
| En desarrollo | Hay una implementación parcial o una alternativa en evaluación. |
| Por validar | La implementación existe; faltan pruebas necesarias para cerrar. |
| Cumplido | Todos los criterios de aceptación tienen evidencia verificable. |

Un objetivo se cierra cuando funciona en el entorno previsto, supera sus pruebas relevantes y deja evidencia con fecha. Una captura aislada o una prueba de demostración no cierra un recorrido real. Si una regresión invalida un criterio, el objetivo vuelve a «Por validar» o «En desarrollo».

## Objetivos de seguimiento

Estos identificadores son propios del seguimiento. Los puntos «1 y 2» de nuestra conversación corresponden a **MVP-01 y MVP-02**. No sustituyen la numeración de entregas del plan técnico original, cuya entrega 2 también incluye la selección.

| ID | Objetivo | Estado | Resultado disponible / falta principal |
| --- | --- | --- | --- |
| MVP-00 | Base reproducible del proyecto | Cumplido | Motor fijado, estructura, exportación Android y verificaciones reproducibles. |
| MVP-01 | Validación móvil y decisión del motor | En desarrollo | APK, HTTPS, teclado y navegación comprobados parcialmente. TalkBack sigue sin exponer los controles de la versión principal en el emulador. El gesto autenticado pasó con una cuenta sintética en el emulador. Faltan mediciones y accesibilidad completa. |
| MVP-02 | Cuentas y vínculo bilateral real | Por validar | Vínculo confirmado históricamente. Sesión segura verificada con datos de prueba en el emulador. Reapertura y sesión verificadas contra el servicio alojado con cuentas sintéticas. La cuenta principal histórica queda pendiente. |
| MVP-03 | Selección privada y revelación bilateral | Validado en desarrollo | 9 de 9 casos aprobados en Android emulado con backend local. El borrador, la espera, la revelación y la reapertura también se verificaron previamente contra Supabase de desarrollo. |
| MVP-04 | Acuerdo y receta compartida | Validado en desarrollo local | Receta del servidor, edición y aprobación bilateral por versión verificadas en Android emulado. Falta aplicar y probar las migraciones de M4 en Supabase de desarrollo. |
| MVP-05 | Siembra única y primer brote | Validado en desarrollo local | Confirmación bilateral, cultivo único y brote a las 168 horas verificados en Android emulado. Falta aplicar y probar M4 y M5 en Supabase de desarrollo. |
| MVP-06 | Salida, eliminación y recuperación | Pendiente | Cierre de sesión y algunos errores de red implementados; faltan desvinculación y eliminación real. |
| MVP-07 | Piloto del recorrido completo | Pendiente | Requiere objetivos anteriores, privacidad, comprensión y calidad móvil validadas. |

### MVP-00 · Base reproducible

- [x] Godot 4.7.2, GDScript y Compatibility fijados para la base actual.
- [x] Separación de dominio, flujo, infraestructura e interfaz.
- [x] Catálogo de 20 cualidades en cinco familias, con identificadores estables.
- [x] Exportación e instalación del APK de depuración en Samsung.
- [x] Configuración local excluida de Git; APK sin claves administrativas.
- [x] Herramientas de importación, pruebas y compilación.

Evidencia: [README](../README.md), [Android](ANDROID.md), [decisiones iniciales](DECISIONES_INIT.md), `tools/toolchain.json`, `tools/Build-Android.ps1` y `tools/Test-AppParejas.ps1`. Este cierre no aprueba todavía el motor para lanzamiento ni constituye una versión de producción.

### MVP-01 · Validación móvil

- [x] Apertura, primera navegación y jardín de demostración instalados en Samsung Android 16.
- [x] Comunicación HTTPS real con Supabase, sin desactivar validación de certificados.
- [x] Formularios desplazables y teclado Samsung con texto al 150%.
- [x] Gesto lateral desde el formulario: vuelve sin cerrar la app; con teclado conserva el campo escrito.
- [x] Recorrido autónomo de demo en Samsung y gesto desde su jardín; controles del jardín al 200% sin desborde horizontal.
- [x] Comprobar el gesto desde un vínculo confirmado en Supabase con una cuenta sintética en el emulador. La comprobación física queda diferida.
- [ ] Validar TalkBack en todo el recorrido destinado al MVP: lectura, foco, campos, errores, desplazamiento y acciones.
- [ ] Verificar texto al 200% en el dispositivo y conservar todas las acciones accesibles.
- [ ] Medir rendimiento sostenido del jardín y comparar renderizadores según el presupuesto del plan técnico.
- [ ] Ratificar la versión del motor y el renderizador con esos resultados.

TalkBack expone controles y permite escribir en una copia con Godot 4.8 dev 7. La copia pasó las 1325 comprobaciones existentes. **La app principal sigue en 4.7.2, donde TalkBack no expone sus controles.** La versión preliminar no se adopta sólo por esa prueba parcial. La copia se desinstaló del teléfono al terminar; el APK de prueba se conserva localmente.

Evidencia: [validación de cuentas y teléfono](CUENTAS_Y_VALIDACION.md), [prueba de accesibilidad](ACCESIBILIDAD_ANDROID.md) y capturas/registros locales allí identificados.

### MVP-02 · Cuentas y vínculo real

- [x] Proyecto Supabase de desarrollo y migración de vínculo aplicados.
- [x] Acceso por OTP numérico, perfil, consentimiento y cierre de sesión.
- [x] SMTP y plantillas de correo con código configurados para pruebas.
- [x] Crear, consultar, revisar, aceptar y cancelar invitaciones autenticadas.
- [x] Confirmación bilateral con dos cuentas distintas en Samsung y computadora.
- [x] Pruebas locales de permisos, restricciones, idempotencia y aceptación concurrente.
- [x] Consulta anónima rechazada por el servicio real.
- [x] Recuperar el mismo vínculo alojado después de terminar el proceso y tras verificar un OTP sintético en Android.
- [ ] Repetir con la cuenta principal histórica y un OTP recibido por correo.
- [x] Integrar almacenamiento seguro, renovación y borrado al cerrar sesión. Reapertura, revocación y reintento comprobados con respuestas controladas en Android emulado.
- [x] Verificar esos casos contra Supabase de desarrollo en el emulador con cuentas sintéticas.
- [x] Comprobar en la base alojada que una tercera identidad sintética no accede al vínculo ajeno bajo el rol autenticado. La prueba se revirtió.
- [x] Comprobar en la base alojada que no se pueden aceptar invitaciones canceladas o vencidas y que consultar después no confirma un vínculo.
- [x] Completar la reconexión desde el cliente Android contra el servicio alojado con un vínculo sintético.

Android conserva cifrado el token de renovación. Al reabrir, consulta Auth y después el estado del vínculo. Para comprobar la recuperación con la cuenta principal del registro histórico hace falta un primer acceso por OTP en el emulador. La permanencia posterior es un criterio separado. El alias de Gmail sirve como segunda cuenta de prueba, aunque ambos correos lleguen a una sola bandeja.

El código solicitado el 2 de octubre no se considera vigente ni se reutiliza como evidencia. Para retomar la prueba, comprobar primero el estado del cliente y solicitar un código nuevo si corresponde, una sola vez.

Evidencia: [cuentas y validación](CUENTAS_Y_VALIDACION.md), `backend/supabase/migrations/202610020001_connection.sql`, `tools/Test-Backend.ps1` y `app/tests/account_connection_tests.gd`. La migración ya aplicada no se vuelve a ejecutar; los cambios siguientes se agregan como nuevas migraciones.

### MVP-03 · Selección privada y revelación

[Objetivos, recorrido medible y resultados de los nueve casos de M3](MVP_03.md#aceptación-en-android-emulado--17-de-noviembre-de-2026).

- [x] Guardar una selección propia de 3 a 5 IDs únicos del catálogo vigente, aislada por cuenta y vínculo.
- [x] Mantener las elecciones privadas hasta que ambos consientan compartir sus revisiones vigentes.
- [x] Mostrar espera y revelar sólo la proyección autorizada por el servidor.
- [x] Recuperar el borrador propio y manejar cambios concurrentes y pérdida de conexión.
- [x] Al reabrir elecciones, retirar ambos consentimientos y ocultar la revelación. Las aprobaciones se incorporan en M4.
- [x] Probar con dos integrantes y una tercera cuenta, incluyendo acceso directo por API.

Cierre: las dos cuentas comparten y recuperan elecciones reales sin filtrarlas antes del consentimiento. El selector local y la segunda elección ficticia no cumplen este objetivo.

### MVP-04 · Acuerdo y receta

- [x] Generar en el servidor una receta determinista que conserve los aportes equivalentes de ambos integrantes.
- [x] Representar la misma identidad de semilla en ambos clientes, con explicación textual.
- [x] Guardar nombre, intención y versión del acuerdo.
- [x] Registrar dos aprobaciones explícitas sobre la misma versión.
- [x] Invalidar aprobaciones afectadas al editar y rechazar versiones antiguas.

El 17 de noviembre se aprobaron ocho casos de extremo a extremo con dos clientes en `AppParejas_API_35` y sesiones sintéticas. El backend aislado ejecutó las migraciones del repositorio en PostgreSQL 17 y las RPC mediante PostgREST. El APK de prueba usó la escena principal y el transporte HTTPS con un certificado de prueba.

| Caso | Resultado |
| --- | --- |
| M4-01 | La receta y el acuerdo permanecen privados hasta el segundo consentimiento. |
| M4-02 | Ambos clientes reciben la misma identidad y renderizan la semilla con la receta del servidor. |
| M4-03 | La aprobación exige un nombre. Cuando el servidor rechaza el texto, el formulario conserva lo escrito. |
| M4-04 | Consultar después de perder una respuesta recupera el nombre, la intención y una sola versión. |
| M4-05 | Cada integrante ve quién aprobó. Ambas aprobaciones se registran en la misma versión. |
| M4-06 | Una edición retira las aprobaciones. Una versión obsoleta se rechaza y dos aprobaciones concurrentes de la versión vigente se registran. |
| M4-07 | Una cuenta externa queda fuera de la lectura y la aprobación. |
| M4-08 | Reabrir elecciones oculta el acuerdo y recupera ambos borradores privados. Una nueva revelación crea un acuerdo sin nombre ni aprobaciones. |

Pasaron la [suite SQL de M4](../backend/tests/mvp04_agreement.sql), las regresiones SQL de M3 y la migración de un vínculo previamente revelado. El servidor normaliza el texto y cuenta grafemas según Unicode 17. La prueba de conformidad verificó 692 casos representables en PostgreSQL. [Unicode Text Segmentation](https://www.unicode.org/reports/tr29/)

Evidencia local en `.artifacts/m4-acceptance/`: `emulator.log`, `backend.log`, `upgrade.log` y `acuerdo-aprobado.png`. El APK separado verifica el flujo con datos de prueba y el arte provisional de Godot. La siembra corresponde a MVP-05.

### MVP-05 · Siembra y primer brote

- [x] Registrar confirmaciones de siembra explícitas de ambas personas sobre el acuerdo vigente.
- [x] Crear un único cultivo mediante una transacción del servidor, incluso con reintentos y concurrencia.
- [x] Guardar receta y acuerdo inmutables después de sembrar.
- [x] Determinar el primer brote con tiempo de servidor: 168 horas desde la siembra.
- [x] Recuperar jardín y etapa en ambos clientes sin depender del reloj del teléfono.
- [x] Registrar por persona la presentación del hito, sin modificar el crecimiento.

El 17 de noviembre se aprobaron ocho casos en `AppParejas_API_35` con dos sesiones sintéticas y PostgreSQL 17/PostgREST aislados.

| Caso | Resultado |
| --- | --- |
| M5-01 | La siembra exige dos aprobaciones sobre la versión vigente antes de aceptar confirmaciones. |
| M5-02 | Perder una respuesta HTTPS y consultar recupera la confirmación registrada. Una sola confirmación deja la siembra pendiente. |
| M5-03 | Se puede retirar y volver a confirmar antes de sembrar. Una edición invalida las confirmaciones de la versión previa. |
| M5-04 | Dos confirmaciones concurrentes crean un único cultivo. Los reenvíos recuperan el mismo identificador. |
| M5-05 | El cultivo congela el nombre, la intención, la receta y la versión. Se bloquean la edición, la reapertura de las elecciones y la retirada de la siembra. |
| M5-06 | Al reabrir con la sesión de Keystore y el reloj del emulador adelantado ocho días, la app recupera el mismo cultivo en etapa semilla. Se restauró el reloj del emulador al terminar. |
| M5-07 | Al vencer el plazo de servidor, consultas concurrentes recuperan el mismo primer brote. Marcarlo como visto sólo afecta a quien lo marcó. |
| M5-08 | Una cuenta ajena queda fuera del jardín y del registro de presentación. |

La [suite SQL de M5](../backend/tests/mvp05_cultivation.sql) verificó el paso de semilla a brote en el límite de las 168 horas. Para repetir la transición en Android se ajustaron las fechas del cultivo en la base desechable. La app consulta al servidor al reabrir, al volver a primer plano y al actualizar el jardín.

Evidencia local en `.artifacts/m5-acceptance/` con los registros `emulator-plant.log`, `clock-test.log`, `emulator-sprout.log`, `counts.log` y las capturas `semilla.png` y `brote.png`.

### MVP-06 · Salida y recuperación

- [ ] Permitir desvinculación unilateral y revocar el acceso cruzado en el servidor.
- [ ] Revocar invitaciones y cancelar acciones bilaterales pendientes al salir.
- [ ] Implementar eliminación de cuenta y datos con tareas de borrado reintentables.
- [ ] Borrar sesión segura, borradores y memoria compartida al cerrar sesión según el contrato.
- [ ] Resolver desconexión, sesión vencida y respuestas tardías sin repetir acciones sensibles automáticamente.
- [ ] Definir retención, proveedor de correo final y operación del entorno de lanzamiento.

Cierre: ninguna operación ni recibo previo permite recuperar contenido ajeno después de salir; la eliminación completa puede verificarse y recuperarse ante fallos.

### MVP-07 · Piloto

- [ ] Completar el recorrido real desde acceso hasta primer brote y salida.
- [ ] Comprobar privacidad con una tercera cuenta y todas las vías de lectura expuestas.
- [ ] Cumplir accesibilidad, texto aumentado, áreas táctiles y movimiento reducido.
- [ ] Medir rendimiento y estabilidad en los dispositivos objetivo.
- [ ] Revisar comprensión del consentimiento, espera, aprobación, siembra y salida con personas de prueba.
- [ ] Preparar compilación, configuración y correo del entorno de piloto.
- [ ] Si iOS entra en el alcance, completar exportación y VoiceOver en dispositivo real.

Cierre del MVP: todos los criterios anteriores cuentan con evidencia; los errores y las limitaciones conocidas están documentados y no invalidan privacidad, consentimiento ni recuperación.

## Orden de trabajo acordado

| Prioridad | Próximo bloque | Resultado esperado |
| --- | --- | --- |
| 1 | Reingreso en emulador y gesto desde confirmación | Recuperar el vínculo existente sin crear otra invitación; la app permanece abierta. |
| 2 | Sesión segura y cierre de validación móvil | Reapertura, TalkBack completo y decisión del motor respaldados por pruebas. |
| 3 | Casos negativos del vínculo real | Tercera cuenta, cancelación, vencimiento y reconexión verificados. |
| 4 | MVP-03 | Primera selección privada y revelación bilateral reales. |
| 5 | MVP-04 → MVP-05 | Acuerdo aprobado, siembra única y primer brote. |
| 6 | MVP-06 → MVP-07 | Salida segura y piloto completo. |

La preparación de contratos o diseños puede avanzar en paralelo a una validación pendiente, pero no se marca cumplido el objetivo dependiente sin su evidencia. QR nativo y enlaces públicos continúan pendientes: el código manual permite probar el vínculo; incorporar esos medios antes del piloto si se mantienen en su alcance.

## Cómo mantener este documento

Al finalizar cada bloque:

1. Revisar los criterios del objetivo y marcar únicamente los comprobados.
2. Actualizar estado, resultado disponible y próximos pasos.
3. Registrar fecha, entorno, prueba y enlace a evidencia; indicar si sólo es local o de demostración.
4. Anotar limitaciones y decisiones pendientes, sin guardar códigos OTP, contraseñas, JWT ni claves secretas.
5. Actualizar la guía técnica correspondiente y agregar una entrada al historial.

Para iniciar un bloque, tomar la primera prioridad pendiente, consultar su contrato y definir qué prueba demostrará el resultado. Un objetivo «Cumplido» se modifica cuando hay un cambio de requisito o una regresión, no porque comience una etapa nueva.

## Historial de avance

| Fecha | Objetivos | Avance y evidencia | Pendiente |
| --- | --- | --- | --- |
| 2026-10-02 | MVP-00 | Base exportada e instalada; herramientas reproducibles. | Aprobación del motor para lanzamiento pertenece a MVP-01. |
| 2026-10-02 | MVP-01 | Teclado/gesto comprobados parcialmente; controles TalkBack en copia 4.8 dev 7. | Recorrido accesible completo, mediciones y gesto autenticado. |
| 2026-10-02 | MVP-02 | OTP y vínculo real confirmados en Samsung y escritorio; pruebas del servidor local y rechazo anónimo real. | Recuperación, sesión segura y casos negativos reales. |
| 2026-10-03 | Seguimiento | Se crea este documento como referencia general de objetivos y cierre. | Continuar por la prioridad 1; no se ejecutaron pruebas nuevas al crear el documento. |
| 2026-10-04 | MVP-01 / MVP-02 | Refinamiento autónomo: 1347 pruebas de código y 33 del recorrido visual en escritorio sin fallos; APK actualizado generado. | Emulador con 4 fallos visuales; Samsung bloqueado; sesión segura, reapertura real y TalkBack completo pendientes. |
| 2026-10-04 | MVP-01 | Samsung desbloqueado: 33 comprobaciones sin fallos; gesto en jardín demo y brote mediante toque. Corrección de ancho al 200%, con 1349 pruebas de código sin fallos. | Gesto autenticado, sesión segura, reapertura real y TalkBack completo pendientes; fallos del emulador aún por resolver. |
| 2026-11-06 | MVP-01 / MVP-02 | Keystore y reaperturas con sesión de prueba en Android emulado. PostgreSQL local y recorrido bilateral local aprobados. TalkBack activo sin controles con nombre. | Supabase restaurado. Casos negativos aprobados en SQL alojado con rollback. APK conectado visible con GPU del host. Reingreso, OTP sintético y reconexión aprobados contra Supabase desde Android emulado. Pendientes la cuenta principal histórica y la accesibilidad. Prueba física diferida por preferencia del usuario. |
| 2026-11-17 | MVP-03 | 9 de 9 casos aprobados en Android emulado con backend local y sesiones sintéticas. Evidencia por caso en [M3](MVP_03.md). | MVP-04, acuerdo y receta compartida. |
| 2026-11-17 | MVP-04 | Ocho casos aprobados en Android emulado con el backend local, incluidas edición, aprobación concurrente y reapertura. | Aplicar y validar M4 en Supabase de desarrollo. La siembra corresponde a MVP-05. |
| 2026-11-17 | MVP-05 | Ocho casos aprobados en Android emulado con backend local. Confirmaciones concurrentes, un cultivo, un brote y presentación individual verificados. | Aplicar y validar M4 y M5 en Supabase de desarrollo. La desvinculación y eliminación corresponden a MVP-06. |

## Documentos de referencia

- [Plan de desarrollo y escena 3D](../entregables/AppParejas_Escena_3D_y_plan_de_desarrollo_V1.md): entregas originales, presupuesto móvil y criterio de V1 completa.
- [Arquitectura técnica](../entregables/AppParejas_Arquitectura_tecnica_V1.md): capas, sesión y límites del MVP.
- [Datos, sincronización y privacidad](../entregables/AppParejas_Datos_sincronizacion_y_privacidad_V1.md): invariantes, consentimientos, revisiones y contratos de servidor.
- [Cuentas y validación](CUENTAS_Y_VALIDACION.md): implementación real y evidencia actual.
- [Accesibilidad Android](ACCESIBILIDAD_ANDROID.md): prueba del motor alternativo y pendientes.
- [Autoexploración](AUTOEXPLORACION.md): correcciones y pruebas autónomas del 4 de octubre.
- [Primera apertura de demostración](PRIMERA_APERTURA.md) y [fase inicial](FASE_INIT.md): registro previo; sus pendientes históricos se contrastan con este seguimiento y la guía de cuentas.
