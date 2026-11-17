# MVP-07 · Preparación del piloto Android

## Ensayo del 17 de noviembre de 2026

Se ejecutaron 15 comprobaciones en `AppParejas_API_35` con Android 15, Godot 4.7.2, Compatibility y GPU del anfitrión. El APK de pruebas cargó las escenas de la app y sus servicios contra AppParejas-desarrollo. Se crearon dos sesiones sintéticas independientes y una tercera cuenta para comprobar aislamiento.

- Dos participantes crearon y aceptaron una invitación real. El primer consentimiento mantuvo privadas las elecciones y la receta. El segundo reveló las elecciones, habilitó el acuerdo y permitió que ambos aprobaran y sembraran el mismo cultivo.
- Se ajustó el vencimiento únicamente del cultivo sintético. Los dos clientes recuperaron el mismo brote al reabrir. Un integrante salió y el otro perdió acceso al actualizar.
- La tercera cuenta recibió `pair_unavailable`. En el catálogo de PostgreSQL ambos roles de cliente carecían de acceso al esquema privado, todas sus tablas tenían RLS y no había tablas o vistas públicas consultables por esos roles.
- Las sesiones de la prueba se obtuvieron con contraseña y se cargaron en Keystore. Queda pendiente repetir con correo y código de acceso del piloto. El trabajador de eliminación procesó las tres cuentas sintéticas y se confirmó su ausencia en Auth.

El APK base firmado de depuración quedó instalado como `org.appparejas.preview`. Los registros, la huella SHA-256 y el APK de prueba local están en `.artifacts/m7-pilot/`. El artefacto de depuración apunta al entorno de desarrollo. Para distribuir a participantes se requiere preparar la compilación firmada del piloto.

## Accesibilidad y fluidez

Con TalkBack activo, la bienvenida del APK base presentó siete nodos nativos sin texto ni descripción. Se restauraron los ajustes del emulador al terminar. La prueba deja abierto el criterio de accesibilidad. La siguiente comparación requiere compilar la app con una versión de Godot que incluya AccessKit para Android y verificar en el lector los controles, el orden de foco, el teclado, los errores y el texto al 200 %.

Durante un minuto en el jardín con brote se registraron 3.600 cuadros y un p95 de 19,67 ms. Una muestra de memoria arrojó aproximadamente 170 MiB de PSS. El criterio del plan técnico pide diez minutos en el dispositivo objetivo, incluida la estabilidad y temperatura. La muestra en emulador sirve como referencia inicial.

Evidencia local en `.artifacts/m7-pilot/`. Los archivos `emulator-flow.log`, `emulator-sprout.log`, `garden-memory.txt`, `talkback-final.xml` y `brote.png` contienen los resultados.

## Recuperación y respaldo

En PostgreSQL 17 se generó un volcado de una base sintética con las migraciones vigentes y se restauró en otra base del entorno aislado. Pasaron las suites de cultivo, eliminación y retención sobre la base restaurada. Sigue pendiente el ensayo con una copia equivalente al entorno alojado y con bajas posteriores al respaldo, junto con la elección del destino, el acceso y el plazo de conservación.

Supabase describe dos opciones para este proyecto. El plan Free admite exportaciones lógicas con la CLI y requiere un destino externo para conservarlas. El plan Pro ofrece respaldos diarios administrados con acceso a los últimos siete días. Cada opción debe probar la restauración en un entorno aislado y reconciliar las bajas y desvinculaciones antes de habilitar el acceso. [Respaldos en Supabase](https://supabase.com/docs/guides/platform/backups)

## Sesiones con participantes

Con consentimiento de las personas de prueba y datos ficticios, pedir a dos participantes que completen estos pasos sin explicaciones durante el recorrido. Registrar la pantalla, el resultado y lo que esperaban que ocurriera, sin capturar códigos ni elecciones personales.

| Momento | Señal a observar |
| --- | --- |
| Acceso e invitación | Ambos entienden a qué cuenta acceden y quién envió el código. |
| Selección, espera y revelación | Cada uno puede explicar cuándo se muestran sus elecciones. |
| Acuerdo y siembra | Distinguen aprobar la versión de confirmar la siembra. |
| Brote y salida | Pueden recuperar el jardín y anticipar qué acceso se pierde al desvincular. |

Quedan por confirmar participantes y fecha, rendimiento físico y la cobertura de respaldo. Gmail y la retención acordada de treinta días siguen documentados en [MVP-06](MVP_06.md).
