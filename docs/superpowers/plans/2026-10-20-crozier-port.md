# Crozier (CK3 1.20) Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Edicts of the Realm work correctly on CK3 1.20.1 "Crozier": repair the auto-apply hooks so they no longer clash with vanilla, switch the removed `on_character_faith_change` hook to `on_rite_change`, and document the rite behaviour.

**Architecture:** No change to the evaluator logic. `faith` already means the faith level in 1.20, and the vanilla directive only acts on other-faith counties. The real work is in `common/on_action/eotr_on_actions.txt`: each hook body moves into its own `eotr_*` on_action, attached to the vanilla on_action with `on_actions = { ... }` (append) instead of a competing `effect` block. The rest is comments, two localization sentences, version metadata and docs.

**Tech Stack:** PdxScript (CK3 1.20.1.1), CK3 localization YAML. No build, no test framework. Every test is an in-game check in `-debug_mode`, run by a human, using console commands and `debug.log` / `error.log`.

**Spec:** [docs/superpowers/specs/2026-10-01-rite-aware-religion-policy-design.md](../specs/2026-10-01-rite-aware-religion-policy-design.md)

## Global Constraints

- Every `common/**/*.txt` file and the localization YAML must start with a UTF-8 BOM. Check with `head -c 3 <file> | xxd -p`, expect `efbbbf`.
- PdxScript files indent with tabs.
- Namespace everything `eotr_*`.
- Outputs are vanilla `vassal_directive_*` flags only. Always `remove_vassal_directives = yes` before adding one.
- Never write `effect` (or `trigger`) directly on a vanilla on_action. Attach an `eotr_*` on_action with `on_actions = { ... }`.
- The bounded auto-apply set stays at **seven** hooks: yearly + title gain/lost + character faith (`on_rite_change`) / culture + county faith/culture. `on_primary_title_change` is a settings migration, not an auto-apply hook. Do NOT add `on_county_rite_change` or `on_faith_created`.
- `supported_version="1.20.*"` in `descriptor.mod` (the double wildcard `"1.*.*"` is rejected by the game).
- Release version: `1.3.0`.
- Every auto-apply hook gates on the realm's top liege being a player with `eotr_auto_apply` set, before any other work.

## How to run an in-game check

Agents cannot run the game. Each test step below is a script for the human. The agent asks the user to run it, then reads the logs itself.

