# TinySpec: Quitar `sparse-checkout reapply` del warm path (git 2.25)

**Branch**: main · **Commit**: e727748
**Date**: 2026-10-15
**Status**: done
**Complexity**: small

## What

Cuando hay `path_filter`, el warm path de `sync` ejecutaba `git sparse-checkout reapply` después de `set`. Ese subcomando no existe en git 2.25, el mínimo que declara la extensión. Allí sale con 129, y un agente puede tomar el warm sync como fallido y quedarse con la caché vieja.

Lo encontró la primera ejecución de `test-sync-git.sh` en git 2.25.1, en `ubuntu:20.04` con Podman, después del PR #9.

## Context

| File | Role |
| --- | --- |
| [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md) | Modificar: quitar `reapply` del warm path y añadir una nota para que no vuelva |
| [.github/scripts/test-sync-git.sh](../../.github/scripts/test-sync-git.sh) | Modificar: 2 checks nuevos (de 35 a 38) |
| [CHANGELOG.md](../../CHANGELOG.md) | Modificar: entrada `Fixed` en `[Unreleased]` |
| [.specify/bugs/knowledge-sync-defects/fix.md](../../.specify/bugs/knowledge-sync-defects/fix.md) | Modificar: verificación en git 2.25 y follow-up cerrado |

## Requirements

1. El paso sparse del warm path sale con 0 en git 2.25.
2. Una caché clonada en modo cone, que tiene archivos de la raíz, los pierde en su siguiente warm sync, igual que con `reapply`.
3. El resto no cambia: los 35 checks previos siguen pasando en git 2.25 y en el git actual.

## Plan

1. Quitar `git sparse-checkout reapply` y su comentario. `sparse-checkout set`, que corre justo antes, ya actualiza el árbol de trabajo.
2. Dejar una nota en el comando para que nadie lo vuelva a añadir.
3. Añadir al script un escenario con una caché en modo cone.
4. Ejecutar el script en macOS (git 2.54) y en `ubuntu:20.04` (git 2.25.1). Ejecutarlo también contra el `sync.md` anterior en 2.25, para comprobar que el check nuevo detecta el fallo.

## Decisiones

**Quitar la línea en lugar de tolerar el error** (`reapply 2>/dev/null || true`). La línea era redundante, porque `set` ya hace ese trabajo. Mantenerla solo serviría para ocultar un error en las versiones donde no existe.

**El check comprueba el código de salida del paso, no solo el resultado.** En 2.25 el resultado ya era correcto con la línea puesta: `set` había hecho el trabajo antes del error. Lo que fallaba era la salida 129, así que un check que solo mirara el resultado habría pasado con el bug.

## Tasks

- [x] T1 Quitar `reapply` del warm path y añadir la nota
- [x] T2 Checks nuevos: el paso sparse sale con 0, y una caché cone pierde sus archivos de la raíz
- [x] T3 Entrada en `CHANGELOG.md` y actualización de `fix.md`
- [x] T4 Commit `e727748` en `main`

## Done When

- [x] `test-sync-git.sh` pasa 38/38 en git 2.54 (macOS) y en git 2.25.1 con GNU `timeout` (`ubuntu:20.04`)
- [x] Con el `sync.md` anterior en git 2.25, falla el check del paso sparse
- [x] `validate-extension.sh` pasa 13/13 (con un `python3` que tenga PyYAML)
