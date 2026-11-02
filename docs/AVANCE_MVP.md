# Avance general de AppParejas

Última actualización: **4 de octubre de 2026**. Última evidencia de ejecución: **4 de octubre de 2026**.

Este es el documento principal para decidir qué desarrollar, revisar los objetivos cumplidos y registrar el avance del MVP. Las guías técnicas vinculadas conservan los detalles y las pruebas. Actualizar este documento al terminar cada bloque de trabajo.

## Objetivo del MVP

Dos personas, cada una desde su cuenta, crean un vínculo, eligen entre 3 y 5 cualidades, consienten compartirlas, revisan una semilla común, aprueban la misma versión del acuerdo, confirman la siembra y recuperan el primer brote. El servidor protege la privacidad, los consentimientos y las transiciones. Cualquiera puede desvincularse.

La V1 termina con el primer brote. Quedan fuera chat, pagos, monedas, actividades, puntuaciones, rachas y notificaciones automáticas. La planta no penaliza la ausencia.

Android es la plataforma en desarrollo y verificación, con Samsung y computadora como clientes de prueba. La inclusión de iOS en el primer lanzamiento sigue por confirmar; si se incluye, requiere entorno macOS/Xcode y validación con VoiceOver.

## Dónde estamos

Tenemos una aplicación instalable en Android, un catálogo y jardín de demostración, acceso real por código de correo y un vínculo bilateral confirmado contra Supabase. **Todavía no tenemos el recorrido completo del MVP:** las elecciones compartidas, el acuerdo, la siembra y el crecimiento reales están pendientes.

El trabajo inmediato es cerrar la validación móvil y la recuperación de cuentas. Después continúa la selección privada y la revelación con consentimiento bilateral.

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
| MVP-01 | Validación móvil y decisión del motor | En desarrollo | APK, HTTPS, teclado y navegación comprobados parcialmente; falta completar TalkBack, gestos autenticados y mediciones. |
| MVP-02 | Cuentas y vínculo bilateral real | Por validar | OTP e invitación aceptada en ambos clientes; falta recuperación tras reabrir y sesión persistente segura. |
| MVP-03 | Selección privada y revelación bilateral | Pendiente | Catálogo y selector disponibles en demo; falta persistencia y consentimiento real de ambas cuentas. |
| MVP-04 | Acuerdo y receta compartida | Pendiente | Mezcla visual local de prueba; faltan receta autorizada y aprobaciones por versión. |
| MVP-05 | Siembra única y primer brote | Pendiente | Semilla y brote visuales de demo; faltan transacción, tiempo de servidor e hito real. |
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
- [ ] Comprobar físicamente el gesto desde el vínculo real confirmado con el APK actualizado.
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
- [ ] Recuperar el mismo vínculo después de terminar el proceso y volver a entrar con un código nuevo.
- [ ] Integrar almacenamiento seguro de sesión, renovación y borrado al cerrar sesión; verificar la reapertura.
- [ ] Comprobar en el servicio real que una tercera cuenta no accede al vínculo ajeno.
- [ ] Completar pruebas reales de invitación cancelada/vencida, acceso rechazado y reconexión sin confirmaciones falsas.

La sesión actual vive en memoria: terminar el proceso requiere otro acceso. La recuperación del vínculo y la permanencia de la sesión son criterios diferentes. El alias de Gmail sirve como segunda cuenta de prueba, aunque ambos correos lleguen a una sola bandeja.

El código solicitado el 2 de octubre no se considera vigente ni se reutiliza como evidencia. Para retomar la prueba, comprobar primero el estado del cliente y solicitar un código nuevo si corresponde, una sola vez.

Evidencia: [cuentas y validación](CUENTAS_Y_VALIDACION.md), `backend/supabase/migrations/202610020001_connection.sql`, `tools/Test-Backend.ps1` y `app/tests/account_connection_tests.gd`. La migración ya aplicada no se vuelve a ejecutar; los cambios siguientes se agregan como nuevas migraciones.

### MVP-03 · Selección privada y revelación

- [ ] Guardar una selección propia de 3 a 5 IDs únicos del catálogo vigente, aislada por cuenta y vínculo.
- [ ] Mantener las elecciones privadas hasta que ambos consientan compartir sus revisiones vigentes.
- [ ] Mostrar espera y revelar sólo la proyección autorizada por el servidor.
- [ ] Recuperar el borrador propio y manejar cambios concurrentes y pérdida de conexión.
- [ ] Al reabrir elecciones, retirar los consentimientos y aprobaciones correspondientes según el contrato.
- [ ] Probar con dos integrantes y una tercera cuenta, incluyendo acceso directo por API.

Cierre: las dos cuentas comparten y recuperan elecciones reales sin filtrarlas antes del consentimiento. El selector local y la segunda elección ficticia no cumplen este objetivo.

### MVP-04 · Acuerdo y receta

- [ ] Generar en el servidor una receta determinista que conserve los aportes equivalentes de ambos integrantes.
- [ ] Representar la misma identidad de semilla en ambos clientes, con explicación textual.
- [ ] Guardar nombre, intención y versión del acuerdo.
- [ ] Registrar dos aprobaciones explícitas sobre la misma versión.
- [ ] Invalidar aprobaciones afectadas al editar y rechazar versiones antiguas.

Cierre: ambos ven la misma receta y aprueban la misma versión; una aprobación antigua o de una cuenta externa se rechaza. El arte final debe respetar el mapa de cualidades, accesibilidad y presupuesto móvil.

### MVP-05 · Siembra y primer brote

- [ ] Registrar confirmaciones de siembra explícitas de ambas personas sobre el acuerdo vigente.
- [ ] Crear un único cultivo mediante una transacción del servidor, incluso con reintentos y concurrencia.
- [ ] Guardar receta y acuerdo inmutables después de sembrar.
- [ ] Determinar el primer brote con tiempo de servidor: 168 horas desde la siembra.
- [ ] Recuperar jardín y etapa en ambos clientes sin depender del reloj del teléfono.
- [ ] Registrar por persona la presentación del hito, sin modificar el crecimiento.

Cierre: una siembra real y el mismo primer brote se recuperan entre clientes. Probar el plazo con un reloj o entorno de prueba controlado; no agregar una aceleración pública del cultivo.

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
| 1 | Reingreso en Samsung y gesto desde confirmación | Recuperar el vínculo existente sin crear otra invitación; la app permanece abierta. |
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

## Documentos de referencia

- [Plan de desarrollo y escena 3D](../entregables/AppParejas_Escena_3D_y_plan_de_desarrollo_V1.md): entregas originales, presupuesto móvil y criterio de V1 completa.
- [Arquitectura técnica](../entregables/AppParejas_Arquitectura_tecnica_V1.md): capas, sesión y límites del MVP.
- [Datos, sincronización y privacidad](../entregables/AppParejas_Datos_sincronizacion_y_privacidad_V1.md): invariantes, consentimientos, revisiones y contratos de servidor.
- [Cuentas y validación](CUENTAS_Y_VALIDACION.md): implementación real y evidencia actual.
- [Accesibilidad Android](ACCESIBILIDAD_ANDROID.md): prueba del motor alternativo y pendientes.
- [Autoexploración](AUTOEXPLORACION.md): correcciones y pruebas autónomas del 4 de octubre.
- [Primera apertura de demostración](PRIMERA_APERTURA.md) y [fase inicial](FASE_INIT.md): registro previo; sus pendientes históricos se contrastan con este seguimiento y la guía de cuentas.