- Logs live in `~/.local/share/Paradox Interactive/Crusader Kings III/logs/`. Script errors go to `error.log`. `debug_log` output goes to **`debug.log`**.
- Console: press `` ` ``. `effect <body>` runs on the player. There are no outer braces: `effect add_gold = 100`.
- Target another character through a title they hold: `title:<key>.holder`. In debug mode, the title key is shown in the title's view. Do NOT use `character:<number>`: it only accepts history IDs.
- **Code on_actions are deferred.** A hook triggered by a console change runs on the *next game day*, and nothing runs while paused. After any change command, unpause until the date advances by one day, then pause again.
- `debug.log` may lag. If an expected line is missing, save or pause, then read again.

**CHECK command.** Logs whether the holder of `<KEY>` has `<FLAG>`. It runs immediately, with no unpause needed:

```
effect title:<KEY>.holder = { if = { limit = { has_character_flag = <FLAG> } debug_log = "EOTR_CHECK <FLAG>=yes" } else = { debug_log = "EOTR_CHECK <FLAG>=no" } }
```

Read the result:

```bash
grep EOTR_CHECK ~/.local/share/"Paradox Interactive/Crusader Kings III/logs/debug.log" | tail -3
```

**CLEAR command.** Removes the directive from the holder of `<KEY>`:

```
effect title:<KEY>.holder = { remove_vassal_directives = yes }
```

The examples below use the test setup the spec's probe tests were run on: vassal Hoten Krajnc, holder of `c_kranj`. If you build a different setup, substitute your vassal's county key for `c_kranj` everywhere.

## Review Focus

1. **The player converts faith.** Every vassal's "shares my faith" check flips, so the whole realm must be re-evaluated. Covered by Task 1, Step 8.
2. **The player or a vassal changes rite only.** The `on_rite_change` trigger must skip it: no re-evaluation, no realm-wide re-apply. Covered by Task 1, Steps 7 and 9.
3. **Vanilla logic on shared hooks keeps running.** No "more than one 'effect'" error may remain for any hook this mod touches. Covered by Task 1, Step 5.
4. **Realms that aren't an auto-apply player's are never touched.** An AI realm's vassal keeps its vanilla directive. Covered by Task 1, Step 12.
5. **Bulk religion change (Great Schism).** About 5,500 hook fires in one tick, with the player's realm re-applied up to twice. Must end with the right flags and no `eotr` errors. Covered by Task 3, Step 3.

---

### Task 1: Repair the auto-apply hooks

**Files:**
- Modify (full rewrite): `common/on_action/eotr_on_actions.txt`

**Interfaces:**
- Consumes (unchanged, from `common/scripted_effects/eotr_effects.txt`): `eotr_evaluate_and_assign_directive` (vassal scope, needs `scope:eotr_player`), `eotr_apply_all_vassals_for_player` (player scope, needs `scope:eotr_player`), `eotr_walk_liege_chain_and_apply` (character scope, needs `scope:eotr_player`), `eotr_migrate_settings_to_primary_title` (character scope, needs `scope:previous_title`). From `common/scripted_triggers/eotr_triggers.txt`: `eotr_title_has_settings` (title scope).
- Produces: eight on_actions, `eotr_yearly_global_pulse`, `eotr_on_title_gain`, `eotr_on_title_lost`, `eotr_on_rite_change`, `eotr_on_character_culture_change`, `eotr_on_county_faith_change`, `eotr_on_county_culture_change`, `eotr_on_primary_title_change`, each attached to the vanilla on_action of the same base name. No later task calls them.

A child on_action attached through `on_actions` runs with its parent's root and saved scopes (`scope:old_faith`, `scope:previous_title`). The probe file `common/on_action/eotr_zz_probe.txt` relies on the same thing and logged `old_faith` / `old_rite` correctly.

- [ ] **Step 1: Build the test save (with the current, unmodified code)**

The test save is built with the 1.2.3 code, so it also serves as the "old save" check in Task 3. Ask the user to:

1. Launch CK3 1.20.1 with `-debug_mode` and the mod enabled. The launcher's yellow "outdated" warning is expected.
2. Start an 867 game as a Western-rite Christian ruler with at least one AI count/duke vassal. The reference setup is the liege of Hoten Krajnc (`c_kranj`).
3. In the console:
   ```
   effect title:c_kranj.holder = { set_character_rite = rite:byzantine_rite }
   effect title:c_kranj = { set_county_faith = faith:slavic_pagan }
   effect add_legitimacy = 1000
   ```
4. In the "Edicts of the Realm" decisions, set: Religion Policy = Convert, Culture Policy = None, Conflict Priority = Religion First, Default Edict = Foster Prosperity, Automatic Application = On. Picking On runs a full apply.
5. Unpause for one day, then pause.
6. CHECK `c_kranj` / `vassal_directive_convert_faith`. Expect `=yes`.
7. Save as `eotr_crozier_test`.

Every test below starts with "reload `eotr_crozier_test`".

- [ ] **Step 2: Record the failing baseline**

With the game from Step 1 still running, read the log:

```bash
grep "more than one 'effect'" ~/.local/share/"Paradox Interactive/Crusader Kings III/logs/error.log"
```

Expected (FAIL state), five lines naming `on_character_culture_change`, `on_county_faith_change`, `on_title_gain`, `on_title_lost`, `yearly_global_pulse`.

Then ask the user to run the vassal-faith test (it must fail now, because 1.20 removed `on_character_faith_change`). Reload `eotr_crozier_test`, then:

```
effect title:c_kranj.holder = { set_character_faith = faith:norse_pagan }
```

Unpause one day, pause. CHECK `c_kranj` / `vassal_directive_convert_faith`.
Expected (FAIL state): `=yes`. The stale directive was not withdrawn.

- [ ] **Step 3: Rewrite `common/on_action/eotr_on_actions.txt`**

Replace the whole file with the content below. The file must start with a UTF-8 BOM and use tabs. Only these things change from the 1.2.3 file: the header comment, the attachment block, each `<hook> = { effect = ... }` becoming `eotr_<hook> = { effect = ... }`, and `on_character_faith_change` becoming `eotr_on_rite_change` with a `trigger`. Every effect body is otherwise identical.

```
# Auto-application hooks. Active only for players who have set the
# `eotr_auto_apply` variable via the "Automatic Application" setting decision.
# Every auto-apply hook gates on `top_liege = { is_ai = no, primary_title =
# { has_variable = eotr_auto_apply } }` so other players' (and AI characters')
# realms are untouched.
#
# Attachment pattern: never write `effect` (or `trigger`) directly on a vanilla
# on_action. Only one `effect` per on_action survives the merge, so ours would
# either replace vanilla's or be dropped (error.log: "There is more than one
# 'effect' defined"). Each body lives in its own eotr_* on_action instead,
# attached with `on_actions = { ... }`, which appends to vanilla's list. The
# child runs with the parent's root and saved scopes.
#
# Code on_actions run on the next game day after the change (nothing runs while
# paused), and see the state at that moment.

