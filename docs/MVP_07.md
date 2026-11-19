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
- **TalkBack.** Con la misma beta, el árbol nativo del emulador expuso botones de bienvenida, campos y consentimiento del formulario, el mensaje de código inválido con sus acciones y la invitación. La prueba posterior comprobó en el emulador 15 pantallas al 200 %, desplazamiento y activación de acciones sobre datos simulados. La operación bilateral con TalkBack en el teléfono queda pendiente. [Evidencia de accesibilidad](ACCESIBILIDAD_ANDROID.md)
- **Tamaño de texto.** La opción de la app permite pasar del 150 % al 200 % y volver al texto normal. El emulador guardó la selección del 200 % y TalkBack siguió exponiendo los botones de bienvenida. Las pruebas de disposición cubrieron doce pantallas de primera apertura a 360 y 390 px. El formulario también informa que Android puede mantener la sesión al reabrir la app.

## Validación del 18 de noviembre

Con TalkBack activo, texto al 200 % y Godot 4.8 beta 3, dos cuentas sintéticas recorrieron el vínculo contra el backend de desarrollo. Se confirmaron los dos consentimientos de revelación, las aprobaciones y confirmaciones bilaterales, el brote único y la revocación de acceso tras la salida unilateral. [Resultados de accesibilidad](ACCESIBILIDAD_ANDROID.md)

### Candidata Android firmada

Se exportó el APK de release `AppParejas-piloto-candidato.apk` con Godot 4.8 beta 3, firma local de pruebas, soporte para ARM64 y x86_64 e identificador `org.appparejas.pilotcandidate`. El proceso rechazó una URL distinta de la configurada antes de exportar.

En Android 15 emulado con TalkBack activo, la candidata mostró el aviso de AppParejas-desarrollo. El formulario envió un código real por Gmail. La app rechazó un código incorrecto, aceptó el correcto y abrió la invitación. Recuperó la sesión y la invitación después de cerrar el proceso y después de reinstalar el APK encima. La eliminación solicitada desde **Cuenta y vínculo** se confirmó en Auth.

