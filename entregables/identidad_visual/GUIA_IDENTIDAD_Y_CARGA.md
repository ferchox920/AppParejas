# AppParejas · Identidad visual y pantalla de carga

Versión 0.3 · 2 de octubre de 2026 · Propuesta para revisar

## Estado de la entrega

Esta iteración está preparada como archivos locales editables e importables. **No se ha añadido al archivo nativo de Figma**: su conexión MCP alcanzó el límite de llamadas del plan. El navegador alternativo abrió el archivo sin sesión de edición. El archivo existente sigue en https://www.figma.com/design/53oHlGwhPienbccVt3xyVc.

No se modificó el prototipo de Godot. El diseño se revisará antes de llevar estos cambios a desarrollo.

## Dirección visual

Botánica serena, con calidez y espacio. Se conserva el núcleo de colores de las plantillas existentes. Lora Regular para identidad y títulos; DM Sans Regular y Semibold para lectura, controles y estados. Las dos fuentes están incluidas con sus licencias OFL originales.

El símbolo es una semilla abstracta con dos hojas; representa el proyecto. **No sustituye a la semilla específica de la pareja ni revela sus cualidades**. El símbolo de marca no es el primer retoño de producto. Su uso inicial es una propuesta de identidad, sin asumir que el nombre de la app sea definitivo.

## Archivos

- `Vista_previa.html`: revisión interactiva sin servicios externos. Cambia de sección y prueba los tres estados, incluido movimiento reducido.
- `01_Pantallas_de_carga.svg`: lámina de inicio, carga y fallo de conexión.
- `pantalla_inicio.svg`, `pantalla_carga.svg`, `pantalla_conexion.svg`: pantallas separadas de 390 × 844.
- `02_Paleta_de_colores.svg`: muestras, roles y combinaciones verificadas.
- `03_Tipografia.svg`: familias, escala y muestras en español.
- `tokens_identidad.json`: colores, medidas, tipografía y ratios calculados.
- `fuentes/`: archivos tipográficos y licencias.

Los SVG conservan texto y geometría en el archivo fuente; no son capturas planas. La importación de Figma puede convertir algunos textos a contornos o no conservar fuentes incrustadas. Verificar las capas y, si hace falta, recrear el texto con Lora y DM Sans como capas nativas. Estos recursos todavía no son componentes, variables ni estilos nativos del nuevo diseño en Figma.

## Pantalla de inicio y carga

1. **Inicio**: nombre y símbolo, sin controles. No fijar una duración mínima para mostrar marca. El arranque nativo de Android/iOS es una etapa del sistema; no debe duplicarse con otra espera artificial.
2. **Carga**: “Abrimos tu jardín” y “Un momento…”, sólo mientras se abre un jardín vinculado. Indicador indeterminado de tres puntos. Para una persona sin jardín, usar “Preparando tu espacio” y continuar hacia bienvenida; no afirmar que hay un jardín compartido.
3. **Problema de conexión**: “No pudimos conectar”, explicación breve y botón “Reintentar”. El reintento de lectura no repite confirmaciones, envíos ni siembras. “Tus elecciones no se envían de nuevo” sólo debe mostrarse si esta garantía se conserva en la implementación. Si no puede cumplirse, retirarla; nunca prometer recuperación de borradores no guardados.

No se presenta una animación como prueba de que la pareja mejoró. No hay rachas, muerte, castigo ni porcentaje de compatibilidad. Una demora de red no es un estado relacional.

La transición automática ocurre cuando finaliza la operación real. Mostrar un error al fallar o alcanzar el tiempo límite configurado; no dejar una animación infinita. En diseño y desarrollo, prever recuperación de sesión, fallo de almacenamiento y cancelación donde aplique. Los tres estados de esta entrega no completan todavía todo ese flujo.

## Tipografía

| Uso | Familia / peso | Tamaño / interlineado |
|---|---|---|
| Identidad | Lora / 400 | 36 / 44 |
| Título | Lora / 400 | 31 / 40 |
| Subtítulo | Lora / 400 | 24 / 32 |
| Cuerpo | DM Sans / 400 | 16 / 24 |
| Acciones | DM Sans / 600 | 16 / 24 |
| Ayuda | DM Sans / 400 | 14 / 20 |
| Metadatos no esenciales | DM Sans / 600 | 12 / 18 |

Los valores están en píxeles de referencia de Figma; en el móvil usar unidades lógicas y respetar el escalado de texto. Evitar alturas rígidas, truncamientos de mensajes y fuentes de 12 px para información necesaria. Limitar las mayúsculas a metadatos breves. Esta escala amplía la propuesta previa y cambia el interlineado de título de 36 a 40; todavía no se ha propagado a las pantallas existentes.

## Paleta y accesibilidad

Crema `#FAF7F1`, verde bosque `#254C3B`, tinta `#23352B`, musgo gris `#59665C`, salvia `#E3EBDD` y arcilla `#EAC1AA`. Error `#963A3B`, fondo de error `#F9ECE8`, aviso `#765321` sobre `#F0E6D3`, foco `#7B623C`.

Se comprobaron por fórmula siete combinaciones de color: lectura ≥ 4.5:1, borde de selección y foco ≥ 3:1 contra las superficies especificadas. Las ratios constan en el JSON. Esto no demuestra por sí solo la accesibilidad completa: queda probar texto aumentado, lectores de pantalla, orden de foco, contraste del foco en todas las superficies y dispositivos reales. Los bordes `#D6DDD2` son divisores decorativos; para delimitar controles esenciales usar verde bosque u otro borde con contraste verificado. No usar blanco sobre salvia o arcilla para texto de lectura.

Toda selección, espera o error incluye texto o icono además del color. No asociar familias de cualidades a jerarquías de valor ni a colores de “buenas” y “malas”. Los indicadores se ocultan al lector de pantalla; el mensaje de carga se anuncia una vez. Reintentar tiene un área táctil de 56 px de altura y el foco es visible.

## Movimiento

Propuesta de carga: tres puntos con desplazamiento máximo de 4 px, ciclo de 1.4 s y desfase de 0.2 s. Respetar la preferencia del sistema y la opción interna de movimiento reducido: puntos estáticos y el mismo mensaje. No usar pulsos de la planta, rotación de cámara automática, destellos ni animación continua del fondo para la carga. No se creó un prototipo de movimiento nativo en Figma en esta iteración.

## Incorporación pendiente en Figma

Crear una página `03 · Identidad y carga`, importar los SVG como referencia editable, y reconstruir/verificar los textos nativos. Usar las colecciones existentes `AppParejas · Primitivos` y `AppParejas · Interfaz`: conservar los colores coincidentes y añadir los nuevos roles de foco, aviso y fondo de error. Crear estilos nativos a partir de la escala y componentes de inicio/carga/error con auto layout. Conectar el inicio del recorrido sin introducir una demora artificial. Revisar anchura 360 y 390, texto ampliado y zonas seguras de ambos sistemas.

## Decisiones para revisar juntos

- Aprobar o ajustar el tono botánico y la combinación Lora + DM Sans.
- Revisar el símbolo de marca y el nombre AppParejas.
- Ajustar los textos de inicio y carga según el recorrido.
- Después, diseñar bienvenida, acceso y las variantes del selector de cualidades.
