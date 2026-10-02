# Decisiones de la fase inicial

## Motor fijado para la prueba

Usamos Godot 4.7.2 estable con GDScript. Se descargó el paquete portátil oficial y se registró su SHA256 en `tools/toolchain.json`. El binario no se incluye en Git. La elección se adopta para ejecutar la prueba inicial, sujeta a exportación móvil, accesibilidad e integración nativa.

## Interfaz y jardín en una app

La interfaz usa controles y contenedores de Godot. El jardín se dibuja en un SubViewport dentro de la interfaz. El código de mezcla y catálogo vive en `src/domain`; la presentación y geometría de prueba viven en `src/ui`. No se añadieron capas sin uso ni un segundo framework de interfaz.

## Mezcla local limitada a la vista previa

Cada elección aporta 0,5 al total y cada cualidad conserva un aporte de quien la eligió. Las listas se ordenan por ID estable para construir una identidad reproducible. La identidad incluye versiones de catálogo, receta y recursos. Este código no valida consentimientos y no puede aprobar o crear un cultivo: esa responsabilidad queda para PostgreSQL.

## Arte provisional

Usamos primitivas del motor para probar profundidad, iluminación y cámara. El mapa completo de motivos y modelos GLB se incorpora después de validar el encuadre y rendimiento. No se utiliza IA de generación de imágenes ni una simulación botánica para dibujar la planta.

## Git y referencias

`sources/` y el AGENTS.md del espejo se mantienen como referencias locales de sólo lectura y se excluyen del repositorio. Los documentos de `entregables/` sí están versionados. Se excluyen las revisiones internas, cachés, motor portátil, capturas de prueba y credenciales. El repositorio no tiene remoto configurado.