yearly_global_pulse         = { on_actions = { eotr_yearly_global_pulse } }
on_title_gain               = { on_actions = { eotr_on_title_gain } }
on_title_lost               = { on_actions = { eotr_on_title_lost } }
on_rite_change              = { on_actions = { eotr_on_rite_change } }
on_character_culture_change = { on_actions = { eotr_on_character_culture_change } }
on_county_faith_change      = { on_actions = { eotr_on_county_faith_change } }
on_county_culture_change    = { on_actions = { eotr_on_county_culture_change } }
on_primary_title_change     = { on_actions = { eotr_on_primary_title_change } }

# --- Yearly refresh ---
# Fires once globally on January 1st. We iterate every player; for each one
# with auto-apply on, save them as scope:eotr_player and re-evaluate their
# entire sub-realm.
eotr_yearly_global_pulse = {
	effect = {
		every_player = {
			limit = {
				is_landed = yes
				primary_title = { has_variable = eotr_auto_apply }
			}
			save_scope_as = eotr_player
			eotr_apply_all_vassals_for_player = yes
		}
	}
}

# --- Title transferred ---
# `on_title_gain` fires on the new holder; `on_title_lost` on the former
# holder. Re-evaluate the affected character if they are still an eligible
# sub-realm AI vassal of a player with auto-apply on. The loser case
# matters because their misaligned-county set may have shrunk to zero —
# a stale convert_culture/convert_faith should be cleared.
eotr_on_title_gain = {
	effect = {
		if = {
			limit = {
				is_landed = yes
				is_ai = yes
				highest_held_title_tier >= tier_county
				exists = liege
				top_liege = {
					is_ai = no
					primary_title = { has_variable = eotr_auto_apply }
				}
			}
			top_liege = { save_scope_as = eotr_player }
			eotr_evaluate_and_assign_directive = yes
		}
	}
}

eotr_on_title_lost = {
	effect = {
		if = {
			limit = {
				is_landed = yes
				is_ai = yes
				highest_held_title_tier >= tier_county
				exists = liege
				top_liege = {
					is_ai = no
					primary_title = { has_variable = eotr_auto_apply }
				}
			}
			top_liege = { save_scope_as = eotr_player }
			eotr_evaluate_and_assign_directive = yes
		}
	}
}

# --- Character converts faith / culture ---
# Two branches per hook:
#   (a) An AI vassal converted — re-evaluate that vassal only.
#   (b) The player converted — every "shares faith/culture with liege" check
#       in the evaluator just inverted realm-wide, so re-apply to every
#       vassal in their realm.
# on_rite_change (1.20+, replaces on_character_faith_change) fires for faith
# AND rite-only changes; root = character, scope:old_faith = previous faith.
# The trigger skips rite-only changes: the evaluator compares faiths only, so
# they cannot change any outcome. Bulk changes (e.g. the Great Schism) can fire
# this twice per character in one tick; both runs see the final state, so the
# result is the same, only the CPU is wasted.
eotr_on_rite_change = {
	trigger = {
		NOT = { faith = scope:old_faith }
	}
	effect = {
		if = {
			limit = {
				is_landed = yes
				is_ai = yes
				highest_held_title_tier >= tier_county
				exists = liege
				top_liege = {
					is_ai = no
					primary_title = { has_variable = eotr_auto_apply }
				}
			}
			top_liege = { save_scope_as = eotr_player }
			eotr_evaluate_and_assign_directive = yes
		}
		else_if = {
			limit = {
				is_ai = no
				is_landed = yes
				primary_title = { has_variable = eotr_auto_apply }
			}
			save_scope_as = eotr_player
			eotr_apply_all_vassals_for_player = yes
		}
	}
}

eotr_on_character_culture_change = {
	effect = {
		if = {
			limit = {
				is_landed = yes
				is_ai = yes
				highest_held_title_tier >= tier_county
				exists = liege
				top_liege = {
					is_ai = no
					primary_title = { has_variable = eotr_auto_apply }
				}
			}
			top_liege = { save_scope_as = eotr_player }
			eotr_evaluate_and_assign_directive = yes
		}
		else_if = {
			limit = {
				is_ai = no
				is_landed = yes
				primary_title = { has_variable = eotr_auto_apply }
			}
			save_scope_as = eotr_player
			eotr_apply_all_vassals_for_player = yes
		}
	}
}

