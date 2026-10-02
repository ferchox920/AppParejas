# Arquitectura técnica de AppParejas V1
Aplicación móvil con jardín tridimensional
Versión 1.0 · 2 de octubre de 2026 · Propuesta para desarrollo

## 1 Propósito y decisión de arquitectura
Proponemos desarrollar la V1 completa en Godot 4 con GDScript tipado, una interfaz de controles del motor y una escena 3D acotada para la semilla y el brote. Supabase aportaría identidad y persistencia, con PostgreSQL como autoridad para las decisiones bilaterales. Blender se usaría para preparar modelos exportados como GLB.

Esta propuesta parte de un equipo sin experiencia previa en Godot ni Unity, una escena con cámara y profundidad y un producto centrado en formularios y decisiones asincrónicas. Godot es una recomendación de trabajo; la elección definitiva del motor no queda aprobada por este documento. Antes de comprometer el desarrollo, debemos demostrar exportación móvil, lectura accesible de formularios y comunicación con el servidor en dispositivos reales.

La arquitectura mantiene las reglas de la Especificación funcional V1 y del Mapa del sistema de cualidades. Este documento define responsabilidades y límites técnicos; los otros dos nuevos documentos detallan datos, sincronización, recursos 3D y entregas.

### Resultado que debe sostener
Cada persona participa desde su cuenta. El servidor revela las elecciones sólo cuando ambas consienten, conserva las revisiones y crea una única siembra. Los dispositivos dibujan una misma receta visual y recuperan el recorrido al volver. La V1 termina con el primer brote de la misma planta; no incluye monedas, actividades, pagos, chat ni notificaciones automáticas.

## 2 Tecnologías propuestas
| Área | Elección propuesta | Función |
| --- | --- | --- |
| Aplicación | Godot 4 estable y GDScript tipado | Pantallas, navegación, cámara y renderizado |
| Interfaz | Control, Containers y Theme | Formularios adaptables y componentes de Figma |
| Recursos 3D | Blender y glTF 2.0 en GLB | Semilla, tierra, tallo y dos hojas |
| Identidad | Supabase Auth | Acceso individual y sesiones |
| Datos | PostgreSQL en Supabase | Vínculo, revisiones, acuerdos y cultivo |
| Operaciones | Funciones SQL llamadas por RPC | Transiciones atómicas y autorización |
| Cliente de red | Adaptador HTTPS con HTTPRequest | Integración de Godot con la API |
| Versionado | Git y migraciones SQL | Código, catálogo, recursos y esquema |

Fijar versiones exactas del motor, sus plantillas de exportación y las herramientas cuando se inicie el repositorio. No usar automáticamente una versión nueva en cada compilación. La comunicación HTTPS es viable con HTTPRequest de Godot; nuestro adaptador será una implementación propia que deberá probar autenticación, errores y reintentos. Referencia técnica: [G1].

<!-- pagebreak -->
## 3 Capas y responsabilidades
La app tendrá cuatro capas. La interfaz presenta información; los casos de uso coordinan acciones; el dominio representa reglas y estados; los adaptadores resuelven red, archivos y servicios del dispositivo. La base de datos aplica las mismas invariantes relevantes para que un cliente alterado no pueda saltarse el consentimiento.

| Capa | Elementos | Responsabilidad |
| --- | --- | --- |
| Presentación | Pantallas, componentes y GardenView | Mostrar estado y enviar intenciones |
| Aplicación | Compartir, aprobar, sembrar y salir | Coordinar confirmación y recuperación |
| Dominio | PairState, Agreement y VisualRecipe | Representar modelos sin depender de nodos |
| Infraestructura | AuthGateway, PairRepository y DraftStore | Acceso a red y persistencia local |
| Servidor | Esquema, permisos y RPC | Validar identidad, versiones y transacciones |

Los nombres anteriores orientan la organización del código; no implican que esas clases ya existan. Evitar que un botón ejecute SQL, que un material acceda a la cuenta o que una escena gráfica decida si el vínculo está activo.

### Recorrido de una acción
Al pulsar Compartir, la pantalla valida el rango para dar una respuesta inmediata. El caso de uso envía los IDs elegidos, la versión que vio y una clave de idempotencia. El servidor comprueba permisos y estado, guarda la acción y responde con una vista autorizada del recorrido. La app reemplaza su estado con esa respuesta. La animación y la navegación ocurren después de la confirmación.

