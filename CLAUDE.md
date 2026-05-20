# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A Crusader Kings 3 mod written entirely in **PdxScript** (Paradox's scripting language) plus a YAML localization file. There is no compile step, no test framework, and no package manager — the "build" is simply CK3 loading the files at runtime.

Target game versions: 1.18 "Crane" and 1.19 "Scribe" (`supported_version="1.*.*"` in [descriptor.mod](descriptor.mod)).

## Iteration workflow (no CLI build)

CK3 reads mods from the Paradox user-data `mod/` directory. The exact location depends on platform and installer:

| Install | Mod directory |
|------------------|----------------------------------------------------------------------------------------|
| macOS / non-Steam | `~/Documents/Paradox Interactive/Crusader Kings III/mod/` |
| Linux + Steam (Snap) | `~/snap/steam/common/.local/share/Paradox Interactive/Crusader Kings III/mod/` |

In all cases CK3 needs both a symlink (or copy) of this repo into that directory and a sibling launcher-side `.mod` pointer file. Setup details (using the macOS path as the example) are in [docs/superpowers/plans/2026-05-18-edicts-of-the-realm.md](docs/superpowers/plans/2026-05-18-edicts-of-the-realm.md) ("Development environment setup"); substitute the matching path for your install.

With CK3 running in `-debug_mode`:

