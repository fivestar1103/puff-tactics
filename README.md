# Puff Tactics

**Tactical Feed** — Swipe like Shorts, solve like puzzles, addicted by cuteness.

> *"People didn't quit games. They just moved to something that gives faster dopamine with less effort."*

Puff Tactics is a mobile tactical puzzle game that steals the UX of TikTok/Shorts and fills it with real gameplay. Open the app — no menus, no loading — a battlefield snapshot appears instantly. Make one tactical decision. See the result. Swipe up. Next battlefield. Infinite loop.

<p align="center">
  <img src="https://img.shields.io/badge/Engine-Godot%204.6-478cbf?style=for-the-badge&logo=godotengine&logoColor=white" />
  <img src="https://img.shields.io/badge/Backend-Supabase-3fcf8e?style=for-the-badge&logo=supabase&logoColor=white" />
  <img src="https://img.shields.io/badge/Platform-iOS-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/Language-GDScript-355570?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Dev%20Method-Ralph%20Loop-ff6b6b?style=for-the-badge" />
</p>

---

## The Concept

| | Shorts / Reels | Puff Tactics |
|---|---|---|
| Cold start | 0s (video plays) | 0s (battlefield appears) |
| One session | 15s (1 video) | 15–30s (1 tactical decision) |
| User role | Passive consumer | Active decision-maker |
| After session | Time wasted + guilt | Achievement + growth |
| Content source | Creator-dependent | Player battles + procedural + UGC |

**One-line pitch:** Consume tactical puzzles in a feed. Open → battlefield → 1 turn → swipe → next battlefield → infinite repeat.

---

## Core Mechanics

### The Feed (Primary Loop)
The app opens directly into a vertical swipe feed — no menus. Each feed item is a bite-sized tactical situation where you make exactly one turn of decisions. Three content sources fill the feed:

- **Decisive Moments** — AI extracts the most impactful turn from real player battles. You're dropped into that exact moment. Can you do better than the original player?
- **Micro-Puzzles** — Procedurally generated tactical puzzles. "Push 2 enemies off the cliff." "Heal all allies in 1 turn." Hundreds generated daily.
- **UGC Puzzles** — Community-created scenarios ranked by solve rate and likes.

### Bump Physics
The core differentiator. Every puff can push adjacent opponents. Pushes chain — if A pushes B into C, C gets pushed too. Fall off a cliff edge? One-turn knockout. One simple mechanic creates infinite tactical depth.

### Into the Breach-Style Information
Enemy intentions are shown transparently before your turn. Where they'll move, who they'll attack — all visible. This isn't a guessing game. It's pure strategy.

---

## The World

**Puffland** — a floating world of clouds, cotton candy, and mushrooms. The creatures that live here are called **Puffs** — round, squishy, pastel-colored spirits. Their "battles" aren't violent — they bonk each other, bounce around, and roll off cloud edges. Nobody gets hurt. They just go *poof*.

### Puff Classes

| Puff | Role | Move | Range | Unique Skill |
|---|---|---|---|---|
| Cloud Puff | Tank | 2 | 1 | **Cloud Wall** — adjacent allies get +2 defense |
| Flame Puff | Melee DPS | 3 | 1 | **Pop Sting** — attack pushes target 1 tile |
| Droplet Puff | Ranged | 2 | 3 | **Water Stream** — pulls target 1 tile closer |
| Leaf Puff | Healer | 2 | 2 | **Breeze** — AoE heal + buff |
| Whirl Puff | Mobility | 4 | 1 | **Gust** — pushes all enemies along move path |
| Star Puff | Wildcard | 3 | 2 | **Twinkle** — random element attack (ignores affinity) |

### Elements
Fire > Grass > Wind > Water > Fire. Star is neutral.

### Visual Style
Soft, rounded, pastel, cozy, bouncy. Kawaii-meets-Scandinavian. Lavender `#957DAD` · Mint `#A8D8B9` · Peach `#FFD6BA` · Sky `#A0C4FF` · Pink `#E8A0BF`

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   iOS App                        │
│              Godot 4.6 + GDScript                │
├──────────┬──────────┬──────────┬────────────────┤
│  Feed    │  Battle  │  Puffs   │  UI            │
│  System  │  System  │  System  │  (Swipe Feed)  │
├──────────┴──────────┴──────────┴────────────────┤
│              Supabase Backend                    │
│  Auth · PostgreSQL · Edge Functions · Storage    │
└─────────────────────────────────────────────────┘
```

### Tech Stack

| Layer | Choice | Why |
|---|---|---|
| Engine | Godot 4.6 | iOS-stable, excellent 2D, open source |
| Language | GDScript | Fast iteration, engine-native |
| Rendering | 2D Isometric TileMap + Y-Sort | Sprite-based 3D feel |
| Backend | Supabase | Auth, DB, Edge Functions, Realtime — all-in-one |
| UI Paradigm | Vertical swipe + bottom FAB | Shorts-app UX |
| iOS | Godot iOS export + Xcode | StoreKit 2 IAP, Apple Sign-In |

---

## Development Method: Ralph Loop

This project is built using the **Ralph Loop** — an autonomous AI agent development methodology where a coding agent runs in a loop, picking tasks from a PRD and implementing them one by one until everything is done.

```
┌──────────────────────────────────────────┐
│  Orchestrator (Claude Code)              │
│  • Maintains PRD and task dependencies   │
│  • Reviews commits, catches bugs         │
│  • Updates AGENTS.md with learnings      │
│  • Course-corrects when things go wrong  │
└────────────────┬─────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────┐
│  Executor (Codex CLI — Ralph Loop)       │
│  while stories_remain:                   │
│    1. Read PRD + AGENTS.md + progress    │
│    2. Pick next uncompleted story        │
│    3. Implement + validate               │
│    4. Commit + update tracking           │
│    5. Exit → fresh context → repeat      │
└──────────────────────────────────────────┘
```

### Running the Ralph Loop

```bash
# Default: Codex agent, 50 iterations
./ralph/ralph.sh

# Use Claude Code instead
./ralph/ralph.sh --agent claude

# Custom iteration count
./ralph/ralph.sh --agent codex 30
```

### Key Files

| File | Purpose |
|---|---|
| `ralph/prd.json` | User stories with acceptance criteria and pass/fail status |
| `ralph/prompt.md` | Prompt fed to the agent each iteration |
| `ralph/ralph.sh` | The bash loop runner |
| `progress.txt` | Cumulative log of completed work |
| `AGENTS.md` | Patterns and gotchas discovered during development |
| `CLAUDE.md` | Project conventions and architecture reference |

---

## MCP Servers

The project is configured with Model Context Protocol servers for enhanced AI-assisted development:

| Server | Purpose |
|---|---|
| [Context7](https://github.com/upstash/context7) | Live documentation lookup (Godot, Supabase, etc.) |
| [Supabase MCP](https://github.com/supabase-community/supabase-mcp) | Database management and migrations |
| [GitHub MCP](https://github.com/modelcontextprotocol/server-github) | PR/issue management |
| [Godot MCP](https://github.com/satelliteoflove/godot-mcp) | Editor integration |
| [Serena](https://github.com/oraios/serena) | Semantic code navigation and editing |

Copy `.mcp.json.example` to `.mcp.json` and fill in your tokens to use them.

---

## Project Status

Solo development project. Currently in **Phase 1: Prototype** — building the core systems (tilemap, puff entities, turn system, bump physics, feed UI) via the Ralph loop.

See `ralph/prd.json` for the full story backlog and current progress.

---

## License

All rights reserved. This repository is public for educational and portfolio purposes.
