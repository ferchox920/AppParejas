# MVP-07 · Preparación del piloto Android

## Ensayo del 17 de noviembre de 2026

Se ejecutaron 15 comprobaciones en `AppParejas_API_35` con Android 15, Godot 4.7.2, Compatibility y GPU del anfitrión. El APK de pruebas cargó las escenas de la app y sus servicios contra AppParejas-desarrollo. Se crearon dos sesiones sintéticas independientes y una tercera cuenta para comprobar aislamiento.

- Dos participantes crearon y aceptaron una invitación real. El primer consentimiento mantuvo privadas las elecciones y la receta. El segundo reveló las elecciones, habilitó el acuerdo y permitió que ambos aprobaran y sembraran el mismo cultivo.
- Se ajustó el vencimiento únicamente del cultivo sintético. Los dos clientes recuperaron el mismo brote al reabrir. Un integrante salió y el otro perdió acceso al actualizar.
- La tercera cuenta recibió `pair_unavailable`. En el catálogo de PostgreSQL ambos roles de cliente carecían de acceso al esquema privado, todas sus tablas tenían RLS y no había tablas o vistas públicas consultables por esos roles.
- Las sesiones de este primer ensayo se obtuvieron con contraseña y se cargaron en Keystore. El trabajador de eliminación procesó las tres cuentas sintéticas y se confirmó su ausencia en Auth.

El APK base firmado de depuración quedó instalado como `org.appparejas.preview`. Los registros, la huella SHA-256 y el APK de prueba local están en `.artifacts/m7-pilot/`. El artefacto de depuración apunta al entorno de desarrollo. Para distribuir a participantes se requiere preparar la compilación firmada del piloto.

## Accesibilidad y fluidez

Con TalkBack activo, la bienvenida del APK base presentó siete nodos nativos sin texto ni descripción. Se restauraron los ajustes del emulador al terminar. La prueba deja abierto el criterio de accesibilidad. La comparación con una versión que incluye AccessKit se registra más abajo.

Durante un minuto en el jardín con brote se registraron 3.600 cuadros y un p95 de 19,67 ms. Una muestra de memoria arrojó aproximadamente 170 MiB de PSS. La medición física de diez minutos se registra más abajo.

Evidencia local en `.artifacts/m7-pilot/`. Los archivos `emulator-flow.log`, `emulator-sprout.log`, `garden-memory.txt`, `talkback-final.xml` y `brote.png` contienen los resultados.

## Validación adicional del 17 de noviembre

### Galaxy S25 Ultra

En Android 17 con Adreno 830, Godot 4.7.2 y Compatibility, el APK de prueba aprobó las 15 comprobaciones del recorrido con las cuentas sintéticas en Supabase de desarrollo. Midió el jardín con brote en primer plano durante 600,02 segundos, con el teléfono conectado por USB.

| Medición | Resultado |
| --- | --- |
| Fluidez | 72.092 cuadros. p95 de 8,80 ms frente a una meta de 33 ms. p99 de 9,23 ms y máximo de 21,08 ms. |
| Temperatura | Batería de 32,5 a 33,2 °C. Estado térmico de Android 0 en todas las muestras. |
| Memoria | De 271 a 280 MiB PSS durante el jardín, por encima de la meta inicial de 250 MB. La compilación de prueba abrió dos sesiones al inicio. Hace falta medir la memoria del APK de un solo cliente. |
| Estabilidad | Sin cierres durante la medición. Se completaron la salida y la revocación en el segundo cliente después del ensayo. |

La carga por USB impide estimar el consumo en batería con esta corrida. Se retiró el APK temporal del S25 y se restauró su ajuste de pantalla. Registros en `.artifacts/m7-s25/`.

El trabajador de eliminación procesó las cuatro cuentas temporales de la segunda validación. Se confirmó que ya no figuran en Auth.

### Acceso, privacidad y accesibilidad

- **Gmail.** En una compilación aislada de Godot 4.8 beta 3, un alias de prueba recibió el OTP del SMTP de desarrollo. El emulador mostró el error ante un código incorrecto, aceptó el correcto y creó una invitación. Después de cerrar el proceso se recuperó la invitación pendiente sin pedir otro código. Supabase rechazó reutilizar el OTP. La caducidad tiene cobertura con Auth local.
- **Privacidad.** La cuenta ajena no recibió datos del vínculo por `get_connection_state` y el servidor rechazó sus llamadas a las nueve RPC que toman el ID del vínculo. También rechazó las mismas llamadas anónimas y las lecturas directas de las tablas privadas comprobadas en REST. El jardín y el acuerdo permanecieron iguales después de los intentos.
- **TalkBack.** Con la misma beta, el árbol nativo del emulador expuso botones de bienvenida, campos y consentimiento del formulario, el mensaje de código inválido con sus acciones y la invitación. Aún se debe comprobar el foco y la operación del recorrido bilateral con el lector, incluido el desplazamiento.
- **Tamaño de texto.** La opción de la app permite pasar del 150 % al 200 % y volver al texto normal. El emulador guardó la selección del 200 % y TalkBack siguió exponiendo los botones de bienvenida. Las pruebas de disposición cubrieron doce pantallas de primera apertura a 360 y 390 px. El formulario también informa que Android puede mantener la sesión al reabrir la app.

## Recuperación y respaldo

En PostgreSQL 17 se generó un volcado de una base sintética con las migraciones vigentes y se restauró en otra base del entorno aislado. Pasaron las suites de cultivo, eliminación y retención sobre la base restaurada. En un segundo ensayo sintético, el respaldo contenía dos jardines activos. Se repitieron en la base restaurada una baja y una desvinculación que habían ocurrido después de la copia. La cuenta eliminada y los integrantes que perdieron acceso siguieron bloqueados. Sigue pendiente probar una copia equivalente al entorno alojado y definir el destino, el acceso y el plazo de conservación.

Supabase describe dos opciones para este proyecto. El plan Free admite exportaciones lógicas con la CLI y requiere un destino externo para conservarlas. El plan Pro ofrece respaldos diarios administrados con acceso a los últimos siete días. Cada opción debe probar la restauración en un entorno aislado y reconciliar las bajas y desvinculaciones antes de habilitar el acceso. [Respaldos en Supabase](https://supabase.com/docs/guides/platform/backups)

## Sesiones con participantes

Con consentimiento de las personas de prueba y datos ficticios, pedir a dos participantes que completen estos pasos sin explicaciones durante el recorrido. Registrar la pantalla, el resultado y lo que esperaban que ocurriera, sin capturar códigos ni elecciones personales.

| Momento | Señal a observar |
| --- | --- |
| Acceso e invitación | Ambos entienden a qué cuenta acceden y quién envió el código. |
| Selección, espera y revelación | Cada uno puede explicar cuándo se muestran sus elecciones. |
| Acuerdo y siembra | Distinguen aprobar la versión de confirmar la siembra. |
| Brote y salida | Pueden recuperar el jardín y anticipar qué acceso se pierde al desvincular. |

Quedan pendientes la compilación firmada del piloto, los participantes y la fecha, la memoria del APK de un solo cliente, la validación de TalkBack en un teléfono y la cobertura de respaldo. Gmail y la retención acordada de treinta días siguen documentados en [MVP-06](MVP_06.md).
