## Why

La carga histórica debe admitir filas válidas y reintentos sin inflar los indicadores.

## What Changes

Persistir lotes, incidencias, coincidencias y vínculos de origen con confirmación transaccional.

## Capabilities

### New Capabilities

- `persistir-etl-graduados` — Persistencia y conciliación por fila en SQL Server.

### Modified Capabilities

## Impact

Migraciones y pruebas de integración en SysGraduados_bd. El consumidor es la API .NET.