# --- County converts faith / culture ---
# Root is the county title. The holder may be a deep sub-vassal; the spec
# asks us to re-evaluate the holder and every intermediate liege up to (but
# not including) the player. eotr_walk_liege_chain_and_apply handles that.
# Rite-only county changes fire on_county_rite_change instead, which we
# deliberately do not hook: they cannot change a faith-level check.
# Note: in vanilla 1.19 on_county_culture_change is documented but never
# fires from base-game code — wiring it here is defensive against future
# patches or other mods that trigger it.
eotr_on_county_faith_change = {
	effect = {
		if = {
			limit = {
				exists = holder
				holder = {
					exists = top_liege
					top_liege = {
						is_ai = no
						primary_title = { has_variable = eotr_auto_apply }
					}
				}
			}
			holder.top_liege = { save_scope_as = eotr_player }
			holder = { eotr_walk_liege_chain_and_apply = yes }
		}
	}
}

eotr_on_county_culture_change = {
	effect = {
		if = {
			limit = {
				exists = holder
				holder = {
					exists = top_liege
					top_liege = {
						is_ai = no
						primary_title = { has_variable = eotr_auto_apply }
					}
				}
			}
			holder.top_liege = { save_scope_as = eotr_player }
			holder = { eotr_walk_liege_chain_and_apply = yes }
		}
	}
}