El APK queda en `build/android/` y los registros de exportación, firma, OTP y reinstalación en `.artifacts/pilot-release/`. Falta instalar esta candidata en ARM64, operar el recorrido bilateral con TalkBack en el S25 Ultra y medir memoria, batería y temperatura con un solo cliente. [Compilación e instalación](ANDROID.md#compilar-la-candidata-del-piloto-en-linux)

## Renderizado del jardín bajo demanda

Con movimiento reducido, el visor solicita un cuadro al mostrar el jardín, cambiar la receta o la etapa, mover la cámara, cambiar el tamaño o volver a la app. Si se habilita el movimiento, el visor se actualiza mientras se usa su textura. El cambio se aplica al jardín compartido y a la demo.

La comparación se hizo en Android 15 emulado con una sola vista del cliente, un brote sintético y Godot 4.7.2 Compatibility. Cada tramo sostuvo 20 segundos de jardín en reposo. El contador mide las llamadas de dibujo de toda la app por cuadro. Se repitió la comparación invirtiendo el orden de los modos.

| Modo en reposo | Mediana de llamadas de dibujo por cuadro | p95 del intervalo entre cuadros |
| --- | ---: | ---: |
| Continuo | 19 | 19,22 a 19,36 ms |
| Bajo demanda | 14 | 19,00 a 19,47 ms |

El visor bajo demanda redujo el número de llamadas de dibujo. Los intervalos entre cuadros fueron similares y las muestras de memoria del emulador no mostraron una reducción consistente.

Pasaron nueve comprobaciones visuales, entre ellas el reposo del visor, el giro, el zoom, el restablecimiento de cámara, el cambio de etapa, la reaparición del visor y el movimiento opcional. Los registros quedan en `.artifacts/m7-render/`. Las mediciones de memoria, batería y temperatura del APK de un cliente en el S25 Ultra siguen pendientes.

## Recuperación y respaldo

En PostgreSQL 17 se generó un volcado de una base sintética con las migraciones vigentes y se restauró en otra base del entorno aislado. Pasaron las suites de cultivo, eliminación y retención sobre la base restaurada. En un segundo ensayo sintético, el respaldo contenía dos jardines activos. Se repitieron en la base restaurada una baja y una desvinculación que habían ocurrido después de la copia. La cuenta eliminada y los integrantes que perdieron acceso siguieron bloqueados. El 18 de noviembre pasó una restauración cifrada con las mismas versiones de PostgreSQL y Auth que desarrollo y datos ficticios. Quedó habilitada una carpeta privada de Drive para las copias. El procedimiento del piloto propone retener siete copias diarias. Falta generar la primera copia de desarrollo y comprobar la cobertura independiente de bajas y desvinculaciones. [Procedimiento de respaldo](RESPALDO_PILOTO.md)

Supabase describe dos opciones para este proyecto. El plan Free admite exportaciones lógicas con la CLI y requiere un destino externo para conservarlas. El plan Pro ofrece respaldos diarios administrados con acceso a los últimos siete días. Cada opción debe probar la restauración en un entorno aislado y reconciliar las bajas y desvinculaciones antes de habilitar el acceso. [Respaldos en Supabase](https://supabase.com/docs/guides/platform/backups)

## Sesiones con participantes

Con consentimiento de las personas de prueba y datos ficticios, pedir a dos participantes que completen estos pasos sin explicaciones durante el recorrido. Registrar la pantalla, el resultado y lo que esperaban que ocurriera, sin capturar códigos ni elecciones personales.

### Preparación de la distribución interna

1. Confirmar la versión de Godot con el recorrido físico con TalkBack. Registrar la versión exacta del motor, las plantillas y el renderizador de la compilación aprobada.
2. Acordar quién custodia el almacén y la credencial de firma del piloto. Usar la clave de distribución desde la primera instalación de los participantes para que puedan actualizar conservando sus datos. La candidata firmada con la clave de pruebas sirve para las validaciones internas.
3. Exportar el APK con la URL y la clave publicable del entorno aprobado. Registrar el identificador, la versión, la huella del APK y la huella del certificado obtenida con `apksigner verify --print-certs`. Comprobar instalación limpia, actualización con la misma firma y el aviso de entorno esperado. [Guía de compilación](ANDROID.md#compilar-la-candidata-del-piloto-en-linux)
4. Confirmar el primer respaldo de desarrollo y que la restauración cubre las bajas y desvinculaciones posteriores. [Procedimiento de respaldo](RESPALDO_PILOTO.md)
5. Acordar fecha y dos participantes, cada uno con una cuenta de prueba y un cliente Android. Usar Gmail para el acceso y compartir la invitación por código. Al terminar, solicitar el borrado de las cuentas de prueba y comprobar que el trabajador lo procese.

### Guion de la sesión

| Momento | Señal a observar |
| --- | --- |
| Acceso e invitación | Ambos entienden a qué cuenta acceden y quién envió el código. |
| Selección, espera y revelación | Cada uno puede explicar cuándo se muestran sus elecciones. |
| Acuerdo y siembra | Distinguen aprobar la versión de confirmar la siembra. |
| Brote y salida | Pueden recuperar el jardín y anticipar qué acceso se pierde al desvincular. |

Por paso, registrar si lo completaron de forma autónoma, con ayuda o si quedó bloqueado. Antes de revelar, confirmar que cada persona entiende qué ve su pareja. Tras la salida, comprobar desde el otro cliente que perdió acceso al jardín. Un fallo de privacidad, consentimiento, recuperación de sesión o revocación requiere corregir y repetir el paso afectado antes de ampliar el piloto.

Quedan pendientes la configuración y firma de distribución del piloto, los participantes y la fecha, las mediciones del APK de un solo cliente, la validación de TalkBack en un teléfono y la cobertura de respaldo. Gmail y la retención acordada de treinta días siguen documentados en [MVP-06](MVP_06.md).
