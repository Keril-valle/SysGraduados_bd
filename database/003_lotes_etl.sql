CREATE OR ALTER PROCEDURE dbo.etl_registrar_lote
    @nombre_archivo nvarchar(256),
    @hoja nvarchar(256),
    @hash_archivo nvarchar(256),
    @filas nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF DATALENGTH(@hash_archivo) <> 128 OR @hash_archivo COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9a-f]%'
        THROW 51002, 'Se requiere SHA-256 hexadecimal en minúscula.', 1;
    IF ISNULL(ISJSON(@filas, ARRAY), 0) <> 1
        THROW 51003, 'Se requiere un arreglo JSON de filas.', 1;

    DECLARE @id_lote int;
    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @id_lote = id_lote
        FROM dbo.lote_importacion WITH (UPDLOCK, HOLDLOCK)
        WHERE hash_archivo = @hash_archivo AND hoja = @hoja;

        IF @id_lote IS NULL
        BEGIN
            INSERT dbo.lote_importacion(nombre_archivo, hoja, hash_archivo, fecha_importacion, estado)
            VALUES (@nombre_archivo, @hoja, @hash_archivo, SYSUTCDATETIME(), N'en_proceso');
            SET @id_lote = CONVERT(int, SCOPE_IDENTITY());

            INSERT dbo.stg_titulacion
                (id_lote, numero_fila, anio_en_archivo, datos_originales, datos_normalizados,
                 estado_validacion, detalle_incidencias, ultima_validacion)
            SELECT @id_lote, numero_fila, anio_en_archivo, datos_originales, datos_normalizados,
                   IIF(detalle_incidencias IS NULL, N'por_procesar', N'rechazada'),
                   detalle_incidencias,
                   IIF(detalle_incidencias IS NULL, NULL, SYSUTCDATETIME())
            FROM OPENJSON(@filas) WITH (
                numero_fila int,
                anio_en_archivo int,
                datos_originales nvarchar(max) AS JSON,
                datos_normalizados nvarchar(max) AS JSON,
                detalle_incidencias nvarchar(max) AS JSON
            );
        END;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH;
    SELECT @id_lote AS id_lote;
END;
GO

CREATE OR ALTER VIEW dbo.etl_resumen_lote
AS
    SELECT l.id_lote, l.estado, COUNT(s.id_staging) AS leidas,
           COUNT(CASE WHEN s.estado_validacion = N'nueva' THEN 1 END) AS nuevas,
           COUNT(CASE WHEN s.estado_validacion = N'vinculada' THEN 1 END) AS vinculadas,
           COUNT(CASE WHEN s.estado_validacion = N'pendiente' THEN 1 END) AS pendientes,
           COUNT(CASE WHEN s.estado_validacion = N'rechazada' THEN 1 END) AS rechazadas,
           COUNT(CASE WHEN s.id_staging IS NOT NULL AND s.estado_validacion NOT IN
               (N'nueva', N'vinculada', N'pendiente', N'rechazada') THEN 1 END) AS sin_procesar
    FROM dbo.lote_importacion AS l
    LEFT JOIN dbo.stg_titulacion AS s ON s.id_lote = l.id_lote
    GROUP BY l.id_lote, l.estado;
GO
