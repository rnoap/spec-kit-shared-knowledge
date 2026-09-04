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
| [.github/workflows/validate.yml](../../.github/workflows/validate.yml) | Nuevo — 2 jobs, en cada PR y en push a `main`. **Bloqueante** |
| [.github/workflows/upstream-compat.yml](../../.github/workflows/upstream-compat.yml) | Nuevo — mismo smoke test contra spec-kit `main`, semanal. **Advisory** |
| [.github/scripts/validate-extension.sh](../../.github/scripts/validate-extension.sh) | Nuevo — 13 checks estáticos, ejecutable también en local |
| [.github/scripts/assert-install.sh](../../.github/scripts/assert-install.sh) | Nuevo — aserciones del smoke, compartidas por los dos workflows |
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

**spec-kit fijado a `v1.0.4`, no a `main` — y un job aparte que sí mira `main`.**
Sin fijar, un cambio incompatible de upstream aterriza como rojo en un PR que no
tiene nada que ver, y el autor pierde el tiempo depurando su propio cambio. No es
hipotético: durante el desarrollo de 1.4.0, `specify init --ai` pasó a ser
`--integration`, y el primer smoke test falló por eso.

Pero fijar tiene su propio modo de fallo: dejas de enterarte de que upstream te
rompió, hasta el día que subes el pin y heredas todo el destrozo de golpe. Por eso
`upstream-compat.yml` corre el **mismo** smoke test contra `main` semanalmente.
Puede ponerse rojo sin molestar a nadie: no se dispara en `pull_request` y no es
un check requerido. Un rojo ahí significa una sola cosa — upstream cambió algo del
que esta extensión depende; decide, y sube `SPEC_KIT_REF` a propósito.

**Las aserciones del smoke viven en un solo archivo.** `assert-install.sh` lo usan
los dos workflows. Si se duplicaran, el job de compatibilidad podría pasar un
check que el bloqueante ya no hace — peor que no tenerlo. Aquí sí se extrae,
porque son scripts de CI: la prohibición de §I aplica al paquete instalado, no a
esto.

**El runtime de una action no se elige desde el workflow.** Lo declara ella en su
`action.yml` (`runs.using`), y `actions/setup-node` no lo cambia — eso prepara
Node para *tu* código, no para el runtime de las actions de terceros. La primera
versión de este CI fijó `setup-uv@v6`, que declara `node20`, y se documentó el
warning resultante como "se irá cuando upstream publique un build node24". Era
falso: `v7.0.0` se titula *"node24 and a lot of bugfixes"* y ya existía. El
warning era nuestra versión vieja, cuatro majors atrás. Ahora `v10.0.1`; los
cambios de v9/v10 solo tocan defaults de caché, irrelevantes con
`enable-cache: false`.

**Versión exacta, no major flotante.** `setup-uv` dejó de publicar tags mayores
en `v8.0.0` (*"Immutable releases and secure tags"*): `v7` es la última que
existe, y `@v10` no resuelve. El primer intento de este bump usó `@v10` y falló
en 3 segundos — el CI cazando un error del propio CI. Fijar exacto era además lo
correcto: en su esquema esas tags son inmutables.

**Auditar todas las actions, no solo la que aviso.** Al comprobar que cada `uses:`
resolvía de verdad, apareció una segunda con `node20` que nadie había mirado:
`actions/upload-artifact@v5`. Sube a `v7`. La lección es que perseguir la
anotación concreta que sale en pantalla deja atrás las que aún no han saltado.

**Los `[P]` no aplican.** Los dos jobs de `validate.yml` son independientes y
GitHub ya los corre en paralelo.

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
- [x] T9 Extraer `assert-install.sh` — una sola copia para los dos workflows
- [x] T10 `upstream-compat.yml` — smoke semanal contra spec-kit `main`, advisory

## Done When

- [x] `bash .github/scripts/validate-extension.sh` da 13/13 en local
- [x] Ambos jobs verdes en runners reales
- [x] `git archive` sigue sin contener `.github/`
- [x] La constitución ya no dice que no hay CI
- [x] Los checks son **bloqueantes**, no solo informativos
- [x] `upstream-compat` no se dispara en `pull_request` — verificado, no puede
      bloquear a nadie

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

- `strict: true` en la protección exige que la rama esté al día antes de mergear.
  Con un solo mantenedor es fricción menor; protege del caso "PR verde que rompe
  al mergear".
- `upstream-compat` aún no ha corrido en su horario — se dispara el primer lunes
  a las 06:00 UTC. Se puede forzar antes con `gh workflow run upstream-compat.yml`.