# --- Primary title changed ---
# Settings live on the player's primary title so they survive ordinary
# succession for free (the heir inherits the title). But if the player's PRIMARY
# title itself changes — e.g. forming an empire, where a higher title becomes
# primary while the old one is kept as a secondary — the settings would be
# stranded on the now-secondary title. This hook moves them onto the new primary.
#
# Vanilla contract (see title_on_actions.txt): root = character,
# scope:previous_title = the previous primary title, and it is never called when
# the new primary equals the old one. We act only for landed players whose old
# primary actually held settings and whose new primary doesn't already have its
# own (so we never clobber an existing configuration).
eotr_on_primary_title_change = {
	effect = {
		if = {
			limit = {
				is_landed = yes
				is_ai = no
				exists = scope:previous_title
				scope:previous_title = { eotr_title_has_settings = yes }
				NOT = { primary_title = { eotr_title_has_settings = yes } }
			}
			eotr_migrate_settings_to_primary_title = yes
		}
	}
}
```

Write it with a BOM, for example: write the content to the file, then
`(printf '\xEF\xBB\xBF'; cat common/on_action/eotr_on_actions.txt) > /tmp/x && mv /tmp/x common/on_action/eotr_on_actions.txt`
(only if your editor didn't keep the existing BOM).

- [ ] **Step 4: Static checks**

```bash
head -c 3 common/on_action/eotr_on_actions.txt | xxd -p
grep -c "^[a-z_]* *= { on_actions" common/on_action/eotr_on_actions.txt
grep -n "^\(yearly_global_pulse\|on_[a-z_]*\) = {$" common/on_action/eotr_on_actions.txt
grep -n "on_character_faith_change" common/on_action/eotr_on_actions.txt
```

Expected:
- `efbbbf`.
- `8`.
- No output: no vanilla on_action is opened as a multi-line block, so none carries an `effect`.
- Only the comment line that mentions the replacement.

- [ ] **Step 5: Restart the game, check that vanilla no longer clashes**

On_action merging happens at load, so ask the user to **quit and relaunch** CK3 (hot reload is not enough here). Load `eotr_crozier_test`, then:

```bash
L=~/.local/share/"Paradox Interactive/Crusader Kings III/logs"
grep "more than one 'effect'" "$L/error.log"
grep -n "eotr" "$L/error.log"
```

Expected: both print nothing. Compare with the five lines in Step 2.

- [ ] **Step 6: Test `on_rite_change`, vassal faith change (Step 2's failing test)**

Reload `eotr_crozier_test`, then:

```
effect title:c_kranj.holder = { set_character_faith = faith:norse_pagan }
```

Unpause one day, pause. CHECK `c_kranj` / `vassal_directive_convert_faith`, then CHECK `c_kranj` / `vassal_directive_building_focus_economy`.

Expected: `convert_faith=no`, `building_focus_economy=yes`. The vassal is now Foreign, so he falls through to the Default Edict.

- [ ] **Step 7: Test the rite-only skip (vassal)**

Reload `eotr_crozier_test`, then:

```
effect title:c_kranj.holder = { remove_vassal_directives = yes }
effect title:c_kranj.holder = { set_character_rite = rite:georgian_rite }
```

Unpause one day, pause. CHECK `c_kranj` / `vassal_directive_convert_faith`.
Expected: `=no`. The hook was skipped, so the flag we cleared stayed cleared.

Control: take the "Issue Directives to the Realm" decision, then CHECK again.
Expected: `=yes`. He was still a valid candidate, so the earlier `no` came from the trigger skipping, not from the evaluator.

- [ ] **Step 8: Test the player converting faith (Review Focus 1)**

Reload `eotr_crozier_test`, then:

```
effect set_character_faith = faith:norse_pagan
```

Unpause one day, pause. CHECK `c_kranj` / `vassal_directive_convert_faith`, then CHECK `c_kranj` / `vassal_directive_building_focus_economy`.
Expected: `convert_faith=no`, `building_focus_economy=yes`. The vassal no longer shares the player's faith, and the whole realm was re-applied.

- [ ] **Step 9: Test the rite-only skip (player, Review Focus 2)**

Reload `eotr_crozier_test`, then:

```
effect title:c_kranj.holder = { remove_vassal_directives = yes }
effect set_character_rite = rite:roman_rite
```

If the player is already on `roman_rite`, use `rite:ambrosian_rite` instead.

Unpause one day, pause. CHECK `c_kranj` / `vassal_directive_convert_faith`.
Expected: `=no`. No realm-wide re-apply ran for a rite-only change.

- [ ] **Step 10: Test `on_title_gain` and `yearly_global_pulse` (both silently dropped before the fix)**

Title gain: reload `eotr_crozier_test`. Find the key of any county the player holds directly, from the title view in debug mode. Then:

```
effect title:c_kranj.holder = { remove_vassal_directives = yes }
effect title:c_kranj.holder = { get_title = title:<player county key> }
```

Unpause one day, pause. CHECK `c_kranj` / `vassal_directive_convert_faith`.
Expected: `=yes`. The vassal was re-evaluated on gaining the title.

Yearly: reload `eotr_crozier_test`, then:

```
effect title:c_kranj.holder = { remove_vassal_directives = yes }
effect trigger_event = { on_action = yearly_global_pulse }
```

Unpause one day, pause. CHECK `c_kranj` / `vassal_directive_convert_faith`.
Expected: `=yes`.

- [ ] **Step 11: Test the primary-title settings migration**

Reload `eotr_crozier_test`. Pick a kingdom with no holder (title view shows no holder; for example the de jure kingdom of the player's capital, if unheld). Then:

```
effect get_title = title:<kingdom key>
```

If the player's primary title did not switch to the kingdom on its own, also run:

```
effect set_primary_title_to = title:<kingdom key>
```

Unpause one day, pause. Open the "View Current Settings" decision.
Expected: Religion Convert, Culture not set, Religion First, Foster Prosperity, Automatic Application On. These are the same values as before, now read from the new primary title.

- [ ] **Step 12: Test that other realms are untouched (Review Focus 4)**

Reload `eotr_crozier_test`. Pick a county held by an AI vassal of a *different*, AI-ruled realm (its key from the title view). Then:

```
effect title:<that county>.holder = { remove_vassal_directives = yes add_character_flag = vassal_directive_build_maa }
effect title:<that county>.holder = { set_character_faith = faith:norse_pagan }
```

Unpause one day, pause. CHECK `<that county>` / `vassal_directive_build_maa`.
Expected: `=yes`. Our hook did not touch an AI realm.

- [ ] **Step 13: Commit**

```bash
git add common/on_action/eotr_on_actions.txt
git commit -m "Attach auto-apply hooks via on_actions; use on_rite_change for 1.20

Defining effect directly on vanilla on_actions made ours replace vanilla's
(culture change, county faith change) or be dropped (title gain/lost, yearly
pulse). Each hook body now lives in its own eotr_* on_action appended with
on_actions. on_character_faith_change was removed in 1.20; on_rite_change
replaces it, with a trigger that skips rite-only changes.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Make sure `common/on_action/eotr_zz_probe.txt` is NOT staged (it is listed in `.git/info/exclude`).

---

### Task 2: Comments, localization, version and docs

**Files:**
- Modify: `common/scripted_triggers/eotr_triggers.txt:1-3`
- Modify: `common/scripted_effects/eotr_effects.txt:14-17`
- Modify: `common/decisions/eotr_decisions.txt:2,69`
- Modify: `localization/english/eotr_l_english.yml:39,44`
- Modify: `descriptor.mod`
- Modify: `README.md:7,30-35`
- Modify: `CHANGELOG.md` (new entry at the top)
- Modify: `CLAUDE.md:9,68,83,91` and the "Conventions to preserve" list

