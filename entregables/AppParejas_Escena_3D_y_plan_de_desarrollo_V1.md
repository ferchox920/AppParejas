# Escena 3D de AppParejas V1
Semilla parametrizada y plan de desarrollo
Versión 1.0 · 2 de octubre de 2026 · Propuesta para desarrollo

## 1 Objetivo gráfico y alcance
La escena debe mostrar una semilla propia y su primer brote con profundidad, una cámara controlable y una leyenda comprensible. La identidad nace de las cualidades elegidas por ambas personas. No generamos un modelo o una imagen con inteligencia artificial cada vez: combinamos recursos y parámetros prediseñados.

La V1 propone una escena pequeña con tierra o recipiente, semilla, tallo corto y dos hojas. No incluye jardín abierto, estaciones, física de fluidos, plagas, marchitamiento, floración o reproducción. Las ilustraciones de Figma son referencias conceptuales; aún no son recursos 3D ni representan todas las combinaciones del catálogo.

La escena depende de la receta y etapa autorizadas por el servidor. Cámara, zoom y animación de descubrimiento son preferencias locales. Ninguna cualidad modifica el plazo de 168 horas, la salud de la planta o el derecho a participar.

## 2 Traducción de Figma a Godot
| Elemento de diseño | Implementación propuesta | Verificación |
| --- | --- | --- |
| Botones campos y tarjetas | Control, Theme y escenas reutilizables | Texto variable y áreas táctiles |
| Colores tipografía y espaciado | Theme y constantes de diseño versionadas | Comparación con pantallas de referencia |
| Imagen de semilla o brote | GardenView con SubViewport y Node3D | Encuadre y leyenda en móvil |
| Abrir significado | Panel textual de motivos y cualidades | Funciona sin depender del color o del 3D |
| Movimiento reducido | Estado visual final y transiciones simples | Sin balanceo ni giro automático |
| Ajustes y regreso al jardín | Navegación con estado real del servidor | El brote permanece al volver |

No exportar cada pantalla de Figma como una imagen ni copiar posiciones absolutas de todos los textos. Usar distribución adaptable, listas desplazables y foco visible. Godot ofrece contenedores para esos patrones [G2].

### Cámara y gestos
Proponemos una cámara en perspectiva con objetivo fijo en la planta, rotación horizontal limitada a ambos lados y zoom acotado. No ofrecer desplazamiento libre que saque la planta del encuadre. Ajustar límites después de evaluar los modelos. La pantalla tendrá botones alternativos para girar, acercar y restablecer; un toque en una cualidad abre su explicación.

Separar los gestos del área 3D del desplazamiento de listas. Los controles superpuestos consumen su entrada y no giran la planta. Al entrar en un formulario, conservar foco y evitar que el teclado cubra campos o confirmaciones.

<!-- pagebreak -->
## 3 Receta visual y contribución bilateral
Para cada cualidad q, aplicar w(q) = 0,5 × I(q en A) / nA + 0,5 × I(q en B) / nB. Cada persona aporta 0,5 al total, aunque una elija tres y la otra cinco. La fórmula mezcla rasgos gráficos; no mide amor ni compatibilidad.

Ejemplo: A elige cariño, respeto y escucha; B elige respeto, paciencia, juego, calidez y gratitud. Respeto recibe 4/15; cariño y escucha reciben 1/6 cada una; las cuatro exclusivas de B reciben 1/10 cada una. Los pesos suman 1 y la unión conserva siete cualidades. Intercambiar A y B mantiene los mismos resultados.

### Composición por familias
| Familia | Capa de semilla | Continuidad en el brote |
| --- | --- | --- |
| Afecto | Matices y acabado de cubierta | Matices y bordes de hojas |
| Sostén | Contorno y trazos estructurales | Contorno y líneas del tallo |
| Conexión | Núcleo simbólico y motivos internos | Apertura pliegue y venas de hojas |
| Vitalidad | Motas curvas y acentos exteriores | Acentos e inclinación decorativa |
| Cuidado | Halo inferior simbólico | Raíces en vista de significado |

Los veinte motivos y significados deben seguir el Mapa del sistema de cualidades. Ordenar IDs estables antes de componer. Calcular mezclas por canal mediante reglas versionadas con límites mínimos y máximos. Aplicar en un orden fijo: base, contorno, cubierta, núcleo, acentos y capa inferior. El brote conserva los motivos equivalentes de cada familia.

