# OpenVault

## graphify

Este repo tiene un grafo de conocimiento generado con [graphify](https://github.com/safishamsi/graphify) en `graphify-out/`. Cubre código (AST de Swift/Python), docs e imágenes de marca, con comunidades detectadas y cada relación marcada como `EXTRACTED`, `INFERRED` o `AMBIGUOUS`.

Cómo lo usamos:

- **Antes de responder preguntas sobre la arquitectura o el código**, lee `graphify-out/GRAPH_REPORT.md` (nodos más conectados y comunidades) y consulta el grafo antes de recorrer archivos a mano:
  - `/graphify query "<pregunta>"` — contexto amplio (BFS); agrega `--dfs` para seguir una cadena concreta.
  - `/graphify path "<A>" "<B>"` — camino más corto entre dos conceptos.
  - `/graphify explain "<nodo>"` — todo lo que conecta con un nodo.
- **Responde solo con lo que el grafo contiene.** Las relaciones `INFERRED` y `AMBIGUOUS` son hipótesis: verifícalas en el código antes de afirmarlas.
- **Después de cambiar código o docs de forma relevante**, corre `/graphify . --update` (solo re-extrae lo que cambió; si el cambio es solo de código no usa LLM) y sube `graphify-out/` junto con el cambio.
- **Reconstrucción completa:** `/graphify .`. Las imágenes de `assets/brand/` son variantes del mismo ícono: agrúpalas por formato en vez de lanzar un agente por imagen.

Se versionan `GRAPH_REPORT.md`, `graph.html` y `graph.json`. La caché, `manifest.json`, `cost.json` y los archivos `.graphify_*` son locales (contienen rutas absolutas) y están en `.gitignore`.
