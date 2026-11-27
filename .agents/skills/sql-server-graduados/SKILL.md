---
name: sql-server-graduados
description: Diseñar o verificar cambios de esquema, migraciones T-SQL y consultas estadísticas de Graduados UNA en SysGraduados_bd.
---

# SQL Server de Graduados UNA

- Revisá los scripts de `database/` antes de cambiar el esquema. Para instalaciones existentes, agregá una migración incremental y verificá también la instalación limpia.
- Conservá el vínculo entre persona, titulación, oferta y unidad académica. Las identificaciones y carnés son texto. Una persona puede tener varias titulaciones.
- Para indicadores, filtrá por fecha de juramentación y unidad académica. Contá titulaciones por evento y personas con `COUNT(DISTINCT id_persona)` sobre todo el período filtrado. Evitá que uniones con teléfonos o registros de origen multipliquen los resultados.
- Verificá migraciones con `sqlcmd -b` en una base local de prueba. Comprobá restricciones, filas preexistentes y casos con dos títulos para una persona.
- Para publicación, consultá las reglas aprobadas sobre estados, cortes y acceso a datos personales.
