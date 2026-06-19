# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

雪峰Agent is an AI-powered Gaokao (Chinese college entrance exam) application advisor. It's a **single-file Python web server** (`server.py`, ~430 lines) that embeds a complete HTML/CSS/JS chat SPA (~250 lines of JS). No framework, no build step, no npm, no tests. There's also a CLI chatbot (`agent.py`, ~645 lines) as a legacy/alternative interface.

Core value: a local **42-million-record SQLite database** of official admission data (24 provinces, 2024-2025) combined with system prompts encoding Zhang Xuefeng's advisory methodology from 8 books and 61 video lessons.

## Run

```bash
python server.py          # Starts HTTP server on port 8765, opens in browser
python agent.py           # CLI mode (requires: pip install openai pywin32)
```

On Windows, double-click `启动.bat` (runs `py -3 server.py || python server.py`).

On first run, `admission_clean.db.gz` (29 MB) auto-decompresses to `admission_clean.db` (143 MB).

## Architecture

### Data pipeline

```
User input → regex extract (province/rank/score/major) → local SQLite query
  → /recommend API (冲/稳/保 tier matching) → web search (Tavily API, Baidu fallback)
  → combined data sent to LLM → response with per-school [DB]/[联网] source labels
```

### Server API endpoints (`server.py`)

| Endpoint | Description |
|----------|-------------|
| `GET /ping` | Health check `{"ok":true,"db":true/false}` |
| `GET /query?province=&school=&major=` | Raw DB query |
| `GET /recommend?province=&rank=&score=&keyword=` | Core recommendation engine — returns `chong`/`wen`/`bao` arrays |
| `GET /search?q=` | Web search (Baidu scraping, mostly non-functional; Tavily is called client-side) |
| `GET /` | Serves the complete HTML/CSS/JS SPA |
| `GET /img_suit.png`, `GET /img_scifi.png` | Avatar images |

### Recommendation tier logic (`server.py:86-138`)

**冲 (Reach)**: rank between `user_rank * 0.85` and `user_rank`
**稳 (Match)**: rank between `user_rank` and `user_rank * 1.3`
**保 (Safety)**: rank between `user_rank * 1.3` and `user_rank * 1.6`

Rank-based search first; falls back to score-based if rank returns nothing. Each tier falls back to broader search without keyword filter if the keyword-filtered query is empty.

### Frontend (`server.py:173-421`, embedded in `HTML_PAGE` string)

- Vanilla JS with no dependencies — direct `fetch()` to OpenAI-compatible `/v1/chat/completions`
- All state in `localStorage`: conversations (`xf_chats`), API config (`cf_url`, `cf_key`, `cf_model`, `cf_tavily`), mode (`xf_mode`), dark mode (`xf_dark`)
- Two modes: **报考** (gaokao) uses `PG` system prompt; **娱乐** (fun) uses `PF` system prompt
- Regex-based info extraction (`extractInfo()` in JS) extracts province/rank/score/major from user input without LLM
- Web search: Tavily API preferred (client-side fetch to `api.tavily.com`), falls back to Baidu via server `/search` endpoint
- Province-aware slot counts (e.g., Zhejiang=80, Shandong=96, Jiangsu=40) auto-injected into system prompt

### CLI chatbot (`agent.py`)

Uses the `openai` Python SDK. `GaokaoAdvisor` class manages conversation state with a slot-filling state machine (province, rank, score, major preference, family background). Commands: `/paste`, `/reset`, `/slots`, `/quit`. Has `cleanup_format()` to strip markdown from LLM output for terminal display.

## Key prompt files

- `system_prompt.md` — Main advisor system prompt (280 lines): personality definition, consultation process, 5 information slots (硬分/兴趣/地域/家庭/诉求), truthfulness rules
- `prompt_fun.md` — "Fun mode" persona (Zhang Xuefeng brash Northeastern Chinese style)
- `knowledge_base.md` — 17-module knowledge base (837 lines) covering admission methodology, major analysis, school tiers, employment trends, province policies

The frontend embeds minified/concatenated versions of these prompts directly in the JS (variables `PG` and `PF`), so changes to the `.md` files require syncing them into `server.py`'s `HTML_PAGE` string.

## Database

- `admission_clean.db` (143 MB, auto-decompressed from `admission_clean.db.gz` on first run)
- Table `admission`: `province, year, school_name, major_name, score, rank`
- 42M records across 24 provinces (2024-2025), sourced from provincial education exam authorities
- `rebuild_db.py` rebuilds the DB from raw Excel/PDF source files
- `clean_data.py` validates and cleans the DB

## Configuration

- No `.env` file required — all settings are entered in the browser UI and stored in `localStorage`
- `.env.example` exists for the CLI `agent.py` (uses `LLM_API_KEY`, `LLM_BASE_URL`, `LLM_MODEL` or `LLM_PROVIDER` shortcut)
- Any OpenAI-compatible API works: DeepSeek (⭐ default/recommended), Qwen, GLM, GPT-4o, Ollama

## File summary

| File | Purpose |
|------|---------|
| `server.py` | Main app: HTTP server + embedded SPA UI (single-file, no dependencies) |
| `agent.py` | CLI chatbot (alternative interface, requires `openai` package) |
| `admission_clean.db.gz` | Compressed SQLite database (auto-extracted on first run) |
| `system_prompt.md` / `prompt_fun.md` / `knowledge_base.md` | LLM prompt source files (embedded into server.py) |
| `rebuild_db.py` | Database builder from raw data |
| `clean_data.py` | Database cleaning/validation |
| `gaokao_data.py` | Web scraping for live Gaokao data |
| `启动.bat` | Windows one-click launcher |
