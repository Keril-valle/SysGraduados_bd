CREATE OR ALTER PROCEDURE dbo.etl_confirmar_fila
    @id_lote int,
    @numero_fila int,
    @decision nvarchar(16) = NULL,
    @revisado_por nvarchar(256) = NULL,
    @justificacion nvarchar(max) = NULL,
    @id_candidata int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @staging int, @estado nvarchar(256), @datos nvarchar(max), @revision int,
            @persona int, @titulacion int, @estado_titulacion int;
    DECLARE @candidatas TABLE (id_titulacion int PRIMARY KEY);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- One lock order per lot and per person avoids competing writes from overlapping batches.
        IF NOT EXISTS (SELECT 1 FROM dbo.lote_importacion WITH (UPDLOCK, HOLDLOCK) WHERE id_lote=@id_lote)
            THROW 51004, 'El lote no existe.', 1;

        SELECT @staging=id_staging, @estado=estado_validacion, @datos=datos_normalizados
        FROM dbo.stg_titulacion WITH (UPDLOCK, HOLDLOCK)
        WHERE id_lote=@id_lote AND numero_fila=@numero_fila;
        IF @staging IS NULL THROW 51005, 'La fila no existe.', 1;

        IF @decision IS NOT NULL AND
            (@estado <> N'pendiente' OR @decision NOT IN (N'vincular', N'crear')
             OR NULLIF(TRIM(@revisado_por), N'') IS NULL OR NULLIF(TRIM(@justificacion), N'') IS NULL)
            THROW 51006, 'La revisión requiere una fila pendiente, decisión, responsable y justificación.', 1;

        IF @estado = N'por_procesar' OR @decision IS NOT NULL
        BEGIN
            DECLARE @tipo nvarchar(4000)=JSON_VALUE(@datos,'$.tipo_identificacion'),
                    @numero nvarchar(4000)=JSON_VALUE(@datos,'$.numero_identificacion'),
                    @codigo nvarchar(4000)=JSON_VALUE(@datos,'$.codigo_titulo'),
                    @fecha date=TRY_CONVERT(date,JSON_VALUE(@datos,'$.fecha_juramentacion'),23),
                    @nombre nvarchar(4000)=JSON_VALUE(@datos,'$.nombre'),
                    @apellido nvarchar(4000)=JSON_VALUE(@datos,'$.primer_apellido'),
                    @pais nvarchar(4000)=JSON_VALUE(@datos,'$.codigo_pais'),
                    @unidad nvarchar(4000)=JSON_VALUE(@datos,'$.codigo_unidad');
            DECLARE @incidencia nvarchar(max);

            IF @tipo IS NULL OR LEN(@tipo) NOT BETWEEN 1 AND 64 OR @numero IS NULL OR LEN(@numero) NOT BETWEEN 1 AND 64
                SET @incidencia=N'[{"campo":"identificacion","motivo":"Identificación inválida"}]';
            ELSE IF @fecha IS NULL
                SET @incidencia=N'[{"campo":"fecha_juramentacion","motivo":"Fecha inválida"}]';
            ELSE IF @codigo IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.oferta_titulo WHERE codigo_titulo=@codigo)
                SET @incidencia=N'[{"campo":"codigo_titulo","motivo":"Oferta desconocida"}]';
            ELSE IF @unidad IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.oferta_titulo WHERE codigo_titulo=@codigo AND codigo_unidad=@unidad)
                SET @incidencia=N'[{"campo":"codigo_unidad","motivo":"Unidad incompatible con la oferta"}]';
            ELSE IF @pais IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.pais WHERE codigo_pais=@pais)
                SET @incidencia=N'[{"campo":"codigo_pais","motivo":"País desconocido"}]';
            ELSE IF @nombre IS NULL OR LEN(@nombre) NOT BETWEEN 1 AND 256 OR @apellido IS NULL OR LEN(@apellido) NOT BETWEEN 1 AND 256
                SET @incidencia=N'[{"campo":"nombre","motivo":"Nombre o primer apellido inválido"}]';

            IF @incidencia IS NOT NULL
            BEGIN
                IF @decision IS NOT NULL THROW 51007, 'Los datos de la revisión ya no son válidos.', 1;
                SET @estado=N'rechazada';
            END
            ELSE
            BEGIN
                SELECT @persona=id_persona FROM dbo.persona WITH (UPDLOCK, HOLDLOCK)
                WHERE tipo_identificacion=@tipo AND numero_identificacion=@numero;
                IF @persona IS NULL
                BEGIN
                    INSERT dbo.persona (tipo_identificacion,numero_identificacion,nombre,primer_apellido,
                                        segundo_apellido,carnet,sexo_registrado,codigo_pais,correo_electronico)
                    VALUES (@tipo,@numero,@nombre,@apellido,JSON_VALUE(@datos,'$.segundo_apellido'),
                            JSON_VALUE(@datos,'$.carnet'),JSON_VALUE(@datos,'$.sexo_registrado'),@pais,
                            JSON_VALUE(@datos,'$.correo_electronico'));
                    SET @persona=CONVERT(int,SCOPE_IDENTITY());
                END;

                INSERT @candidatas
                SELECT id_titulacion FROM dbo.titulacion WITH (UPDLOCK,HOLDLOCK)
                WHERE id_persona=@persona AND codigo_titulo=@codigo AND fecha_juramentacion=@fecha;

                IF @decision IS NULL AND EXISTS (SELECT 1 FROM @candidatas)
                BEGIN
                    INSERT dbo.revision_duplicado(id_staging,datos_solicitud) VALUES (@staging,@datos);
                    SET @revision=CONVERT(int,SCOPE_IDENTITY());
                    INSERT dbo.revision_coincidencia(id_revision,id_titulacion_candidata)
                        SELECT @revision,id_titulacion FROM @candidatas;
                    SET @estado=N'pendiente';
                END
                ELSE
                BEGIN
                    IF @decision=N'vincular'
                    BEGIN
                        IF NOT EXISTS (
                            SELECT 1 FROM dbo.revision_coincidencia AS c
                            JOIN dbo.revision_duplicado AS r ON r.id_revision=c.id_revision
                            JOIN @candidatas AS actual ON actual.id_titulacion=c.id_titulacion_candidata
                            WHERE r.id_staging=@staging AND r.decision IS NULL AND actual.id_titulacion=@id_candidata
                        ) THROW 51008, 'La titulación no es candidata de esta revisión.', 1;
                        SET @titulacion=@id_candidata;
                        SET @estado=N'vinculada';
                    END
                    ELSE
                    BEGIN
                        SELECT @estado_titulacion=id_estado FROM dbo.estado_titulacion WHERE nombre=N'VIGENTE';
                        IF @estado_titulacion IS NULL THROW 51009, 'El catálogo requiere el estado VIGENTE.', 1;
                        INSERT dbo.titulacion(id_persona,codigo_titulo,id_estado,fecha_juramentacion,origen_registro)
                        VALUES (@persona,@codigo,@estado_titulacion,@fecha,N'excel');
                        SET @titulacion=CONVERT(int,SCOPE_IDENTITY());
                        SET @estado=N'nueva';
                    END;

                    INSERT dbo.registro_origen(id_staging,id_titulacion) VALUES (@staging,@titulacion);
                    INSERT dbo.persona_telefono(id_persona,numero)
                    SELECT DISTINCT @persona, t.value
                    FROM OPENJSON(@datos,'$.telefonos') AS t
                    WHERE t.type=1 AND LEN(t.value) BETWEEN 1 AND 64
                      AND NOT EXISTS (SELECT 1 FROM dbo.persona_telefono AS p WHERE p.id_persona=@persona AND p.numero=t.value);

                    IF @decision IS NOT NULL
                        UPDATE dbo.revision_duplicado
                        SET id_titulacion_resultado=@titulacion, decision=@decision, revisado_por=@revisado_por,
                            fecha_revision=SYSUTCDATETIME(), justificacion=@justificacion
                        WHERE id_staging=@staging AND decision IS NULL;
                END;
            END;

            UPDATE dbo.stg_titulacion
            SET estado_validacion=@estado,detalle_incidencias=@incidencia,ultima_validacion=SYSUTCDATETIME()
            WHERE id_staging=@staging;
        END;

        UPDATE dbo.lote_importacion
        SET estado=CASE WHEN EXISTS (
            SELECT 1 FROM dbo.stg_titulacion WHERE id_lote=@id_lote AND estado_validacion=N'por_procesar'
        ) THEN N'en_proceso' ELSE N'procesado' END
        WHERE id_lote=@id_lote;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH;
    SELECT @estado AS estado_validacion;
END;
GO
