# Fase inicial de AppParejas

Actualización del 2 de octubre de 2026.

Actualización de primera apertura: el recorrido persistente de bienvenida, introducción, acceso e invitaciones de demostración está implementado e integrado con las cualidades y el jardín. Compartir abre Android y la cámara contempla permiso denegado. El backend, el lector de QR y los enlaces públicos siguen pendientes. Ver [primera apertura](PRIMERA_APERTURA.md) para el estado vigente, pruebas y contratos de integración; el registro original de tres vistas se conserva debajo.

Actualización Android: se recuperó esta base en `D:/PersonalProyect/AppParejas`, se configuraron las plantillas 4.7.2 y se generó un APK de depuración. Se verificaron instalación, bienvenida, navegación al jardín y pantalla de cualidades con texto aumentado en el teléfono Samsung SM-S936U1 con Android 16. El emulador se cerró y las próximas pruebas usan el teléfono. Siguen pendientes mediciones de rendimiento y accesibilidad. Ver [la guía Android](ANDROID.md). Las secciones siguientes conservan el registro de la inicialización original.

La fase inicial convierte los documentos y diseños en una base ejecutable para evaluar Godot. Esta entrega inicia la prueba técnica; no cierra los criterios de la entrega 0 de la arquitectura.

## Implementado

- Repositorio Git local en `main`, con documentos y diseños versionados.
- Godot 4.7.2 estable, GDScript tipado y renderizador Compatibility.
- Catálogo JSON de 20 cualidades y cinco familias, con IDs y definiciones de la fuente de producto.
- Dominio separado para validación de selecciones y mezcla gráfica de aportes equivalentes.
- Tres vistas: bienvenida, jardín y selección de cualidades.
- Jardín con SubViewport, cámara acotada y controles alternativos a gestos.
- Semilla y brote con dos hojas hechos con geometría simple.
- Estado del brote conservado al volver desde la selección sin aplicar una receta nueva.
- Tipografía DM Sans y Lora, listas desplazables y texto aumentado.
- Herramientas para abrir el proyecto y ejecutar verificaciones reproducibles.

La vista previa no guarda datos privados, envía solicitudes, genera invitaciones ni presenta confirmaciones de siembra. La segunda elección es ficticia y fija; el usuario sólo modifica un ejemplo local. Los puntos sobre la semilla y su color son recursos de la maqueta, no la traducción completa de las veinte cualidades.

## Verificado en esta entrega

Godot importó y ejecutó el proyecto sin errores de script. Las pruebas automatizadas comprobaron validación, unión de cualidades, suma de pesos, simetría al intercambiar integrantes, invariancia del orden, navegación, límites de cámara, mínimo y máximo de selección y legibilidad estructural de las etiquetas de familias.

También se renderizaron y revisaron seis vistas con el motor gráfico real en Windows: bienvenida, semilla, brote, selección, selección con texto al 150 % y ancho lógico 360, y jardín con ancho lógico 430. La validación visual corresponde a escritorio con GPU; no demuestra rendimiento ni accesibilidad en teléfonos.

Resultado final: **230 verificaciones automatizadas y cero fallos**. [Ver capturas de la implementación](imagenes/Inicio_Godot.png).

## Para cerrar la prueba técnica

1. Configurar plantillas de exportación y generar una compilación Android.
2. Instalar y medir el recorrido en al menos un teléfono objetivo. No había dispositivo conectado durante esta inicialización.
3. Probar formularios, gestos, teclado, áreas seguras y TalkBack en esa compilación.
4. Preparar macOS con Xcode y repetir la prueba de exportación y VoiceOver si iOS integra la primera entrega.
5. Validar una llamada HTTPS con datos de prueba y el mecanismo de sesión seguro antes de conectar cuentas reales.
6. Contrastar Compatibility con Mobile sobre el mismo dispositivo y recursos.
7. Completar en Figma los estados de acceso, consentimiento, primera aprobación, siembra pendiente, errores y salida.

Después de estas pruebas se ratifica Godot o se reabre la comparación con Unity. No se crearon recursos externos de Supabase, claves, servicios de pago ni un remoto Git.

## Próxima implementación del producto

Una vez validada la base móvil, crear migraciones SQL y pruebas de permisos para vínculo e invitación; integrar acceso individual; luego selección privada y revelación bilateral. Los contratos están en los documentos técnicos de `entregables/`.
