---
name: web-search
description: Live web search and URL content fetching. Use whenever the user asks to search the web, look up current/recent facts, verify external information, read a website, or cite online sources.
---

# Web Search

Use the `web` command. It is a real command, not a model-internal capability.

## Commands

```bash
web search "query"              # search and print source URLs/snippets
web search "query" -n 10        # more results
web search "query" --content    # include fetched page content for each result
web fetch https://example.com    # fetch readable markdown for a URL
```

The same script is also available at:

```bash
{baseDir}/web search "query"
{baseDir}/web fetch https://example.com
```

## Rules

- For current facts, run `web search` first, then `web fetch` on an official or high-quality source.
- Cite the returned URLs in your answer.
- Do not answer from memory while saying you searched.
- If the command fails or the results are inconclusive, say so clearly and ask whether to try another source.
- Do not run `pi skill search`; that starts another model session and is not a web search.
- Do not run nonexistent commands such as `web search` unless this installed `web` command is on PATH or you use `{baseDir}/web`.

## Backends

The command uses, in order:

1. Brave Search API if `BRAVE_API_KEY` is set.
2. Jina Search if `JINA_API_KEY` is set.
3. Yahoo Search HTML fallback.
4. Wikipedia search fallback if general web search fails.

The output shows which backend was used and the fetch timestamp.
