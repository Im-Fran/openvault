# OpenVault

## graphify

This repo uses a knowledge graph generated with [graphify](https://github.com/safishamsi/graphify) in `graphify-out/`. It is not versioned: each person generates it locally with `/graphify .` (if `graphify-out/` doesn't exist, generate it before using it). It covers code (Swift/Python AST), docs and brand images, with detected communities and every relationship tagged as `EXTRACTED`, `INFERRED` or `AMBIGUOUS`.

How we use it:

- **Before answering questions about the architecture or the code**, read `graphify-out/GRAPH_REPORT.md` (most connected nodes and communities) and query the graph before walking files by hand:
  - `/graphify query "<question>"` — broad context (BFS); add `--dfs` to follow a specific chain.
  - `/graphify path "<A>" "<B>"` — shortest path between two concepts.
  - `/graphify explain "<node>"` — everything connected to a node.
- **Answer only with what the graph contains.** `INFERRED` and `AMBIGUOUS` relationships are hypotheses: verify them in the code before stating them.
- **After meaningful code or docs changes**, run `/graphify . --update` (it only re-extracts what changed; code-only changes don't use an LLM) to keep your local graph up to date.
- **Full rebuild:** `/graphify .`. The images in `assets/brand/` are variants of the same icon: group them by format instead of launching one agent per image.

All of `graphify-out/` is in `.gitignore`.

## Localization

English is the source language; Latin American Spanish (`es-419`) is the secondary language.

- UI strings live in `App/Sources/Localizable.xcstrings`. Write new user-facing strings in English and add their `es-419` translation to the catalog.
- Strings that aren't SwiftUI literals use `String(localized:)`.
- `OpenVaultCore` messages use `String(localized:)`, resolved from the app bundle. The `ovault` CLI is English-only.
- Docs have `.es.md` twins (e.g. `README.md` / `README.es.md`); keep both in sync when editing either.
