# TinySpec: Hooks `before_tasks` y `before_clarify`

**Branch**: main
**Date**: 2026-09-04
**Status**: done
**Complexity**: small

## What

La extensión `knowledge` solo sincroniza en `before_specify` y `before_plan`. Los contratos y decisiones compartidas también son relevantes al desglosar tareas y al resolver ambigüedades, así que hoy `/speckit.tasks` y `/speckit.clarify` arrancan con una caché potencialmente obsoleta. Añadir esos dos puntos de enganche.

## Context

| File | Role |
|------|------|
| [extension.yml](../../extension.yml) | Modificar — 2 entradas nuevas bajo `hooks:` + bump de versión |
| [README.md](../../README.md) | Modificar — § "Integration with /speckit-specify and /speckit-plan" cubre solo 2 hooks |
| [CHANGELOG.md](../../CHANGELOG.md) | Modificar — sección `[1.3.0]` |

`before_tasks` y `before_clarify` son puntos válidos: aparecen entre los 19 eventos que spec-kit registra en `.specify/extensions.yml` de este proyecto.

## Requirements

1. `extension.yml#hooks` declara `before_tasks` y `before_clarify`, ambos con `command: speckit.knowledge.sync` y **sin argumentos** — FR-016 de la spec 003 exige que el auto-trigger no pueda pasar `--no-context-output`.
2. Ambos usan `optional: true` + `prompt`, idéntico al patrón de los dos hooks existentes.
3. `extension.version` pasa de `1.2.0` a `1.3.0` (feature nueva → minor).
4. Tras `specify extension add <path> --dev` en un proyecto limpio, los **cuatro** hooks aparecen en el `.specify/extensions.yml` del consumidor.
5. El README deja de describir la integración como exclusiva de specify/plan.

## Plan

1. `extension.yml`: añadir las 2 entradas a `hooks:`, copiando la forma de `before_plan` (`command` / `optional` / `prompt` / `description`).
2. `extension.yml`: `version: "1.2.0"` → `"1.3.0"`.
3. `README.md`: retitular la sección de integración a algo neutro y listar los cuatro puntos.
4. `CHANGELOG.md`: sección `## [1.3.0] - 2026-09-04` + actualizar los links del pie.
5. Verificar con instalación limpia.

## Tasks

- [x] T1 Añadir `before_tasks` a `extension.yml#hooks`
- [x] T2 Añadir `before_clarify` a `extension.yml#hooks`
- [x] T3 Bump `extension.version` → `1.3.0`
- [x] T4 Retitular y ampliar la § de integración del README a los 4 hooks
- [x] T5 Entrada `[1.3.0]` en CHANGELOG + links del pie
- [x] T6 `specify extension add <path> --dev` en proyecto limpio → confirmar los 4 hooks

## Done When

- [x] Todas las tareas marcadas
- [x] El `.specify/extensions.yml` del proyecto de prueba lista los 4 hooks
- [x] `specify extension list` reporta `knowledge 1.3.0`

## Nota — coste por ciclo

Pasar de 2 a 4 hooks implica hasta 4 clone/fetch por ciclo de feature. Los cuatro son `optional: true` (el usuario puede declinar), pero el arreglo real es el TTL `max_age` que quedó diferido al SDD completo. Si ese trabajo entra pronto, considera publicar 1.3.0 junto con él en vez de por separado.
