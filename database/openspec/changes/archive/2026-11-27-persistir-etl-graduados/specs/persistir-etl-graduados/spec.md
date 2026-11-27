## Purpose

Mantener la consistencia de la carga histórica de titulaciones ante fallos, revisiones y reintentos concurrentes.

## ADDED Requirements

### Requirement: Identidad de lote
El sistema SHALL garantizar el siguiente comportamiento.

#### Scenario: Identidad de lote
- **WHEN** recibe dos cargas concurrentes del mismo contenido y hoja
- **THEN** ambas recuperan el mismo lote y existe una sola fila staging por número de fila original.

### Requirement: Atomicidad y reanudación
El sistema SHALL garantizar el siguiente comportamiento.

#### Scenario: Atomicidad y reanudación
- **WHEN** ocurre un fallo entre insertar la titulación y vincular el origen
- **THEN** la transacción revierte ambos cambios y el reintento confirma una sola titulación con su vínculo.

### Requirement: Coincidencias
El sistema SHALL garantizar el siguiente comportamiento.

#### Scenario: Coincidencias
- **WHEN** otra fila coincide en persona, oferta y fecha con un evento previo
- **THEN** queda pendiente con sus candidatas; una revisión autorizada puede vincular el evento existente o justificar una titulación adicional conservando quién decidió y cuándo.

### Requirement: Conciliación
El sistema SHALL garantizar el siguiente comportamiento.

#### Scenario: Conciliación
- **WHEN** el lote termina con filas nuevas, vinculadas, pendientes y rechazadas
- **THEN** cada fila pertenece a exactamente una categoría y la suma coincide con las filas leídas.