| Console command | Use |
|----------------------|-----------------------------------------------------------|
| `` ` ``               | Open/close the in-game console |
| `effect { ... }`     | Run inline PdxScript on the player — primary smoke-test tool |
| `debug_log "MSG"`    | Write `MSG` to `error.log` (works inside `effect { ... }`) |
| `reload` / `reload_loca` | Manual reload — usually unnecessary, see below |

**Files hot-reload on disk change.** Editing anything under `common/**/*.txt` or `localization/**/*.yml` causes CK3 to pick up the change automatically — no `reload` console command needed. The manual commands above exist as fallbacks for cases where the file watcher misses an event.

Errors and `debug_log` output land in `error.log` in the sibling `logs/` directory of whichever data dir the game uses (e.g. `~/.local/share/Paradox Interactive/Crusader Kings III/logs/error.log` on Linux+Steam — note this is NOT the snap-confined `~/snap/steam/.../` path the launcher writes to; see "Iteration workflow" below). The file is appended; check the tail. The verification loop is: edit → check `error.log` tail for new `eotr_*` mentions → exercise the decision in-game.

**All PdxScript files (`common/**/*.txt`) AND the localization YAML must start with a UTF-8 BOM** — CK3 logs a `should be in utf8-bom encoding` warning per missing BOM and will "try anyway," but in practice some files (notably `decisions/*.txt`) parse-fail without one. If your editor strips BOMs, re-add them with `(printf '\xEF\xBB\xBF'; cat orig.txt) > new.txt && mv new.txt orig.txt`. Verify with `head -c 3 file | xxd -p` → expect `efbbbf`.

## Architecture

The mod exposes seven decisions in a custom decision group `eotr_realm_directives`: five persistent **settings** (four policy settings + the `eotr_auto_apply` master toggle), one read-only **viewer** of the current configuration, and one **action** that reads the settings and assigns a `vassal_directive_*` flag to every sub-realm vassal. When `eotr_auto_apply` is set, the action is also invoked from on_action hooks (yearly + reactive).

```
Settings (persisted as character flags on the player):
  eotr_religion_convert                          (Religion Policy = Convert)
  eotr_culture_convert | eotr_culture_accept     (Culture Policy, mutually exclusive)
  eotr_priority_religion | eotr_priority_culture (Conflict Priority)
  eotr_default_prosperity|bulwark|martial|none   (Default Edict)
  eotr_auto_apply                                (Automatic Application master toggle)

Action: eotr_apply_directives  (also invoked from on_actions when eotr_auto_apply is set)
   ├── save_scope_as = eotr_player                     (player saved as named scope)
   └── eotr_apply_all_vassals_for_player               (scripted effect)
        └── every_vassal_or_below (landed AI, ≥ county tier)
             └── eotr_evaluate_and_assign_directive   (scripted effect)
                  ├── reads scope:eotr_player's setting flags
                  ├── checks vassal-vs-its-lands via scripted triggers
                  ├── remove_vassal_directives = yes
                  └── add_character_flag = vassal_directive_<chosen>
```

Files (all small, read top-to-bottom):
- [common/decision_group_types/eotr_decision_group.txt](common/decision_group_types/eotr_decision_group.txt) — UI grouping with `sort_order`.
- [common/decisions/eotr_decisions.txt](common/decisions/eotr_decisions.txt) — all decisions. Each setting uses `decision_view_widget_decision_option_list_controller` to render radio-style options.
- [common/scripted_effects/eotr_effects.txt](common/scripted_effects/eotr_effects.txt) — the per-vassal evaluator (the algorithmic heart of the mod), the `eotr_apply_all_vassals_for_player` iteration wrapper, and the `eotr_walk_liege_chain_and_apply` recursive walker used by county-conversion hooks.
- [common/scripted_triggers/eotr_triggers.txt](common/scripted_triggers/eotr_triggers.txt) — two `any_held_county` helpers for "vassal holds at least one misaligned county".
- [common/on_action/eotr_on_actions.txt](common/on_action/eotr_on_actions.txt) — auto-apply hooks: `yearly_global_pulse`, `on_title_gain`/`on_title_lost`, `on_character_faith_change`/`on_character_culture_change`, `on_county_faith_change`/`on_county_culture_change`. All gated on the realm's top liege being a player with `eotr_auto_apply` set.
- [localization/english/eotr_l_english.yml](localization/english/eotr_l_english.yml) — all visible strings, keyed `eotr_*`.

The full design rationale (including why heretic vassals never get `convert_faith`, why "any" misaligned county is the threshold instead of a majority, and which edge cases were considered) is in [docs/superpowers/specs/2026-05-17-edicts-of-the-realm-design.md](docs/superpowers/specs/2026-05-17-edicts-of-the-realm-design.md). The implementation plan that produced each file is in [docs/superpowers/plans/2026-05-18-edicts-of-the-realm.md](docs/superpowers/plans/2026-05-18-edicts-of-the-realm.md).

## Conventions to preserve

- **Namespace everything `eotr_*`.** Every flag, trigger, effect, decision, decision-group-type, localization key — all prefixed. This is the entire compatibility story with other directive mods.
- **Outputs are vanilla flags only.** Always `add_character_flag = vassal_directive_*` from the vanilla set; never invent new directive types. Other mods (notably "Better Mass Vassal Directive") read these same flags, so changes must stay within the vanilla namespace.
- **Always `remove_vassal_directives = yes` before adding a new one.** This is what makes the apply action idempotent and what makes the mod cooperate with other directive mods (last-write-wins).
- **Settings persist as character flags on the player.** Each setting decision clears all sibling flags in its category, then adds the chosen one. To add a new option to an existing setting, add the `remove_character_flag` to the decision's `effect` clearing block AND add a new `else_if = { limit = { scope:..._opt = yes } add_character_flag = ... }` branch. NEVER use `scope:X ?= { add_character_flag = Y }` — `?=` shifts scope into the option-list boolean tag (not a character), so the add silently fails to persist; use `if + limit = { scope:X = yes }` instead.
- **Decision option scope tokens vs. persistent flag names are distinct identifiers.** On `eotr_set_priority`, `eotr_set_default_edict`, and `eotr_set_auto_apply`, option tokens use an `_opt` suffix (`eotr_priority_religion_opt`, `eotr_auto_apply_on_opt`) to avoid colliding with the persisted flag name (`eotr_priority_religion`, `eotr_auto_apply`). On `eotr_set_religion_policy` and `eotr_set_culture_policy`, the tokens use a different middle segment instead (`eotr_religion_policy_convert` as token vs. `eotr_religion_convert` as flag). Keep both schemes when extending.
- **Scope contract for the evaluator:** `eotr_evaluate_and_assign_directive` runs on a vassal scope. Every caller MUST `save_scope_as = eotr_player` on the player (the one whose settings drive the assignment) before invoking it — root varies wildly across call sites (player from the manual decision, county/vassal/unset from on_actions) so the saved scope is the only stable handle. All reads of the player's setting flags must use `scope:eotr_player = { has_character_flag = ... }`. All checks of the vassal's own faith/culture/lands use the implicit (vassal) scope.
- **Auto-apply hooks gate on the realm's top liege.** Every on_action effect in [common/on_action/eotr_on_actions.txt](common/on_action/eotr_on_actions.txt) starts with a filter of the form `top_liege = { is_ai = no, has_character_flag = eotr_auto_apply }` (or `holder.top_liege = { ... }` for county hooks). This rejects nearly every fire cheaply (most realms don't belong to an auto-apply player) and ensures other players' realms — and AI realms — are never touched. Never assume the realm-top is a player without checking.
- **Decisions are player-only.** Every decision sets `ai_will_do = { base = 0 }` and `ai_check_interval = 0`. Preserve these on any new decision.
- **`supported_version` in `descriptor.mod` and the launcher `.mod` pointer must pin a specific major.minor.** The double-wildcard `"1.*.*"` is rejected by the game (`Invalid supported_version`) even though the plan/spec docs use it. Use `"1.19.*"` (Scribe) or `"1.18.*"` (Crane). CK3 can't express "either" — pick one and rely on the yellow launcher warning for the other.
- **Decision `picture` must be a block, not a bare string** (verified against vanilla 1.19: 301 decisions use block form, 0 use bare string). Always `picture = { reference = "gfx/..." }`, never `picture = "gfx/..."`. The bare-string form parse-fails the whole decisions file and cascades to every other attribute looking "unexpected."
- **Option-list widget choice:** two valid widget guis use `controller = decision_option_list_controller`. We use `"decision_view_widget_decision_option_list_controller"` (radio-button layout, no description block); the alternative `"decision_view_widget_option_list_generic"` works too but its .gui file hardcodes a `text_multi name="description"` at the top that duplicates the decision's `desc` field — vanilla decisions live with the dup, we don't. Don't switch back unless you're prepared to handle the duplication.

## What NOT to add (explicit YAGNI from the spec)

- New `vassal_directive_*` types
- Per-vassal manual overrides or exemption lists
- Additional auto-apply triggers beyond the seven in [common/on_action/eotr_on_actions.txt](common/on_action/eotr_on_actions.txt) (yearly + title gain/lost + character faith/culture + county faith/culture). The set is intentionally bounded; more hooks compound CPU cost on every realm in the world for diminishing returns.
- Localization beyond English unless a new language is being added intentionally
- A scripted GUI / `.gui` markup — the mod intentionally stays inside standard decision UI to minimize patch breakage