### Intensidad y legibilidad
Todas las cualidades de la unión tienen motivo y entrada en la leyenda. El peso regula intensidad dentro de un intervalo que conserva presencia; no eliminar un motivo sólo por un peso pequeño. Mantener una base completa aunque no se elija una familia. Resolver superposiciones reservando zonas y usando el orden de composición, sin descartar silenciosamente una diferencia.

Si las veinte fichas afectan varios canales, combinar sus contribuciones antes de dibujar. Evitar veinte materiales o luces independientes. Una coincidencia sólo suma aportes de la fórmula; no aplicar un multiplicador adicional que la convierta en una recompensa.

### Resultado canónico
El servidor calcula y guarda selected_union, pesos, parámetros acotados, leyenda, catalog_version, recipe_version y asset_version. El cliente puede mostrar una vista previa local de su borrador propio, pero no inventa la receta compartida ni lee selecciones ajenas antes de tiempo. La receta final se valida en la misma revisión del acuerdo que ambos aprueban.

<!-- pagebreak -->
## 4 Recursos 3D y control de versiones
Preparar los originales en Blender y exportar GLB como formato de intercambio. Godot admite glTF y recomienda ese formato en su documentación de importación [G6]. No depender de tener Blender instalado en la máquina de compilación: entregar el GLB exportado junto con el original y su versión.

### Recursos mínimos
- Semilla base con contorno, cubierta y núcleo simbólico para la vista de significado.
- Tierra o recipiente, sin mecánica de riego ni colisiones complejas.
- Brote con tallo corto y exactamente dos hojas.
- Motivos de las veinte cualidades, mediante geometría ligera o máscaras de textura según la prueba.
- Materiales simples y animación opcional de siembra y aparición del brote.
- Representación estática y leyenda textual como alternativa a la escena animada.

Definir unidades y escala, origen en la base de la planta, nombres de nodos estables y pivotes previsibles. Revisar normales, UV, iluminación, transparencia y tamaño de textura al importar. Probar orientación y apariencia en el renderizador elegido; no asumir que un shader de Blender se transfiere idéntico.

### Escena propuesta
GardenView incluye SubViewportContainer y SubViewport. Dentro, GardenRoot agrupa CameraRig con Camera3D, luz, entorno, terreno y PlantRoot. PlantRoot aplica una receta validada a las piezas de semilla o brote. Un controlador de entrada cambia cámara y un presentador de UI muestra la leyenda; ninguno modifica el estado bilateral.

### Compatibilidad y preservación
Las actualizaciones incluyen manifiestos de recursos y versiones de receta que soportan. La planta sembrada conserva su asset_version. No reutilizar un mismo número de versión para un recurso distinto ni recalcular recetas antiguas con reglas nuevas.

Si una versión no está disponible o un recurso falla, mostrar el nombre, la etapa y el significado textual, con una imagen base claramente identificada si fuera necesaria. No reemplazarlo por una planta que atribuya otras cualidades. Empaquetar los recursos del MVP en la app para no depender de descargas durante la siembra.

### Determinismo
La identidad canónica exige los mismos IDs, pesos, parámetros, motivos y etapa; no exige igualdad píxel a píxel entre GPUs. Usar redondeo definido al guardar parámetros, orden fijo de mezcla y posiciones prediseñadas. Si un detalle requiere aleatoriedad, derivarlo de las entradas canónicas y de la versión de receta, nunca del usuario, dispositivo u orden de selección.

<!-- pagebreak -->
## 5 Presupuestos y calidad móvil
Los valores siguientes son metas iniciales para medir en una prueba, no requisitos publicados de Godot ni garantías de rendimiento. Ajustarlos con el teléfono objetivo y un recorrido instalado.

| Medida | Meta inicial propuesta | Condición de medición |
| --- | --- | --- |
| Fluidez del jardín | Tiempo de cuadro p95 menor o igual a 33 ms | Sesión de 10 minutos en equipo de referencia |
| Geometría visible | Hasta 30 000 triángulos | Semilla o brote y terreno juntos |
| Materiales activos | Hasta 8 | Evitar un material por cualidad |
| Luces y sombras | Una luz principal y sombra sencilla opcional | Evaluar temperatura y legibilidad |
| Texturas | Atlas de hasta 1024 por lado como partida | Medir memoria residente y artefactos |
| Memoria de la app | Meta inicial menor a 250 MB | Dispositivo físico y recorrido completo |
| Apertura del jardín | Menor a 2 segundos tras recibir datos | Recursos locales cargados sin red de arte |

