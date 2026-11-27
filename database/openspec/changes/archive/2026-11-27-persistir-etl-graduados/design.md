## Context

001_inicial.sql define lote_importacion, stg_titulacion, registro_origen y las tablas de revisión. La clave de staging ya protege (id_lote, numero_fila); el lote aún carece de unicidad por contenido y hoja.

## Goals / Non-Goals

Este incremento termina en la API y SQL Server. El tablero y la publicación institucional quedan para otro cambio.

## Decisions

Aplicar migración incremental con clave única (hash_archivo, hoja), contemplando los lotes existentes antes de crearla. Usar SHA-256 del contenido. Serializar la comprobación y escritura de persona/oferta/fecha en una transacción con índice de búsqueda. La decisión autorizada admite dos eventos legítimos con la misma clave. Persistir resultado por fila y actualizar totales desde esos resultados. La API controla autorización; SQL asegura integridad.

## Risks / Trade-offs

Ejecutar integración y E2E contra SQL Server real en Docker o una instancia dedicada con BD desechable por ejecución. Aislar el servidor cuando se aplique 001_inicial.sql, que selecciona SysGraduados por nombre. Usar un XLSX sintético con la estructura del Excel de graduados; mantener el archivo institucional fuera del repositorio.