### Organización inicial del repositorio
- app/project.godot y app/export_presets.cfg: configuración reproducible sin secretos de firma.
- app/src/ui y app/scenes/ui: componentes y pantallas.
- app/src/application y app/src/domain: casos de uso y modelos.
- app/src/infrastructure: red, sesión, borradores y preferencias.
- app/scenes/garden y app/assets: escena y recursos empaquetados.
- backend/supabase/migrations y backend/tests: esquema, RPC y pruebas de permisos.
- content: catálogo, textos, reglas de receta y manifiestos de versiones.
- art/source: originales de Blender y documentación de exportación.
- docs y tests: decisiones, contratos y verificaciones del cliente.

Conservar el proyecto como un repositorio único con módulos claros. No hace falta iniciar microservicios, un servidor gráfico o un sistema de multijugador en tiempo real. Los binarios grandes de arte pueden usar Git LFS si su tamaño lo justifica.

<!-- pagebreak -->
## 4 Aplicación móvil y representación gráfica
Proponemos una app vertical. El marco de Figma de 390 × 844 es una referencia de composición, no una resolución obligatoria. Implementar márgenes, áreas seguras, contenedores, desplazamiento y altura de texto variable. Probar un ancho lógico de 360 y otro de 430, además del diseño de referencia.

Godot ofrece contenedores para distribuir controles y SubViewportContainer para mostrar un viewport dentro de la interfaz [G2]. Para AppParejas proponemos un GardenView que contenga la escena 3D en un SubViewport y controles de interfaz alrededor. Así, la resolución del jardín puede ajustarse sin reducir la legibilidad del texto.

La cámara y los materiales son locales. No se transmiten imágenes entre integrantes ni se sincronizan movimientos de cámara. El servidor entrega la receta y la etapa; cada cliente las representa. Ambos deben conservar identidad visual, aunque iluminación o antialiasing difieran ligeramente según el dispositivo.

### Elección del renderizador
Godot distingue Mobile, adecuado para hardware móvil más reciente, y Compatibility, orientado a una cobertura más amplia y escenas menos exigentes [G3]. Proponemos comenzar la prueba técnica con Compatibility por la sencillez del jardín y contrastarlo con Mobile en el mismo teléfono. Elegir con mediciones de tiempo de cuadro, memoria, consumo sostenido y calidad. No diseñar efectos que obliguen a Forward+.

### Estado local y estado compartido
Guardar localmente preferencias de movimiento, tamaño de texto y borradores de la persona autenticada. Mantener en memoria la vista compartida mientras la app está activa. En la V1 inicial no persistir en disco selecciones ajenas ni sus textos compartidos: al reabrir, consultarlos después de validar el acceso.

Esta decisión permite revocar el acceso en el servidor sin mantener una copia compartida accesible sin conexión. Sin red se muestra el borrador propio y un aviso para recuperar el espacio compartido. No se promete retirar lo que alguien ya vio, fotografió o guardó por su cuenta.

### Sesión y capacidades del dispositivo
Proponemos acceso por correo con código de un solo uso, sujeto a configurar la entrega de correo de autenticación. Las invitaciones se abrirían por enlace verificado cuando esté implementado; ofrecer además ingresar un código de invitación para no depender del enlace profundo en la primera prueba.

La persistencia de sesiones necesita un adaptador a Android Keystore y a Keychain en iOS, con revisión del mecanismo concreto. No considerar user:// un almacén secreto ni ocultar credenciales en recursos del motor. Si este adaptador aún no está disponible, el prototipo usa sesión sólo en memoria y vuelve a pedir acceso al abrir.

<!-- pagebreak -->
## 5 Servidor y comunicación
Proponemos utilizar la API de Supabase mediante HTTPS y un conjunto pequeño de funciones PostgreSQL. Las operaciones bilaterales viven en transacciones de la base de datos. Reservar Edge Functions para tareas con privilegios administrativos, por ejemplo coordinar la eliminación de la cuenta de Auth, o para integraciones externas futuras.

El adaptador de Godot adjunta la clave publicable en apikey y el JWT vigente de la persona en Authorization Bearer. Una clave publicable identifica la aplicación; no sustituye la autenticación ni los permisos del usuario. Las claves secretas y service_role se conservan exclusivamente en el servidor [S1].