**Interfaces:**
- Consumes: the eight `eotr_*` on_action names and the `on_rite_change` hook from Task 1 (named in CLAUDE.md).
- Produces: release `1.3.0` metadata. Nothing in code depends on this task.

- [ ] **Step 1: Write the failing check**

Ask the user (game running, mod loaded) to open "Set Religion Policy" and hover over the Convert option.
Expected (FAIL state): the tooltip has no sentence about rites.

- [ ] **Step 2: Update the trigger comment**

In `common/scripted_triggers/eotr_triggers.txt`, replace:

```
# True if the character holds at least one county whose faith differs from
# the character's own faith. Used to decide whether vassal_directive_convert_faith
# would have any work to do.
```

with:

```
# True if the character holds at least one county whose faith differs from
# the character's own faith. Used to decide whether vassal_directive_convert_faith
# would have any work to do. Compares faith, not rite (1.20+): a same-faith
# county of another rite does not count, because the directive does not
# convert rites.
```

- [ ] **Step 3: Update the evaluator comment**

In `common/scripted_effects/eotr_effects.txt`, replace:

```
	# --- Religion candidate ---
	# Only fires when player has Religion=Convert AND vassal shares player's
	# faith AND vassal has at least one misaligned county. Heretic vassals
	# never get convert_faith (it would spread heresy).
```

with:

```
	# --- Religion candidate ---
	# Only fires when player has Religion=Convert AND vassal shares player's
	# faith AND vassal has at least one misaligned county. Heretic vassals
	# never get convert_faith (it would spread heresy).
	# 1.20+: `faith` is the faith level, not the rite. A vassal of another rite
	# of the player's faith qualifies on purpose: the directive only converts
	# other-FAITH counties (rite-only mismatches do nothing), and a converted
	# county takes the vassal's rite, which is still the player's faith.
```

- [ ] **Step 4: Fix the stale decision comments**

In `common/decisions/eotr_decisions.txt`, replace line 2:

```
# Reads the player's eotr_* character flags and renders a four-line summary
```

with:

```
# Reads the eotr_* variables on the player's primary title and renders a summary
```

and replace line 69:

```
# Toggles the eotr_religion_convert character flag on the player.
```

with:

```
# Sets or clears the eotr_religion_convert variable on the player's primary title.
```

- [ ] **Step 5: Add the rite sentence to localization**

In `localization/english/eotr_l_english.yml`, replace:

```
 eotr_set_religion_policy_desc:0 "Decide how your vassals should handle religion across the realm. Choose #V Convert#! to push your faith into counties of other faiths. This directive will only be given to vassals who share your faith and control counties with differing faiths. Choose #V None#! to ignore religion entirely."
```

with:

```
 eotr_set_religion_policy_desc:0 "Decide how your vassals should handle religion across the realm. Choose #V Convert#! to push your faith into counties of other faiths. This directive will only be given to vassals who share your faith and control counties with differing faiths. Counties converted by a vassal of another rite of your faith adopt that vassal's rite. Choose #V None#! to ignore religion entirely."
```

and replace:

```
 eotr_religion_policy_convert_tooltip:0 "Vassals who share your faith and hold counties of other faiths will be assigned the #V Convert Faith#! [directive|E] when directives are issued."
```

with:

```
 eotr_religion_policy_convert_tooltip:0 "Vassals who share your faith and hold counties of other faiths will be assigned the #V Convert Faith#! [directive|E] when directives are issued. Counties converted by a vassal of another rite of your faith adopt that vassal's rite."
```

- [ ] **Step 6: Bump version metadata and refresh the launcher pointer**

In `descriptor.mod`, change `version="1.2.3"` to `version="1.3.0"` and `supported_version="1.19.*"` to `supported_version="1.20.*"`. Then:

```bash
scripts/launcher-mod.sh dev
grep -n "version" "$HOME/.local/share/Paradox Interactive/Crusader Kings III/mod/edicts_of_the_realm.mod"
```

Expected: `launcher pointer -> /home/andrew/repos/edicts-of-the-realm`, and the pointer shows `version="1.3.0"` and `supported_version="1.20.*"`.

- [ ] **Step 7: Update README.md**

Replace line 7:

```
Supported game versions: 1.18 "Crane", 1.19 "Scribe".
```

with:

```
Supported game version: 1.20 "Crozier". Version 1.2.3 is the last release for 1.18 "Crane" / 1.19 "Scribe".
```

In the Algorithm section, after the paragraph starting "Heretic vassals never receive `convert_faith`", add:

```

"Faith" means faith, not rite (CK3 1.20+). A vassal of another rite of your faith counts as sharing your faith and can receive `convert_faith`. The vanilla directive only converts counties of other faiths, and a converted county takes the converting vassal's rite.
```

