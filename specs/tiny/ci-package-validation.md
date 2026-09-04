# TinySpec: CI que valida el paquete y hace smoke test de instalación

**Branch**: 005-ci-validation (mergeada) · **PR**: [#3](https://github.com/rnoap/spec-kit-shared-knowledge/pull/3)
**Date**: 2026-09-04
**Status**: done
**Complexity**: small

## What

La constitución decía, en §III: *"No CI/CD pipeline exists yet; quality gates are
manual."* Eso fue la causa raíz del release v1.2.0 — ocho defectos llegaron a
`main`, y **cuatro se encontraron solo porque alguien instaló la extensión a
mano**. Un gate que nada obliga a ejecutar no es un gate.

Automatizar lo que sí es mecánicamente comprobable: el manifest, el resultado de
la instalación y el artefacto publicado. No la conducta de los comandos — ver
§ Fuera de alcance.

## Context

| File | Role |
|------|------|
| [.github/workflows/validate.yml](../../.github/workflows/validate.yml) | Nuevo — 2 jobs, en cada PR y en push a `main` |
| [.github/scripts/validate-extension.sh](../../.github/scripts/validate-extension.sh) | Nuevo — 13 checks estáticos, ejecutable también en local |
| [.specify/memory/constitution.md](../../.specify/memory/constitution.md) | Modificar — §III, § Quality Gates, § Code Boundaries, § Governance |

`.github/` ya está en `.gitattributes` (`export-ignore`) y en `.extensionignore`,
así que nada de esto llega al consumidor ni al archivo publicado. Verificado: 0
entradas en `git archive`.

## Requirements

1. Cada check nombra el blocker real que habría cazado. Un validador cuyo motivo
   no se puede rastrear se borra en el primer falso positivo.
2. Las aserciones del smoke test derivan del **manifest**, no de números fijos:
   añadir un sexto comando no debe requerir editar el CI.
3. El script estático corre **en local** sin GitHub. El gate más barato es el que
   se ejecuta antes de hacer push.
4. `permissions: contents: read`. El workflow no necesita más.
5. spec-kit **fijado a un tag**, no a `main`.
6. Dos invariantes del repo pasan de confiadas a mecánicas:
   - Ningún hook declara argumentos (eso *es* FR-022 — mantiene `--force`
     inalcanzable desde un trigger automático). Antes lo garantizaba un
     comentario YAML pidiendo por favor.
   - El bloque *Configuration Validation Rules* es byte-idéntico en los tres
     comandos que lo duplican. §I prohíbe extraerlo a un archivo compartido, así
     que duplicar solo es seguro mientras no pueda divergir.
7. La constitución deja de afirmar que no hay CI, y declara **qué no cubre**.

## Plan

1. `validate-extension.sh` con 13 checks agrupados en cinco secciones, cada uno
   con el blocker anotado en el código.
2. `validate.yml` con dos jobs: `validate` (rápido, sin CLI) y `smoke` (instala
   spec-kit y hace `extension add` real en un proyecto limpio).
3. **Negative-test del validador**: reintroducir cada defecto y confirmar que
   falla. Un validador que solo se ha visto pasar no está verificado.
4. Enmendar la constitución a 1.1.0 con la razón registrada en el propio archivo.
5. Abrir PR y comprobar que el workflow corre **sobre sí mismo**.

## Decisiones

**spec-kit fijado a `v1.0.4`, no a `main`.** Sin fijar, un cambio incompatible de
upstream aterriza como rojo en un PR que no tiene nada que ver, y el autor pierde
el tiempo depurando su propio cambio. No es hipotético: durante el desarrollo de
1.4.0, `specify init --ai` pasó a ser `--integration`, y el primer smoke test
falló por eso. El coste aceptado es que ya no te enteras solo de que upstream te
rompió — te enteras al subir esa línea a propósito, y entonces sabes exactamente
qué fue. Si se quiere lo uno y lo otro, un job programado semanal contra `main`
puede ponerse rojo sin bloquear PRs.

**Los `[P]` no aplican.** Los dos jobs son independientes y GitHub ya los corre
en paralelo.

**Duplicar las reglas de validación sigue siendo correcto.** El check 13 no
sugiere refactorizar hacia un archivo común: spec-kit no lo instalaría y todos
los comandos romperían en runtime. Lo que hace es hacer segura la duplicación.

## Tasks

- [x] T1 `validate-extension.sh` — 13 checks, cada uno anotado con su blocker
- [x] T2 `validate.yml` — job `validate` y job `smoke`, `contents: read`
- [x] T3 Aserciones del smoke derivadas del manifest, no hardcodeadas
- [x] T4 Negative-test: 6 defectos reintroducidos, los 6 cazados
- [x] T5 Constitución → 1.1.0, con la razón registrada inline
- [x] T6 PR abierto; workflow verde sobre sí mismo (validate 4s, smoke 10s)
- [x] T7 Subir actions a v5/v6 y desactivar la caché de uv (inservible aquí)
- [x] T8 Branch protection: los dos checks pasan a **required**

## Done When

- [x] `bash .github/scripts/validate-extension.sh` da 13/13 en local
- [x] Ambos jobs verdes en runners reales
- [x] `git archive` sigue sin contener `.github/`
- [x] La constitución ya no dice que no hay CI
- [x] Los checks son **bloqueantes**, no solo informativos

## Lo que encontró probar el propio test

Contar todos los bullets del output de instalación daba **6** comandos en vez de
5: el config scaffolded también va con bullet. Habría sido **rojo falso en cada
PR correcto**. Corregido a `grep -cE '• speckit\.'`.

Es el argumento entero a favor de T4. Un validador que solo se ha visto pasar no
está verificado — está sin probar.

## Fuera de alcance

**Nada de esto comprueba qué *hace* un comando.** Los prompts de agente los
interpreta un modelo en runtime, así que no hay compilador ni linter que atrape
una instrucción contradictoria: simplemente produce comportamiento incorrecto en
silencio. El `quickstart.md` de cada feature sigue siendo la única verificación
de conducta.

**CI protege el paquete, no la prosa.** Está escrito así en § Quality Gates para
que nadie confunda un build verde con una feature que funciona.

## Pendiente

- La anotación *"Node.js 20 is deprecated"* viene de `astral-sh/setup-uv`, que
  aún declara `node20` en su propio `action.yml`. No se puede cambiar desde este
  workflow. Es warning, no fallo; se va cuando upstream publique un build Node 24.
- `strict: true` en la protección exige que la rama esté al día antes de mergear.
  Con un solo mantenedor es fricción menor; protege del caso "PR verde que rompe
  al mergear".
