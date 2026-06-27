# Building Reusable Claude Skills for Your Dev Environment

I spent an afternoon turning a YouTube video into a full automation system for my Qualcomm Linux development workflow — and it clicked in a way I hadn't expected.

Here's how it went.

---

## It Started with a Video Subtitle

I had a video about Claude Code that I wanted to digest quickly. Instead of watching it in full, I dropped the subtitle file (`.txt`) into my Claude Code session and asked it to summarize the key commands and features.

What came back was this table:

### Slash Commands

| Command | What it does |
|---|---|
| `/init` | Scans your codebase and generates a `CLAUDE.md` — a project cheat sheet with architecture, conventions, and key files |
| `/statusline` | Adds a status bar showing model, context %, cost, etc. |
| `/context` | Shows a breakdown of what's consuming your tokens — system prompts, files, MCP servers — as percentages |
| `/compact` | Compresses conversation history when context is running low. You can specify what to preserve: `/compact but keep all API integration decisions` |
| `/clear` | Wipes conversation history entirely (CLAUDE.md and files remain) |
| `/rewind` | Rolls back the conversation to a previous point without starting over |
| `/hooks` | Configure notification hooks — e.g., play a sound when a long session finishes |
| `/loop` | Runs a prompt on a recurring interval: "every 5 minutes check the deployment" |

### CLI Flags

| Flag | What it does |
|---|---|
| `claude --worktree <feature-name>` | Creates an isolated git worktree on its own branch — lets you run multiple parallel sessions on the same project without conflicts |

### Prompt Keywords

| Keyword | What it does |
|---|---|
| `ultrathink` | Type this word in your prompt to allocate maximum thinking budget before Claude responds — use for hard architecture decisions or complex debugging |
| Plan mode (`Shift+Tab`) | Toggle a mode where Claude can read/research but won't change files — outlines steps and asks questions first |

### Key Concepts (Not Commands)

These aren't slash commands — they're patterns worth knowing:

- **Custom skills** — Create `.md` files in `.claude/skills/` (e.g., `codereview.md`) and invoke them by name or natural language. They run the same workflow every time and can be shared via git.
- **Sub-agents** — Ask Claude to spin up sub-agents in your prompt for parallel work. Each has its own context window; you can set cheaper models (Haiku) for simple tasks.
- **Agent teams** — Like sub-agents, but agents can talk to each other, share a task list, and assign each other work.
- **Permissions** — Instead of `--dangerously-skip-permissions`, explicitly allow safe commands and deny destructive ones (deletes, removes) in settings. The deny list takes priority.
- **CLAUDE.md routing** — Keep CLAUDE.md lean (150–200 lines max); link out to separate files for style guides, business context, etc.
- **Context7 MCP** — Install this MCP server to give Claude up-to-date library docs (Next.js, React, MongoDB, etc.) before it writes code.

That table alone was worth the exercise. But one concept buried in that last bullet changed my whole afternoon:

> **Custom skills** — Create `.md` files in `.claude/skills/` and invoke them by name or natural language. They run the same workflow every time and can be shared via git.

---

## The Problem I Was Solving

I work with a **Qualcomm IQ-8275 EVK** — a Dragonwing development board running Qualcomm Linux. Every time I start a new Claude session, I find myself re-explaining the same things:

