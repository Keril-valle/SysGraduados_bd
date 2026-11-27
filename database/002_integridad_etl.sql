SET XACT_ABORT ON;
BEGIN TRANSACTION;

-- Existing duplicate batches require reconciliation before the unique index can be created.
IF EXISTS (
    SELECT 1 FROM dbo.lote_importacion
    GROUP BY hash_archivo, hoja HAVING COUNT(*) > 1
)
    THROW 51000, 'Reconcilie los lotes duplicados por hash y hoja antes de aplicar la migración.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.lote_importacion') AND name = N'UX_lote_importacion_hash_hoja')
    CREATE UNIQUE INDEX UX_lote_importacion_hash_hoja ON dbo.lote_importacion(hash_archivo, hoja);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.titulacion') AND name = N'IX_titulacion_evento')
    CREATE INDEX IX_titulacion_evento ON dbo.titulacion(id_persona, codigo_titulo, fecha_juramentacion);

COMMIT;
