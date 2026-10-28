# ai-setup

My personal Claude Code setup, packaged the way [mattpocock/skills](https://github.com/mattpocock/skills) does it: one repo that is both a **plugin marketplace** and a **dotfiles-style installer**. Clone it on a new machine, run one script, and every skill, plugin, output style, and status line I use is back.

```bash
git clone https://github.com/said-zenhr/ai-setup ~/Desktop/ai-setup && ~/Desktop/ai-setup/install.sh
```

Or, inside a Claude Code session, just the plugins:

```
/plugin marketplace add said-zenhr/ai-setup
/plugin install said-skills@said
/plugin install scribe@said
/plugin install plain@said
```

## What's inside

```
.claude-plugin/marketplace.json   # marketplace "said": lists the plugins below
plugins/
  said-skills/                    # my own skills + the "Terse" output style
  scribe/                         # Obsidian vault recorder (hooks + skills + commands)
  plain/                          # STE100 replies with a 30-900 word cap (hooks + command)
  training-wheels/                # learning guardrails for junior devs (disabled by default)
config/
  settings.json                   # sanitized ~/.claude/settings.json (model, effort, plugins, status line)
  statusline.sh                   # dir · branch · model · effort · context % · cost · rate-limit reset
  mcp.example.json                # user-scope MCP servers
third-party/
  skills.txt                      # skills pulled from other people's repos via `npx skills`
  plugins.txt                     # plugins from other marketplaces (official, warp, ponytail, caveman)
scripts/
  sync-from-local.sh              # pull live ~/.claude changes back into this repo
  validate.sh                     # what CI runs
docs/INVENTORY.md                 # full snapshot of the setup, for reference
install.sh                        # the one-shot installer
```

### Plugins in this marketplace

| Plugin | What it does | Default |
|---|---|---|
| `said-skills` | `/terse-executor`, `/rails-code-review`, `/describe-pr`, `/daily-work-note`, `/morning-brief`, `/code-mentor`, `/engineer-agent-builder`, `/release-ticket-title`, `/concise-output`, `/bro`, plus the **Terse** output style | on |
| `scribe` | `/scribe`, `/scribe-backfill`, `/scribe-due`. Records decisions, meetings, insights and todos into my Obsidian vault with word budgets, link enforcement and an end-of-session safety net | on |
| `plain` | `/plain 1-7`, a level name (`whisper` to `essay`), a word count 30-900, or `off`. Claude replies in ASD-STE100 Simplified Technical English within a word cap from 30 to 900 words. A hook adds the rules to every prompt; a Stop hook counts words and sentences over 20 words and warns on the next turn | on |
| `training-wheels` | `/training-wheels`, `/tw-level`, `/tw-stats`, `/tw-gaps`, plus the `tw-protocol` terminal dashboard. Socratic hints over answers, XP and kata progression, strict-mode file gate | off |

### Third-party skills

Not vendored. Installed with the [`skills`](https://github.com/vercel-labs/skills) CLI so they track upstream:

| Source | Skills |
|---|---|
| `mattpocock/skills` | grill-me, grilling, tdd, code-review, diagnose, to-spec, to-tickets, implement, wayfinder, research, prototype, teach, handoff, zoom-out, writing-* and ~30 more |
| `vercel-labs/agent-skills` | vercel-react-best-practices |
| `vercel-labs/skills` | find-skills |
| `stablyai/orca` | orca-cli, orchestration, computer-use |
| `devmartinese/awwwards-animations-skill` | awwwards-animations |
| `dylantarre/animation-principles` | exaggerated-clarity |
| `guia-matthieu/clawfu-skills` | yc-pitch-deck |
| `patricio0312rev/skills` | explaining-code |
| `ntcoding/claude-skillz` | concise-output |

Full list in [`third-party/skills.txt`](third-party/skills.txt). Update all with `npx skills update -g`.

### Third-party plugins

| Plugin | Marketplace | Default |
|---|---|---|
| ruby-lsp | claude-plugins-official | on |
| chrome-devtools-mcp | claude-plugins-official | on |
| warp | warpdotdev/claude-code-warp | on |
| ponytail | DietrichGebert/ponytail | off |
| caveman | JuliusBrussee/caveman | off |

## How the installer works

`install.sh` is idempotent. It:

1. Adds this repo (or the local clone, if you ran it from one) and the third-party marketplaces.
2. Installs every plugin at user scope and disables the ones marked `disabled`.
3. Copies `statusline.sh` to `~/.claude/`.
4. Writes `settings.json` if none exists, otherwise **merges** it in with your existing values winning (a timestamped backup is kept).
5. Links `tw-protocol` into `~/.local/bin` (and adds that to PATH in `.zshrc`) so the training-wheels dashboard runs from any directory.
6. Installs third-party skills with `npx skills add … -g`. Skip with `SKIP_THIRD_PARTY=1`.

Training-wheels XP state is per machine: `~/.claude/training-wheels/state.json` and `state.sig`. Copy both to carry progress to a new Mac.

Not managed by this repo, on purpose:

- **Orca agent hooks** in `settings.json`. They are written by the Orca app and point at machine-local scripts.
- **Auto-mode environment profile**. It describes my employer's repos and infra. Regenerate it with `/auto-mode` in the trusted repo.
- **Project-scope MCP servers** (TablePlus, zen-triage). Those belong in each project's `.mcp.json`.
- **Memory** under `~/.claude/projects/*/memory`. Per-machine, per-project.
- **claude.ai connectors** (Slack, Jira, Gmail, Figma, ZenHR…). Those are attached to the account, not the machine.

## Keeping the repo current

Edit skills in `~/.claude/skills/<name>/` as usual, then:

```bash
scripts/sync-from-local.sh   # copies own skills, output styles, statusline, settings, lists
scripts/validate.sh
git commit -am "sync" && git push
```

Skills in `~/.claude/skills` that are symlinks are third-party (`npx skills` installs them into `~/.agents/skills` and links them). Only real directories get copied into `plugins/said-skills`.

## Conventions

- One plugin per concern. `said-skills` is the grab bag; anything with hooks or scripts gets its own plugin.
- A skill is a directory with a `SKILL.md` whose `name:` matches the directory. Supporting files go next to it (`references/`, `assets/`).
- Skills meant to be typed as `/commands` set `disable-model-invocation: true`. Skills meant to trigger automatically write a strong `description:` with the phrases that should trigger them.
- Plugin `version` bumps in `plugin.json` when behaviour changes. `claude plugin update said-skills@said` pulls it.
- `scripts/validate.sh` must pass before push. CI runs the same script.

## License

MIT for everything in `plugins/`. Third-party skills keep their own licenses upstream.