El número de cuadros promedio no basta: observar picos, consumo sostenido, calentamiento, memoria y lectura de texto. Reducir primero sombras y efectos, después resolución del viewport 3D. La interfaz conserva resolución y contraste. Una escena fuera de pantalla no necesita animarse; al volver del segundo plano se revalida el servidor antes de reactivar el recorrido.

### Accesibilidad que debe probarse
Áreas táctiles de al menos 48 unidades lógicas, contraste adecuado, etiquetas que expliquen diferencias y texto ampliado al 150 % y 200 % sin perder acciones. Implementar crecimiento de filas y desplazamiento; no reducir la fuente para que entre un título. Validar la lectura y operación con TalkBack y VoiceOver en las compilaciones objetivo antes de aprobar el motor para lanzamiento.

El 3D tiene una leyenda textual completa y controles alternativos a gestos. Movimiento reducido elimina giro automático y balanceo; el ritual puede mostrar directamente su resultado. No exigir percibir color, profundidad o una animación para consentir o entender la semilla.

### Pruebas de la receta
Verificar orden de selección irrelevante, simetría al intercambiar integrantes, aporte de 0,5 por persona y suma total de 1. Probar elecciones sin coincidencias, coincidencia total, cantidades 3 y 5 y presencia de todas las cualidades de la unión. Revisar visualmente una muestra de recetas por familia y las mezclas extremas para detectar saturación o motivos tapados.

<!-- pagebreak -->
## 6 Plan de desarrollo por entregas
El plan usa resultados verificables en vez de fechas inventadas. Estimar tiempo cuando se conozcan disponibilidad del equipo, recursos de arte y acceso a equipos móviles. Una persona puede cubrir varios roles, pero cada entrega necesita revisión de producto, implementación y verificación.

| Entrega | Trabajo principal | Evidencia para cerrar |
| --- | --- | --- |
| 0 Diseño y decisión técnica | Completar estados de Figma y probar Godot móvil | Formularios accesibles, jardín y acceso HTTPS instalados |
| 1 Base del proyecto | Versiones, estructura, entorno, sesión y navegación | Compilación reproducible sin secretos |
| 2 Vínculo y selección | Invitaciones, catálogo y privacidad | Dos integrantes y cuenta externa probados |
| 3 Acuerdo y receta | Composición visual y aprobaciones por versión | Misma receta y rechazo de aprobación antigua |
| 4 Siembra y brote | Transacción, tiempo e hito individual | Reintentos, concurrencia y cambio de reloj probados |
| 5 Salida y recuperación | Desvinculación, eliminación y red inestable | Accesos revocados y tareas de borrado reintentables |
| 6 Prueba piloto | Rendimiento, comprensión y accesibilidad | Recorrido completo en Android y plataforma iOS prevista |

La prueba del primer brote usa un reloj o plazo de prueba controlado en un entorno separado; no una opción pública para acelerar cultivos reales. Las pruebas de concurrencia envían acciones desde dos sesiones y comprueban el resultado persistido.

### Antes de iniciar la entrega 1
Confirmar motor, renderizador, plataforma inicial, dispositivos de referencia y acceso a macOS con Xcode si se entrega iOS [G4]. Completar en Figma acceso, invitación recibida, consentimiento, errores, primera aprobación, primera confirmación de siembra y salida. Corregir el regreso desde el brote para mantener la etapa mostrada.

### Criterio de V1 completa
Dos personas crean el vínculo, comparten entre 3 y 5 cualidades, revisan la semilla, aprueban la misma versión, siembran y recuperan el primer brote. Una tercera cuenta nunca lee el contenido. Cualquiera puede salir; cerrar sesión o perder red no produce confirmaciones falsas. La planta conserva todos los aportes y no penaliza ausencia. El recorrido instalado cumple los criterios funcionales, de privacidad y accesibilidad.

## 7 Fuentes y relación con el producto
Documentación consultada el 2 de octubre de 2026. Las metas de rendimiento, nodos propuestos y entregas son decisiones de proyecto que requieren medición.
- G2 Godot Containers: https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html
- G4 Godot Exporting for iOS: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html
- G6 Godot Available 3D formats: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html
- Referencias internas: Especificación funcional V1, Mapa del sistema de cualidades, Arquitectura técnica V1 y Datos sincronización y privacidad V1.
- Diseño editable: https://www.figma.com/design/53oHlGwhPienbccVt3xyVc
