---
name: importacion-historica-graduados
description: Diseñar o verificar el staging, la trazabilidad y la conciliación del Excel histórico de titulaciones de Graduados UNA en SysGraduados_bd.
---

# Importación histórica de titulaciones

- Usá la hoja consolidada como fuente de carga. Usá el ODS para contrastar totales y documentá las diferencias con su período y categoría.
- Identificá el archivo y la hoja en `lote_importacion`. Conservá número de fila, datos originales, datos normalizados e incidencias en `stg_titulacion`. La pareja `(id_lote, numero_fila)` identifica una fila dentro del lote.
- Compará persona, oferta y fecha de juramentación. Si se confirma que es el mismo evento, vinculá la fila a la titulación existente mediante `registro_origen`. Para aceptar otra titulación ante una coincidencia, exigí revisión autorizada y justificación y conservá las candidatas.
- Confirmá el resultado de cada fila en una transacción. Al repetir o reanudar una carga, comprobá que no se generen titulaciones adicionales por el reintento.
- Conciliá filas nuevas, vinculadas, pendientes y rechazadas con el total leído. Mostrá las incidencias de fila y campo para permitir corrección y reimportación.
