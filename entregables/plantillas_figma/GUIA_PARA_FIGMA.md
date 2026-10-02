# Plantillas iniciales de AppParejas

Versión 0.2 · 2 de octubre de 2026

Esta propuesta visual permite revisar el recorrido de la V1 antes de implementarlo en Godot. Incluye diez pantallas móviles, una lámina de componentes, un panorama del recorrido y los valores de color y espaciado. El estilo inicial es botánico y sereno, con fondos cálidos y verdes.

## Archivo editable en Figma

[Abrir AppParejas · Plantillas V1](https://www.figma.com/design/53oHlGwhPienbccVt3xyVc)

El archivo contiene dos páginas: **01 · Pantallas V1** y **02 · Componentes**. Las diez pantallas usan textos nativos, instancias de componentes y auto layout. Incluye siete familias de componentes —botón, ficha de cualidad, etiqueta, tarjeta, campo, estado bilateral y escena— con trece componentes principales en total; seis estilos de texto y cuarenta y una variables de colores y geometría organizadas en dos colecciones. La tipografía del archivo es **Lora** para títulos y **DM Sans** para la interfaz.

En el modo Presentar hay tres puntos de entrada: **Elección individual**, **Ambos compartieron** y **Primer brote**. Las conexiones permiten recorrer pantallas y abrir la explicación de la semilla. Son ejemplos con datos fijos: no ejecutan cuentas, selecciones, aprobaciones ni el transcurso del tiempo. En particular, volver desde Primer brote lleva al ejemplo de jardín con semilla; el estado de crecimiento no se conserva en este prototipo.

Se revisaron visualmente las diez exportaciones del archivo a escala 2× y la lámina de componentes. Se corrigieron recortes de títulos, párrafos y etiquetas. Falta probar el diseño con usuarios, texto aumentado y los estados adicionales indicados abajo. La semilla y el brote son ilustraciones vectoriales conceptuales para orientar la futura escena 3D de Godot.

## Qué contiene este paquete

- `pantallas/`: diez SVG individuales de 390 × 844 px.
- `00_componentes.svg`: referencia de colores, tipografía, botones, campos y estados de selección.
- `01_panorama_pantallas.svg`: vista conjunta del recorrido.
- `tokens_visuales.json`: valores editables del sistema visual.
- `Vista_previa.html`: lámina local para revisar los diseños en un navegador.
- `Figma_Vista_general.png`: panorama de las diez pantallas exportadas del archivo nativo.
- `exportaciones_figma/`: capturas PNG de las diez pantallas a escala 2×.
- `Figma_componentes.png`: vista de los componentes nativos.

Los SVG son material vectorial de partida. No son un archivo `.fig`, componentes nativos de Figma, variantes ni un prototipo conectado. Al importarlos, comprobar cómo conserva Figma los textos y grupos; cuando sea necesario, recrear textos como capas nativas. Los modelos de planta son ilustraciones conceptuales estáticas, no recursos 3D para Godot.

## Organización ampliada para próximas iteraciones

La primera versión reúne las pantallas y la guía en una página, y los componentes en otra. La siguiente organización permite ampliar el archivo cuando se completen los estados:

1. **00 Guía y decisiones**: objetivo, alcance, reglas bilaterales y decisiones abiertas.
2. **01 Fundamentos**: variables de color, estilos de texto, espaciado, radios y controles táctiles.
3. **02 Componentes**: botones, ficha de cualidad, etiquetas, campos, estados y navegación.
4. **03 Recorrido V1**: las diez pantallas en orden y las variantes de cada estado.
5. **04 Prototipo**: conexiones navegables y ejemplos de las dos personas.
6. **05 Jardín 3D**: encuadre, cámara, gestos, zonas tocables y movimiento reducido.
7. **06 Entrega a desarrollo**: estados, reglas, textos, recursos y criterios de verificación.

## Estados de componentes a completar

Ya existen los siete grupos de componentes descritos arriba. La tabla expresa el conjunto ampliado de estados deseado; carga, errores, confirmaciones de salida y cabeceras como componentes independientes quedan pendientes.

| Componente | Variantes o propiedades | Comportamiento |
|---|---|---|
| Botón | Principal, secundario; disponible, deshabilitado, cargando. | Una acción por botón; área táctil de al menos 48 px. |
| Ficha de cualidad | Disponible, elegida; nombre, definición. | Marca explícita y cambio de superficie; no depender sólo del color. |
| Etiqueta de cualidad | Familia, elegida, coincidencia. | Nombre siempre visible. La distinción no implica un puntaje. |
| Campo | Vacío, completo, foco, error; ayuda y límite. | Mensaje de error junto al campo y valor conservado. |
| Estado bilateral | Tu aporte listo, esperando, ambos listos. | Mostrar estado sin revelar cualidades privadas. |
| Cabecera | Volver, título, paso opcional. | Mantener navegación consistente. |
| Jardín | Semilla, sembrada, brote; carga, error. | Separar controles de interfaz de los gestos de cámara. |
| Confirmación de salida | Desvinculación, eliminación. | Explicar consecuencias antes de confirmar. |

Mantener botones, fichas y campos con auto layout y propiedades de texto al completar sus estados. Los marcos iniciales son una referencia, no tamaños fijos de producción: validar también un ancho de 360 px y texto aumentado. Los SVG originales usan Georgia y Segoe UI; el archivo nativo usa Lora y DM Sans. Confirmar las fuentes que se distribuirán con la app al preparar la entrega a desarrollo.

## Recorrido y reglas que deben preservarse

### 01 Bienvenida
Explicar la metáfora y ofrecer crear cuenta o iniciar sesión. Agregar después las pantallas de acceso, recuperación y consentimiento, necesarias para completar la V1.

### 02 Invitación
Mostrar generación y compartir enlace. Agregar variantes para quien recibe el enlace, aceptación, rechazo, vencimiento, revocación y cuenta ya vinculada. La maqueta usa un enlace ficticio, sin token real.

### 03 Cualidades
El ejemplo muestra la familia Afecto y cuatro elecciones acumuladas: cariño, respeto, paciencia y escucha. Sólo cariño aparece marcado entre las fichas de la familia visible. Diseñar el selector completo de las cinco familias y el resumen de elegidas. Compartir sólo se habilita entre 3 y 5 selecciones únicas.

### 04 Espera
La selección propia sigue visible. No mostrar nombres ni cantidad de cualidades de la otra persona mientras no se hayan revelado. Revisar permite retirar o modificar la elección con explicación de los efectos.

### 05 Encuentro
El ejemplo tiene dos coincidencias, respeto y paciencia. Una persona también eligió cariño y escucha; la otra, calidez, juego y gratitud. La unión contiene siete cualidades. Agregar variantes sin coincidencias y con coincidencia total, sin juicio de compatibilidad.

### 06 Acuerdo
Nombre e intención son una propuesta compartida. Agregar estados de aprobación de una persona, de ambas y de cambios que invalidan aprobaciones. Los textos de la maqueta cumplen los límites de nombre y frase definidos en la especificación.

### 07 Ritual
La maqueta muestra un acuerdo ya aprobado por ambos, antes de confirmar sembrar. Agregar el estado después de la primera confirmación, opción de retirarla y actualización de acuerdo. La segunda confirmación válida completa la siembra; no exige simultaneidad.

### 08 Jardín
Representa la semilla ya sembrada y siete cualidades originales. El crecimiento no depende de volver diariamente. Las fechas son de demostración. Agregar control accesible para consultar significado y una forma de entrar en ajustes.

### 09 Primer brote
La fecha de demostración es siete días después de la siembra. El plazo sigue siendo una propuesta de producto a validar. Cada persona puede descubrir el brote en un momento distinto. No interpretar el hito como mejora relacional.

### 10 Ajustes
La pantalla sólo abre acciones. La desvinculación y la eliminación necesitan sus confirmaciones y consecuencias, según la especificación. No exigir la aprobación de la pareja para salir del vínculo.

## Lo que Figma puede definir sobre el jardín 3D

Definir encuadre inicial, posición de controles, rotación horizontal, zoom limitado, zonas de toque y acceso a explicaciones. Preparar vistas del estado semilla y brote, y una alternativa de movimiento reducido.

El rendimiento, la cámara real, el balanceo, las deformaciones y la iluminación se verificarán después en un prototipo de Godot. Mantener la misma receta visual entre dispositivos sin exigir imágenes idénticas píxel a píxel.

## Qué falta para validar diseño antes de desarrollar

- Completar las variantes de consentimiento, invitación, espera, errores, salida y pérdida de conexión.
- Ampliar el prototipo conectado para representar las acciones de ambos integrantes, las revisiones y la persistencia de cada etapa sin revelar datos antes de tiempo.
- Revisar comprensión de cualidades, significado de diferencias y consecuencias de editar o salir.
- Probar texto aumentado, contraste, navegación y controles táctiles.
- Confirmar dirección artística y aprobar el conjunto de modelos 3D de referencia.

Estos materiales permiten iniciar la conversación visual. No sustituyen las reglas de los dos documentos fuente ni representan un diseño final aprobado.
