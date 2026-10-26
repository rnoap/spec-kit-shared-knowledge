# Contract: `.manifest.json`

**Feature**: [../batch-corpus-measurement.spec.md](../batch-corpus-measurement.spec.md) · **Plan**: [../plan.md](../plan.md) · **Research**: [../research.md](../research.md) · **Data model**: [../data-model.md](../data-model.md)

The manifest keeps its path, its keys and its schema version (FR-010), so every reader that parses JSON reads it as today.
What changes is the writer and the bytes.
The record run writes the manifest from a shell, and for a given cache exactly one text is valid: the text that run renders.
The Cache Integrity Check renders that text again and compares bytes ([commands.md § 2.4](./commands.md#24-the-check-tail-cache-integrity-check)).

---

## 1. Path and keys, unchanged

| Aspect | Contract |
| --- | --- |
| Path | `.specify/extensions/knowledge/cache/<slug>/.manifest.json`: the manifest path, unchanged |
| `schema_version` | Stays `"1.0"` |
| Top-level keys, in this order | `schema_version`, `source_url`, `source_slug`, `revision`, `synced_at`, `item_count`, `items` |
| Per-item keys, in this order | `path`, `sha256` |
| Writer | The record run's step 6 block. The agent types nothing into the manifest (FR-001) |
| `knowledge-index.md` | Stays agent-written, with the file tool, never through a shell (FR-014, FR-019) |

No key is added, removed, renamed or retyped.
Item sizes reach the agent in the run report ([commands.md § 3](./commands.md#3-report-lines)) and never enter the manifest.

---

## 2. Canonical text

The layout of today's step 6 example, made exact ([research D6](../research.md#d6-canonical-manifest-written-atomically)):

```text
{
  "schema_version": "1.0",
  "source_url": <source_url>,
  "source_slug": "<slug>",
  "revision": <revision>,
  "synced_at": "<synced_at>",
  "item_count": <N>,
  "items": [
    {"path": <path>, "sha256": "<sha256>"},
    {"path": <path>, "sha256": "<sha256>"}
  ]
}
```

- UTF-8 with no byte-order mark. Every line ends in one line feed, the closing `}` included. No carriage return, no tab, no trailing space.
- Top-level keys are indented two spaces, item lines four.
- One space follows each `:` and the `,` between `path` and `sha256`. No other optional space appears.
- Every item line but the last ends in `,`.
- With no item, the `items` line reads `  "items": []`, and no item line or `  ]` follows.
- Items appear in byte order of their raw path, the order of `$items` under `LC_ALL=C`.

| Key | Value | Written as |
| --- | --- | --- |
| `schema_version` | `"1.0"` | That literal |
| `source_url` | The configured `url` as configured: not normalized, and a local path not expanded | JSON string (§ 3) |
| `source_slug` | The slug, 12 lowercase hex characters | JSON string |
| `revision` | The configured `revision` | JSON string (§ 3), or a bare `null` when none is pinned |
| `synced_at` | The record run's time, from `date -u +%Y-%m-%dT%H:%M:%SZ` | JSON string. Its line matches `^  "synced_at": "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z",$` |
| `item_count` | The number of item lines | Decimal digits; `0` when there is no item |
| `items[].path` | The item's path relative to the cache root, with no leading `./` | JSON string (§ 3) |
| `items[].sha256` | SHA-256 of the item's content | 64 lowercase hex characters |

---

## 3. Strings

The encoder receives every name and value as hex bytes from `od` ([research D5](../research.md#d5-the-encoder-reads-hex-not-text)) and writes it as below.
This is what FR-004 means by escaped as JSON requires.

| Byte | Written as |
| --- | --- |
| `"`, 22 | `\"` |
| `\`, 5C | `\\` |
| 08 | `\b` |
| 0C | `\f` |
| 0A | `\n` |
| 0D | `\r` |
| 09 | `\t` |
| Any other byte from 01 to 1F | `\u00XX`, two hexadecimal digits in upper case: 1B is `\u001B` |
| Every other byte: printable ASCII, `/`, 7F, and each byte of a valid UTF-8 sequence | As is |

- No other escape appears: no `\/`, and no `\u` escape above 1F. `guía.md` is written `guía.md`.
- A path never holds 0A, because § Indexable Items leaves such paths out. A source value holds one only when validation was bypassed.
- A path that is not valid UTF-8 never reaches the manifest ([commands.md § 2.2](./commands.md#22-item-records-new)), so the manifest is always valid UTF-8.

---

## 4. Examples

The source `https://github.com/org/payment-service`, unpinned, recorded on Linux.
Its third item's name is `specs/a"b\c`, a tab, then `d.md`; its fifth holds an escape character, U+001B.
The source also holds two symbolic links and `specs/caf\xE9.md`, none of which is an item.
[commands.md § 3](./commands.md#3-report-lines) shows the report of the same run.

```json
{
  "schema_version": "1.0",
  "source_url": "https://github.com/org/payment-service",
  "source_slug": "18dbb51ec4eb",
  "revision": null,
  "synced_at": "2026-10-26T14:00:00Z",
  "item_count": 6,
  "items": [
    {"path": "$(touch pwned).md", "sha256": "ee0896e6aa3b082ec1c00b3f8176f132fad38d88a659994d889acf5a58e3f59a"},
    {"path": "-option.md", "sha256": "b2cc9038eb1eac8a0cc11f3c484603fb9afc519b3a94b4b251b1f6b4f76d7461"},
    {"path": "specs/a\"b\\c\td.md", "sha256": "6cdeceab0b5160232f7d77755436e905adc3420a2611dc3e8854c7f3d9e227e4"},
    {"path": "specs/api.md", "sha256": "9038e328a47f981eb88244c71986da1de14f6d269663be79a76aa1a94e6eb587"},
    {"path": "specs/esc\u001Bape.md", "sha256": "e1d48029c6c358af0b840f69d7cd76024b907903fce27de54967bd6001b354d3"},
    {"path": "specs/guía.md", "sha256": "221bdff142e349df58e6ae81f6ed2d1e92514b3bb9e573ddfc603e729959df22"}
  ]
}
```

The same URL pinned to `v2.4.1`, with no item:

```json
{
  "schema_version": "1.0",
  "source_url": "https://github.com/org/payment-service",
  "source_slug": "5e8b13c49fbe",
  "revision": "v2.4.1",
  "synced_at": "2026-10-26T14:00:00Z",
  "item_count": 0,
  "items": []
}
```

---

## 5. Writing

| Rule | Contract | Req |
| --- | --- | --- |
| Last | Written after every item of the source is in place. Its mtime marks when the cache became valid, and the Cache Freshness Gate reads it | FR-009 |
| Whole or absent | Rendered into `.manifest.json.tmp` in the cache root, then `mv -f` onto `.manifest.json` | FR-008 |
| Temporary file | Never read. It does not end in `.md`, so it is never an item. The next record run writes over one an interrupted run left behind | D6 |
| Every item | Lists every recorded item, whatever the context budget | FR-003 |
| One renderer | § Item Records defines it, and both the record tail and the check tail call it, so a manifest just written passes the check | FR-007 |

---

## 6. Reading

- A reader that parses JSON reads the manifest as today (FR-010).
  Search's corpus is the combined `items[]` of the manifests that pass the check, and status shows `synced_at` and the item count of a source that passes.
- The check parses no JSON. It reads the `synced_at` line, renders the canonical text and runs `cmp`.
  A manifest byte-identical to the writer's own output is valid JSON whose records match their files.

---

## 7. Compatibility

| Manifest found | Under 1.10.0 |
| --- | --- |
| Written by the 1.10.0 record run | Passes while the files, and the source's `url` and `path_filter`, are unchanged |
| Written by the agent under 1.9.1 or earlier | Passes only if byte-identical to the canonical text for its files. Otherwise it fails once, and the next successful sync records it again (FR-013, SC-007) |
| Written by 1.3.0, with no `revision` key | Always takes that one rebuild. The note in sync step 6 that such a manifest needs no re-sync is rewritten ([research D7](../research.md#d7-the-check-renders-and-compares-callers-act)) |
| Reformatted, reordered or edited by hand | Fails. It is never served with records that do not match |
| Only `.manifest.json.tmp`, left by an interrupted run | No manifest: the directory is an interrupted sync ([commands.md § 5.2](./commands.md#52-path-choice)) |

Every upgrade already empties the cache, so an older manifest costs no more than an upgrade does today.