- [ ] **Step 8: Add the CHANGELOG entry**

Insert directly above `## [1.2.3] — 2026-09-22`:

```
## [1.3.0] — 2026-10-20

### Changed
- **Requires Crusader Kings III 1.20 "Crozier".** Version 1.2.3 remains the last release for 1.18/1.19.
- **Religion Policy and rites.** "Shares your faith" compares faiths, not rites, so a vassal of another rite of your faith can receive Convert Faith. The vanilla directive only converts counties of other faiths; a county converted this way takes the converting vassal's rite. The Religion Policy tooltips now say so.

### Fixed
- **Automatic Application hooks no longer clash with the base game.** The yearly refresh and the title gained/lost re-evaluations were silently ignored, and the character-culture-change and county-faith-change hooks replaced the game's own logic for those events. All hooks now run alongside the game's.
- **Vassal and player faith changes trigger re-evaluation again.** 1.20 removed the hook the mod used; the mod now uses its replacement and ignores rite-only changes, which cannot affect any directive.
```

If the release ships on a later date, change the date to that day.

- [ ] **Step 9: Update CLAUDE.md**

1. Line 9: replace

   ```
   Target game versions: 1.18 "Crane" and 1.19 "Scribe" (`supported_version="1.*.*"` in [descriptor.mod](descriptor.mod)).
   ```

   with

   ```
   Target game version: 1.20 "Crozier" (`supported_version="1.20.*"` in [descriptor.mod](descriptor.mod)). 1.2.3 is the last 1.18/1.19 build.
   ```

2. Line 68: in the on_action file description, replace `` `on_character_faith_change`/`on_character_culture_change` `` with `` `on_rite_change` (character faith; skips rite-only changes)/`on_character_culture_change` ``, and add after "All gated on the realm's top liege being a player with `eotr_auto_apply` set.": `` Each body is its own `eotr_<hook>` on_action, appended to the vanilla on_action with `on_actions = { ... }`. ``

3. Line 83: replace `` Use `"1.19.*"` (Scribe) or `"1.18.*"` (Crane). CK3 can't express "either" — pick one and rely on the yellow launcher warning for the other. `` with `` Currently `"1.20.*"` (Crozier). CK3 can't express a range — pick one and rely on the yellow launcher warning for others. ``

4. Line 91: replace `(yearly + title gain/lost + character faith/culture + county faith/culture)` with `` (yearly + title gain/lost + character faith via `on_rite_change`/culture + county faith/culture). `on_county_rite_change` and `on_faith_created` are deliberately excluded: rite-only changes can't affect a faith check, and faith splits already fire `on_rite_change` per character ``.

5. Add to "Conventions to preserve", after the "Auto-apply hooks gate on the realm's top liege" bullet:

   ```
   - **Never write `effect` (or `trigger`) directly on a vanilla on_action.** Only one `effect` per on_action survives the merge, so a mod's either replaces vanilla's or is silently dropped (`error.log`: "There is more than one 'effect' defined"). Put the body in an `eotr_<hook>` on_action and attach it with `<vanilla_hook> = { on_actions = { eotr_<hook> } }`, which appends. The child gets the parent's root and saved scopes. Code on_actions run on the next game day after the change, never while paused, so in-game tests must unpause a day before checking.
   ```

- [ ] **Step 10: Static checks**

```bash
for f in common/scripted_triggers/eotr_triggers.txt common/scripted_effects/eotr_effects.txt common/decisions/eotr_decisions.txt localization/english/eotr_l_english.yml; do printf '%s ' "$f"; head -c 3 "$f" | xxd -p; done
grep -n "character flag" common/decisions/eotr_decisions.txt
grep -c "adopt that vassal's rite" localization/english/eotr_l_english.yml
grep -n "1.19\|1.18" README.md CLAUDE.md descriptor.mod
```

Expected:
- Four lines ending `efbbbf`.
- No `character flag` lines in the comments edited above. Others may remain only if they describe the vassal-side output flags.
- `2`.
- Only the new "last release/build for 1.18/1.19" lines, plus historical notes such as "verified against vanilla 1.19" in CLAUDE.md.

- [ ] **Step 11: Verify in game**

Files hot-reload. Ask the user to hover over the Convert option of "Set Religion Policy" again.
Expected: the tooltip ends with "Counties converted by a vassal of another rite of your faith adopt that vassal's rite." Then:

```bash
grep -n "eotr" ~/.local/share/"Paradox Interactive/Crusader Kings III/logs/error.log"
```

Expected: no output.

- [ ] **Step 12: Commit**