### Política de sincronización
La primera versión puede consultar el estado al abrir, volver del segundo plano y terminar una operación. En una pantalla de espera activa proponemos una consulta cada 15 segundos, con retroceso progresivo si hay errores. Detener consultas en segundo plano. El intervalo es un parámetro de producto y consumo, no una promesa de actualización instantánea.

Realtime queda como optimización posterior. Si se agrega, el evento sólo avisa que cambió el recorrido y provoca una consulta autorizada. No enviar las cualidades privadas en mensajes de cambio. No requiere simultaneidad para aprobar o sembrar.

### Errores y observabilidad
El contrato distingue versión obsoleta, sesión vencida, operación no permitida, validación y servicio no disponible. Traducirlos a mensajes de acción: revisar, volver a ingresar o reintentar. Registrar identificador de operación, tipo de error y tiempos, sin IDs de cualidades, nombres, intenciones, enlaces, JWT ni cuerpos completos de solicitudes.

Las métricas de producto son opcionales y separadas de los registros operativos. No crear un indicador de compatibilidad, cuidado individual o valor de una relación. Mantener contenido íntimo fuera de herramientas de seguimiento de errores.

## 6 Entornos y entregas
Crear entornos de desarrollo, prueba y producción con datos separados. La app conoce la URL y la clave publicable del entorno; nunca cambia silenciosamente de uno a otro. Las migraciones, catálogo y funciones se versionan y se prueban antes de aplicar a producción.

Una compilación identificará versión de app, motor, catálogo, receta, recursos y contrato de API. Usar datos ficticios en pruebas. Guardar claves de firma y credenciales administrativas fuera de Git. Medir costos por entorno, almacenamiento y consultas antes de comprometer una tarifa de operación; este documento no fija precios.

<!-- pagebreak -->
## 7 Decisiones pendientes y criterios de elección
| Decisión | Propuesta inicial | Evidencia para confirmarla |
| --- | --- | --- |
| Motor | Godot con GDScript | App exportada, formulario usable y jardín estable |
| Renderizador | Compatibility como primera prueba | Comparación con Mobile en teléfonos objetivo |
| Plataformas | Android primero e iOS previsto | Prueba temprana de exportación en ambas |
| Acceso | Código por correo | Recepción, recuperación y sesión probadas |
| Sesión persistente | Almacén seguro del sistema | Adaptador y borrado al cerrar sesión verificados |
| Equipos mínimos | Definir después de medir | Matriz real de memoria, GPU y sistema operativo |

Se puede desarrollar y probar Android desde Windows. La documentación de Godot exige macOS con Xcode para exportar a iOS [G4]. Debemos asegurar acceso a ese entorno al comienzo si iOS forma parte de la primera entrega. Para Android, preparar JDK y SDK según la documentación de la versión fijada [G5].

La prueba técnica debe permitir cambiar de motor antes de construir todo el producto si falla una capacidad decisiva. Un resultado insuficiente en accesibilidad, integración nativa o mantenimiento justificaría volver a comparar Godot y Unity con el mismo recorrido y dispositivos. No migrar sólo por una preferencia estética o por una medición aislada.

### Criterios de aceptación de la arquitectura
- Una app instalada muestra formularios y jardín sin requerir otro framework de interfaz.
- Dos cuentas distintas consultan el estado y una tercera no accede al vínculo.
- La elección ajena no viaja al cliente antes de la revelación autorizada.
- Un reintento no duplica siembra; una versión obsoleta nunca se aprueba.
- La etapa y la receta se recuperan del servidor después de reinstalar o cambiar de equipo.
- La V1 se puede operar con texto aumentado y una alternativa a gestos y animaciones.
- Versiones y configuración permiten reproducir una compilación sin secretos en el repositorio.

## 8 Fuentes y documentos relacionados
Documentación consultada el 2 de octubre de 2026. Las decisiones propias se expresan como propuestas; las fuentes respaldan capacidades y requisitos de las herramientas.
- G1 Godot HTTPRequest: https://docs.godotengine.org/en/stable/tutorials/networking/http_request_class.html
- G2 Godot Containers: https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html
- G3 Godot Renderers: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- G4 Godot Exporting for iOS: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html
- G5 Godot Exporting for Android: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
- S1 Supabase API keys: https://supabase.com/docs/guides/getting-started/api-keys
- Base del producto: Especificación funcional V1 y Mapa del sistema de cualidades.