- How to put the device into EDL mode to flash it
- Which USB port is the serial console (it's always the *second* one)
- The exact SSH credentials and how to find the device IP
- Which kas YAML files to combine for a Yocto build
- The specific environment variables that make the build server work

This is tedious and error-prone. Skills fix it.

---

## What Skills Actually Are

A Claude Code skill is a **markdown playbook**. It lives in your plugin directory, has a YAML frontmatter block that tells Claude when to activate it, and contains step-by-step instructions that Claude follows when the trigger fires.

They're not code — they're documentation that executes.

```
~/.claude/plugins/dragonwing/
├── .claude-plugin/
│   └── plugin.json          ← lists which skills exist
└── skills/
    ├── flash/SKILL.md
    ├── serial/SKILL.md
    ├── ssh/SKILL.md
    └── build/SKILL.md
```

Each skill file starts like this:

```markdown
---
description: >
  Use this skill when the user wants to flash the IQ-8275 EVK, mentions QDL,
  wants to flash a Qualcomm Linux image...
allowed-tools:
  - Bash(ssh *)
  - Bash(~/tools/qdl/QDL_2.7_Mac_ARM64/qdl *)
---

## Step 1 — Check QDL is installed
...
```

The `description` is the activation trigger. Claude reads it and decides whether to invoke the skill based on what you're asking. You never have to remember a command name.

---

## The Four Skills I Built

### `flash` — Full 8-step firmware flashing workflow

Covers everything from checking QDL is installed, downloading pre-built artifacts from Codelinaro, putting the device into EDL mode (flip switch SW2-3), UFS provisioning, flashing SAIL firmware, flashing the main Linux image, and finally booting the device. Includes a "custom image" branch for when you're working off a local Yocto build instead of the pre-built release.

### `serial` — Serial console access

The EVK exposes four serial ports over a single micro-USB connection. The main console is always the *second* port (`P1`). The skill handles port discovery, interactive `screen` connections, and a scripted Python/pyserial path for automation (logging in and extracting the IP address without human interaction).

### `ssh` — SSH over the network

Walks through getting the device IP (delegate to `serial` if needed), adding the host key, interactive connections, and non-interactive `sshpass` commands for automation scripts. Includes image verification steps so you can confirm what's running.

### `build` — Yocto/kas build on the remote server

This one was the most interesting to write because I was building the skill *while actually running the build* for the first time. The build server (`hu-raulrm-lv`) has a few quirks that would be impossible to guess:

- Home directory is `/usr2/raulrm`, not `/home/raulrm`
- Shell is `tcsh`, which means `!` in inline SSH strings causes "Event not found" errors
- Three specific environment variables are mandatory or the build fails immediately
- You must write a shell script file and execute it — inline nohup commands don't survive the quoting

By writing the skill as I discovered each of these facts, the final playbook is a complete, verified procedure rather than aspirational documentation.

---

## The Result

Any future Claude session that opens this project and mentions flashing, serial console, SSH, or building will automatically pick up the right skill — with all the environment-specific knowledge already baked in.

I don't re-explain EDL mode. I don't re-paste the kas YAML paths. I don't remind Claude which USB port is the console. It already knows.

That's the shift: from a generic AI assistant to an **environment-aware agent** that understands your exact setup.

---

## Teaching Claude to Reach You When It's Stuck

One pattern that comes up constantly with long autonomous tasks: Claude hits a blocker — a device isn't detected, a build fails, a decision needs a human — and just sits there until you check back.

The fix is a notification skill. I set up [CallMeBot](https://www.callmebot.com/) (a free WhatsApp API that takes 30 seconds to activate) and created a `notify` plugin with a single `whatsapp` skill:

```markdown
---
description: >
  Use this skill when you are blocked and need human input to continue, when a
  long-running task finishes and the user should be notified, or when you
  encounter an error you cannot resolve autonomously.
allowed-tools:
  - Bash(curl *)
---
```

The skill body tells Claude to compose a short message, URL-encode it, and fire a `curl` call:

```bash
MSG="Blocked on flashing step 4 — device not detected in EDL mode. Please check SW2-3 and USB-C cable."
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote_plus('$MSG'))")
curl -s "https://api.callmebot.com/whatsapp.php?phone=OWNER_PHONE&text=${ENCODED}&apikey=OWNER_APIKEY"
```

The skill lives in its own `notify` plugin (separate from `dragonwing`) so every agent in every project can use it — not just the hardware ones.

Now when I kick off a 90-minute Yocto build and go do something else, I get a WhatsApp message when it finishes or if something breaks mid-way. No more compulsively checking the terminal.

The credentials (phone number + API key) stay in the local skill file only — the version pushed to GitHub uses `OWNER_PHONE` / `OWNER_APIKEY` placeholders.

---

## Try It Yourself

The plugin structure is straightforward. Start with one skill for the most repetitive thing in your workflow — the thing you find yourself explaining to Claude at the start of every session. Write it as a step-by-step markdown guide, add the frontmatter description that describes when it should activate, and put it in `~/.claude/plugins/<your-plugin>/skills/<name>/SKILL.md`.

The next time you open a session, you'll never have to explain that procedure again.

---

*Skills created in this post are for the Qualcomm Dragonwing IQ-8275 EVK. The flash workflow uses QDL 2.7 and targets Qualcomm Linux qli-2.0.*