```bash
git add common/scripted_triggers/eotr_triggers.txt common/scripted_effects/eotr_effects.txt common/decisions/eotr_decisions.txt localization/english/eotr_l_english.yml descriptor.mod README.md CHANGELOG.md CLAUDE.md
git commit -m "Release 1.3.0: CK3 1.20 Crozier support

Document that Religion Policy compares faiths, not rites, and that counties
converted by a vassal of another rite take that vassal's rite. Bump to 1.3.0
and supported_version 1.20.*; update README, CHANGELOG and CLAUDE.md
(on_rite_change, on_actions append convention).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Release verification and cleanup

**Files:**
- Delete: `common/on_action/eotr_zz_probe.txt` (untracked, never committed)
- Modify: `.git/info/exclude` (remove the probe line; local only)
- Modify: `docs/superpowers/specs/2026-10-01-rite-aware-religion-policy-design.md` (status line)
- Add: `docs/superpowers/plans/2026-10-20-crozier-port.md` (this plan) and the spec, if not yet committed

**Interfaces:**
- Consumes: Tasks 1 and 2 committed.
- Produces: nothing new in code.

- [ ] **Step 1: Old-save check (optional, skipped by default)**

Skipped at the user's request (2026-10-20). Run it only if a save made with the 1.2.3 code is available.


`eotr_crozier_test` was saved by the 1.2.3 code (Task 1, Step 1). Reload it with the new code and open "View Current Settings".
Expected: Religion Policy shows "Convert", and the other settings are as configured.

- [ ] **Step 2: Candidate rule per vassal class (manual Apply)**

Each case: reload `eotr_crozier_test`, run the setup lines, take "Issue Directives to the Realm", then CHECK `c_kranj` for both flags. No unpause needed, because Apply runs immediately.

Aligned vassal (same rite as the player) holding a pagan county:

```
effect title:c_kranj.holder = { set_character_rite = <the player's rite, e.g. rite:carolingian_christianity> }
```

Expected: `convert_faith=yes`.

Cousin (same faith, other rite) holding a pagan county: no setup, the save already is this case.
Expected: `convert_faith=yes`.

Cousin holding only a same-faith county of another rite:

```
effect title:c_kranj = { set_county_faith = faith:christian_faith }
effect title:c_kranj = { set_county_rite = rite:roman_rite }
```

Expected: `convert_faith=no`, `building_focus_economy=yes`. A rite-only mismatch isn't work for the directive.

Foreign vassal: covered by Task 1, Step 6.

- [ ] **Step 3: Great Schism end-to-end (Review Focus 5)**

Reload `eotr_crozier_test`, then:

```
event great_schism.0001
```

Unpause one day, pause. CHECK `c_kranj` / `vassal_directive_convert_faith`, then CHECK `c_kranj` / `vassal_directive_building_focus_economy`.
Expected: `convert_faith=no`, `building_focus_economy=yes`. The Greek-rite vassal became Orthodox while the player became Catholic, so he's Foreign now. Then:

```bash
grep -n "eotr" ~/.local/share/"Paradox Interactive/Crusader Kings III/logs/error.log"
```

Expected: no output.

- [ ] **Step 4: Rite detaches to a new faith, end-to-end**

Reload `eotr_crozier_test`, then:

```
effect title:c_kranj.holder = { detach_rite_to_new_faith = { target = rite:byzantine_rite } }
```

Unpause one day, pause. CHECK `c_kranj` / `vassal_directive_convert_faith`.
Expected: `=no`. The vassal's rite is now its own faith, so he's Foreign.

- [ ] **Step 5: Remove the probe**

```bash
rm common/on_action/eotr_zz_probe.txt
sed -i '\|common/on_action/eotr_zz_probe.txt|d' .git/info/exclude
git status --short
```

Expected: `git status` doesn't list the probe file.

- [ ] **Step 6: Mark the spec implemented**

In `docs/superpowers/specs/2026-10-01-rite-aware-religion-policy-design.md`, replace

```
Status: **draft, not implemented.** First written 2026-10-01 against
```

with

```
Status: **implemented in 1.3.0** (plan: `docs/superpowers/plans/2026-10-20-crozier-port.md`). First written 2026-10-01 against
```

- [ ] **Step 7: Commit**

```bash
git add docs/superpowers/specs/2026-10-01-rite-aware-religion-policy-design.md docs/superpowers/plans/2026-10-20-crozier-port.md
git commit -m "Add Crozier port spec and plan; mark spec implemented

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Packaging and upload (`scripts/launcher-mod.sh upload` / `zip`) are a separate, user-driven step and are not part of this plan.
