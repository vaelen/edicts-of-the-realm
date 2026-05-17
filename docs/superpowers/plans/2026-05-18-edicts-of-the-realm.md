# Edicts of the Realm Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the "Edicts of the Realm" Crusader Kings 3 mod from the spec at `docs/superpowers/specs/2026-05-17-edicts-of-the-realm-design.md` — five decisions (four persistent settings + one Apply) that smart-assign vanilla `vassal_directive_*` flags across every sub-realm vassal based on each vassal's faith, culture, and lands.

**Architecture:** Pure-PdxScript CK3 mod. Five decisions stored as character flags on the player; one scripted effect (`eotr_evaluate_and_assign_directive`) called via `every_vassal_or_below` from the Apply decision; two scripted triggers detect misaligned counties. No new directive types, no scripted GUI, no GUI markup overrides — only standard `common/` script files and one English localization file.

**Tech Stack:** PdxScript (Crusader Kings 3 scripting language), YAML localization (UTF-8 BOM), CK3 1.18 "Crane" / 1.19 "Scribe" supported version range.

---

## Development environment setup (one-time, do this before Task 1)

CK3 loads mods from `~/Documents/Paradox Interactive/Crusader Kings III/mod/`. Symlink the dev repo so edits show up live:

```bash
ln -s "/Users/andrew/repos/subject-directives-mod" "$HOME/Documents/Paradox Interactive/Crusader Kings III/mod/edicts_of_the_realm"
```

CK3 ALSO needs a launcher-readable `.mod` file at `mod/edicts_of_the_realm.mod`. Create it (this is separate from the `descriptor.mod` we'll add in Task 1):

```bash
cat > "$HOME/Documents/Paradox Interactive/Crusader Kings III/mod/edicts_of_the_realm.mod" <<'EOF'
version="0.1.0"
tags={
	"Decisions"
	"Gameplay"
	"Utilities"
}
name="Edicts of the Realm"
path="mod/edicts_of_the_realm"
supported_version="1.*.*"
EOF
```

Enable "Debug Mode" in the launcher (Game Settings → Launch Arguments → add `-debug_mode`). This unlocks the in-game console (`` ` `` key) and writes errors to `~/Documents/Paradox Interactive/Crusader Kings III/logs/error.log`.

Useful console commands you will use throughout this plan:

| Command | Purpose |
|---|---|
| `reload` | Reloads all script files (decisions, effects, triggers) without restarting the game |
| `reload localization` | Reloads localization YAML |
| `add_character_flag <flag>` | Adds a flag to the current player character |
| `remove_character_flag <flag>` | Removes a flag from the current player character |
| `effect { <inline script> }` | Runs an inline scripted effect on the current player |
| `play <character_id>` | Switches to play as another character |
| `event <event_id>` | Fires an event |
| `clear` | Clears the console |

After each task, run `reload` in the in-game console, then check `error.log` for new errors (the file is appended; the most recent errors are at the bottom).

---

## Task 1: Mod skeleton — descriptor.mod, README, repo bootstrap

**Files:**
- Create: `descriptor.mod`
- Create: `README.md`
- Create: `.gitignore`
- Create: `Credits.txt`

- [ ] **Step 1: Write the descriptor**

Create `descriptor.mod` at the repo root:

```
version="0.1.0"
tags={
	"Decisions"
	"Gameplay"
	"Utilities"
}
name="Edicts of the Realm"
supported_version="1.*.*"
```

- [ ] **Step 2: Write a minimal README**

Create `README.md`:

```markdown
# Edicts of the Realm

A Crusader Kings 3 mod that lets you define a smart realm-wide policy for vassal directives and apply it across every sub-realm vassal in one click. Each vassal receives an appropriate `vassal_directive_*` flag based on their own faith and culture vs. the lands they hold.

Supported game versions: 1.18 "Crane", 1.19 "Scribe".

## Installation (non-Steam)

Clone this repo into `~/Documents/Paradox Interactive/Crusader Kings III/mod/edicts_of_the_realm/` (or symlink it there), then create the matching `edicts_of_the_realm.mod` file as described in the dev plan. Enable in the launcher.

## Credits

See `Credits.txt`.
```

- [ ] **Step 3: Write Credits**

Create `Credits.txt`:

```
Edicts of the Realm

Inspired by Better Mass Vassal Directive
  by Wehrmachtserdbeere and Nightwolf
  https://github.com/Wehrmachtserdbeere/better_mass_vassal_directive
```

- [ ] **Step 4: Add .gitignore**

Create `.gitignore`:

```
# macOS
.DS_Store

# Editor
.vscode/
.idea/
*.swp

# CK3 build artifacts (none for now, but reserve)
*.log
```

- [ ] **Step 5: Verify game can load the (empty) mod**

1. Make sure the symlink and `.mod` file from "Development environment setup" exist.
2. Launch CK3.
3. Enable "Edicts of the Realm" in the launcher.
4. Click "Play".
5. Start a quick game (any character).
6. Open the console (`` ` ``), type `reload`, press Enter.
7. Tab out of the game, open `~/Documents/Paradox Interactive/Crusader Kings III/logs/error.log` in an editor.

Expected: no new errors mentioning `edicts_of_the_realm` or any `eotr_*` identifier. The mod loads successfully even though it adds nothing yet.

- [ ] **Step 6: Commit**

```bash
git add descriptor.mod README.md Credits.txt .gitignore
git commit -m "Task 1: mod skeleton (descriptor, README, credits, gitignore)"
```

---

## Task 2: Custom decision group type

**Files:**
- Create: `common/decision_group_types/eotr_decision_group.txt`
- Create: `localization/english/eotr_l_english.yml`

- [ ] **Step 1: Define the decision group**

Create `common/decision_group_types/eotr_decision_group.txt`:

```
eotr_realm_directives = {
	sort_order = 7
}
```

`sort_order = 7` places it between vanilla `major` (2) and `important` (8) — a custom slot just above standard decisions in the UI. Adjust later if visual placement is wrong.

- [ ] **Step 2: Add the group's display name to localization**

Create `localization/english/eotr_l_english.yml` (the file MUST start with a UTF-8 BOM — most editors handle this automatically when you set encoding to "UTF-8 with BOM"; if your editor doesn't, run `printf '\xEF\xBB\xBF' > localization/english/eotr_l_english.yml` first):

```yaml
l_english:
 decision_group_type_eotr_realm_directives:0 "Edicts of the Realm"
```

- [ ] **Step 3: Verify the group loads without errors**

1. In-game console: `reload`
2. Then: `reload localization`
3. Check `error.log` for any line mentioning `eotr_decision_group` or `decision_group_type_eotr_realm_directives`.

Expected: no errors. (You won't see the group in the UI yet — it appears only when a decision references it. That's Task 5.)

- [ ] **Step 4: Commit**

```bash
git add common/decision_group_types/eotr_decision_group.txt localization/english/eotr_l_english.yml
git commit -m "Task 2: custom decision group eotr_realm_directives"
```

---

## Task 3: Scripted triggers — misaligned-county detectors

**Files:**
- Create: `common/scripted_triggers/eotr_triggers.txt`

- [ ] **Step 1: Write the two scripted triggers**

Create `common/scripted_triggers/eotr_triggers.txt`:

```
# True if the character holds at least one county whose faith differs from
# the character's own faith. Used to decide whether vassal_directive_convert_faith
# would have any work to do.
eotr_has_faith_misaligned_county = {
	any_held_county = {
		NOT = { faith = prev.faith }
	}
}

# True if the character holds at least one county whose culture differs from
# the character's own culture. Used for both convert_culture and
# improve_cultural_acceptance candidate checks.
eotr_has_culture_misaligned_county = {
	any_held_county = {
		NOT = { culture = prev.culture }
	}
}
```

- [ ] **Step 2: Verify the triggers parse correctly**

1. In-game console: `reload`
2. Check `error.log` for any line mentioning `eotr_has_faith_misaligned_county` or `eotr_has_culture_misaligned_county`.
3. Functional smoke test: open the console and run

```
effect { if = { limit = { eotr_has_faith_misaligned_county = yes } debug_log = "FAITH_MISALIGNED" } else = { debug_log = "FAITH_ALIGNED" } }
```

Then check `error.log` (debug_log writes there too) for either `FAITH_MISALIGNED` or `FAITH_ALIGNED`. Repeat for culture:

```
effect { if = { limit = { eotr_has_culture_misaligned_county = yes } debug_log = "CULTURE_MISALIGNED" } else = { debug_log = "CULTURE_ALIGNED" } }
```

Expected: exactly one of the two messages appears for each. Which one depends on which character you're playing. If you started as a single-county count of homogeneous lands, both should log "_ALIGNED".

- [ ] **Step 3: Commit**

```bash
git add common/scripted_triggers/eotr_triggers.txt
git commit -m "Task 3: scripted triggers for misaligned-county detection"
```

---

## Task 4: Scripted effect — per-vassal evaluator

**Files:**
- Create: `common/scripted_effects/eotr_effects.txt`

This is the algorithmic heart of the mod. The effect runs on a vassal scope with `root` = the player who invoked the Apply decision.

- [ ] **Step 1: Write the evaluator effect**

Create `common/scripted_effects/eotr_effects.txt`:

```
# Per-vassal evaluator. Runs on the VASSAL scope; root = the player (liege).
#
# Logic mirrors docs/superpowers/specs/2026-05-17-edicts-of-the-realm-design.md
# Section 4 "Per-vassal evaluation algorithm".
#
# Stages each candidate as a temp variable on the vassal, then resolves via
# the player's priority flag, then falls through to the default edict.
eotr_evaluate_and_assign_directive = {
	# --- Religion candidate ---
	# Only fires when player has Religion=Convert AND vassal shares player's
	# faith AND vassal has at least one misaligned county. Heretic vassals
	# never get convert_faith (it would spread heresy).
	if = {
		limit = {
			root = { has_character_flag = eotr_religion_convert }
			faith = root.faith
			eotr_has_faith_misaligned_county = yes
		}
		set_variable = { name = eotr_pick_religion_convert value = yes }
	}

	# --- Culture candidate ---
	# Convert path: only when vassal shares player's culture AND has a misaligned county.
	if = {
		limit = {
			root = { has_character_flag = eotr_culture_convert }
			culture = root.culture
			eotr_has_culture_misaligned_county = yes
		}
		set_variable = { name = eotr_pick_culture_convert value = yes }
	}
	# Acceptance path: independent of liege's culture; only the vassal-vs-lands diversity matters.
	else_if = {
		limit = {
			root = { has_character_flag = eotr_culture_accept }
			eotr_has_culture_misaligned_county = yes
		}
		set_variable = { name = eotr_pick_culture_accept value = yes }
	}

	# --- Clear any prior directive (vanilla or from a previous run of this mod) ---
	remove_vassal_directives = yes

	# --- Resolve ---
	if = {
		# Both religion and culture candidates fired -> use priority
		limit = {
			has_variable = eotr_pick_religion_convert
			OR = {
				has_variable = eotr_pick_culture_convert
				has_variable = eotr_pick_culture_accept
			}
		}
		if = {
			limit = { root = { has_character_flag = eotr_priority_religion } }
			add_character_flag = vassal_directive_convert_faith
		}
		else = {
			# Culture wins
			if = {
				limit = { has_variable = eotr_pick_culture_convert }
				add_character_flag = vassal_directive_convert_culture
			}
			else = {
				add_character_flag = vassal_directive_improve_cultural_acceptance
			}
		}
	}
	else_if = {
		limit = { has_variable = eotr_pick_religion_convert }
		add_character_flag = vassal_directive_convert_faith
	}
	else_if = {
		limit = { has_variable = eotr_pick_culture_convert }
		add_character_flag = vassal_directive_convert_culture
	}
	else_if = {
		limit = { has_variable = eotr_pick_culture_accept }
		add_character_flag = vassal_directive_improve_cultural_acceptance
	}
	else = {
		# --- Default edict fallthrough ---
		if = {
			limit = { root = { has_character_flag = eotr_default_prosperity } }
			add_character_flag = vassal_directive_building_focus_economy
		}
		else_if = {
			limit = { root = { has_character_flag = eotr_default_bulwark } }
			add_character_flag = vassal_directive_building_focus_fortification
		}
		else_if = {
			limit = { root = { has_character_flag = eotr_default_martial } }
			add_character_flag = vassal_directive_building_focus_military
		}
		# else: eotr_default_none or no default set -> leave cleared
	}

	# --- Cleanup the temp variables (no-op if not set) ---
	remove_variable = eotr_pick_religion_convert
	remove_variable = eotr_pick_culture_convert
	remove_variable = eotr_pick_culture_accept
}
```

- [ ] **Step 2: Verify it parses**

1. Console: `reload`
2. Check `error.log` for any mention of `eotr_evaluate_and_assign_directive`.

Expected: no errors.

- [ ] **Step 3: Smoke-test by invoking on a real vassal**

Functional test: pick a vassal whose ID you can read from a debug tooltip (with `-debug_mode` enabled, hovering over a character shows their ID). Then run, substituting `<id>`:

```
effect { add_character_flag = eotr_religion_convert add_character_flag = eotr_priority_religion add_character_flag = eotr_default_prosperity every_vassal = { limit = { this = character:<id> } eotr_evaluate_and_assign_directive = yes } }
```

This temporarily sets policy flags on yourself, then runs the evaluator on one specific vassal. After running, hover the vassal; their character window should show a `vassal_directive_*` flag in the "Modifiers" or character flag list (visible with debug mode). Note which one was assigned and whether it matches the spec's algorithm given that vassal's faith/culture/lands.

Then clear the test state:

```
effect { remove_character_flag = eotr_religion_convert remove_character_flag = eotr_priority_religion remove_character_flag = eotr_default_prosperity }
```

Expected: the vassal receives one of `vassal_directive_convert_faith`, `vassal_directive_convert_culture`, `vassal_directive_improve_cultural_acceptance`, or `vassal_directive_building_focus_economy` depending on their situation per the spec.

- [ ] **Step 4: Commit**

```bash
git add common/scripted_effects/eotr_effects.txt
git commit -m "Task 4: eotr_evaluate_and_assign_directive scripted effect"
```

---

## Task 5: Setting decision — Religion Policy

**Files:**
- Create: `common/decisions/eotr_decisions.txt` (start of file; later tasks append to it)
- Modify: `localization/english/eotr_l_english.yml` (append)

- [ ] **Step 1: Write the religion policy decision**

Create `common/decisions/eotr_decisions.txt`:

```
# Setting 1 of 4: Religion Policy
# Toggles the eotr_religion_convert character flag on the player.
eotr_set_religion_policy = {
	picture = "gfx/interface/illustrations/decisions/fp2_decision_struggle_compromise.dds"
	decision_group_type = eotr_realm_directives

	desc = eotr_set_religion_policy_desc
	selection_tooltip = eotr_set_religion_policy_tooltip
	confirm_text = eotr_set_religion_policy_confirm

	is_shown = {
		is_landed = yes
		is_ai = no
	}

	is_valid_showing_failures_only = {}

	widget = {
		gui = "decision_view_widget_decision_option_list_controller"
		controller = decision_option_list_controller

		item = {
			value = eotr_religion_policy_convert
			current_description = eotr_religion_policy_convert_tooltip
			localization = eotr_religion_policy_convert_label
		}
		item = {
			value = eotr_religion_policy_none
			current_description = eotr_religion_policy_none_tooltip
			localization = eotr_religion_policy_none_label
		}
	}

	effect = {
		# Clear any prior selection in this category
		remove_character_flag = eotr_religion_convert

		# Apply the chosen option
		switch = {
			trigger = yes

			scope:eotr_religion_policy_convert ?= {
				custom_tooltip = eotr_religion_policy_convert_effect_tooltip
				add_character_flag = eotr_religion_convert
			}
			scope:eotr_religion_policy_none ?= {
				custom_tooltip = eotr_religion_policy_none_effect_tooltip
				# Nothing to add — already cleared
			}
		}
	}

	ai_will_do = { base = 0 }
	ai_check_interval = 0
}
```

- [ ] **Step 2: Append localization strings**

Append to `localization/english/eotr_l_english.yml` (the file already starts with `l_english:`; add these indented one space under it):

```yaml
 # Religion Policy decision
 eotr_set_religion_policy:0 "Set Religion Policy"
 eotr_set_religion_policy_desc:0 "Decide how your vassals should handle religion across the realm. Pick #V Convert#! to push your faith into mismatched counties (only safe on same-faith vassals), or #V None#! to ignore religion."
 eotr_set_religion_policy_tooltip:0 "Choose how Edicts of the Realm handles religion when issuing realm-wide directives."
 eotr_set_religion_policy_confirm:0 "Set Religion Policy"

 eotr_religion_policy_convert_label:0 "Convert"
 eotr_religion_policy_convert_tooltip:0 "Vassals who share your faith and hold misaligned counties will be assigned [vassal_directive_convert_faith|E] when directives are issued."
 eotr_religion_policy_convert_effect_tooltip:0 "Religion Policy set to #V Convert#!."

 eotr_religion_policy_none_label:0 "None"
 eotr_religion_policy_none_tooltip:0 "Religion is ignored when directives are issued."
 eotr_religion_policy_none_effect_tooltip:0 "Religion Policy set to #V None#!."
```

- [ ] **Step 3: Verify the decision appears and works**

1. Console: `reload`, then `reload localization`.
2. Open the decisions tab. You should see an "Edicts of the Realm" group containing "Set Religion Policy".
3. Click it. The option list shows "Convert" and "None".
4. Pick "Convert" and confirm.
5. Verify the flag was set: console command `effect { if = { limit = { has_character_flag = eotr_religion_convert } debug_log = "RELIGION_CONVERT_SET" } else = { debug_log = "RELIGION_CONVERT_NOT_SET" } }` then check `error.log`.
6. Open the decision again, pick "None", confirm.
7. Repeat the flag check — should now log `RELIGION_CONVERT_NOT_SET`.

Expected: flag toggles correctly between Convert and None.

- [ ] **Step 4: Commit**

```bash
git add common/decisions/eotr_decisions.txt localization/english/eotr_l_english.yml
git commit -m "Task 5: Religion Policy setting decision"
```

---

## Task 6: Setting decision — Culture Policy

**Files:**
- Modify: `common/decisions/eotr_decisions.txt` (append)
- Modify: `localization/english/eotr_l_english.yml` (append)

- [ ] **Step 1: Append the culture policy decision**

Append to `common/decisions/eotr_decisions.txt`:

```
# Setting 2 of 4: Culture Policy
# Toggles eotr_culture_convert OR eotr_culture_accept on the player (mutually exclusive).
eotr_set_culture_policy = {
	picture = "gfx/interface/illustrations/decisions/fp2_decision_struggle_compromise.dds"
	decision_group_type = eotr_realm_directives

	desc = eotr_set_culture_policy_desc
	selection_tooltip = eotr_set_culture_policy_tooltip
	confirm_text = eotr_set_culture_policy_confirm

	is_shown = {
		is_landed = yes
		is_ai = no
	}

	is_valid_showing_failures_only = {}

	widget = {
		gui = "decision_view_widget_decision_option_list_controller"
		controller = decision_option_list_controller

		item = {
			value = eotr_culture_policy_convert
			current_description = eotr_culture_policy_convert_tooltip
			localization = eotr_culture_policy_convert_label
		}
		item = {
			value = eotr_culture_policy_accept
			current_description = eotr_culture_policy_accept_tooltip
			localization = eotr_culture_policy_accept_label
		}
		item = {
			value = eotr_culture_policy_none
			current_description = eotr_culture_policy_none_tooltip
			localization = eotr_culture_policy_none_label
		}
	}

	effect = {
		remove_character_flag = eotr_culture_convert
		remove_character_flag = eotr_culture_accept

		switch = {
			trigger = yes

			scope:eotr_culture_policy_convert ?= {
				custom_tooltip = eotr_culture_policy_convert_effect_tooltip
				add_character_flag = eotr_culture_convert
			}
			scope:eotr_culture_policy_accept ?= {
				custom_tooltip = eotr_culture_policy_accept_effect_tooltip
				add_character_flag = eotr_culture_accept
			}
			scope:eotr_culture_policy_none ?= {
				custom_tooltip = eotr_culture_policy_none_effect_tooltip
			}
		}
	}

	ai_will_do = { base = 0 }
	ai_check_interval = 0
}
```

- [ ] **Step 2: Append localization**

Append to `localization/english/eotr_l_english.yml`:

```yaml
 # Culture Policy decision
 eotr_set_culture_policy:0 "Set Culture Policy"
 eotr_set_culture_policy_desc:0 "Decide how your vassals should handle culture. Pick #V Convert#! to push your culture into mismatched counties (only safe on same-culture vassals), #V Acceptance#! to improve cultural acceptance for any vassal whose lands include foreign cultures, or #V None#! to ignore culture."
 eotr_set_culture_policy_tooltip:0 "Choose how Edicts of the Realm handles culture when issuing realm-wide directives."
 eotr_set_culture_policy_confirm:0 "Set Culture Policy"

 eotr_culture_policy_convert_label:0 "Convert"
 eotr_culture_policy_convert_tooltip:0 "Vassals who share your culture and hold counties of differing cultures will be assigned [vassal_directive_convert_culture|E]."
 eotr_culture_policy_convert_effect_tooltip:0 "Culture Policy set to #V Convert#!."

 eotr_culture_policy_accept_label:0 "Acceptance"
 eotr_culture_policy_accept_tooltip:0 "Any vassal whose lands include at least one county of a different culture than the vassal will be assigned [vassal_directive_improve_cultural_acceptance|E]."
 eotr_culture_policy_accept_effect_tooltip:0 "Culture Policy set to #V Acceptance#!."

 eotr_culture_policy_none_label:0 "None"
 eotr_culture_policy_none_tooltip:0 "Culture is ignored when directives are issued."
 eotr_culture_policy_none_effect_tooltip:0 "Culture Policy set to #V None#!."
```

- [ ] **Step 3: Verify the decision works and flags are mutually exclusive**

1. Console: `reload`, `reload localization`.
2. Open decisions, pick "Set Culture Policy" → choose "Convert".
3. Verify in console: 
```
effect { if = { limit = { has_character_flag = eotr_culture_convert } debug_log = "CULTURE=CONVERT" } else_if = { limit = { has_character_flag = eotr_culture_accept } debug_log = "CULTURE=ACCEPT" } else = { debug_log = "CULTURE=NONE" } }
```
Check `error.log` for `CULTURE=CONVERT`.
4. Pick "Acceptance" via the decision. Re-run the check — should log `CULTURE=ACCEPT`. The previous `eotr_culture_convert` flag must be gone (the decision clears both flags before adding the new one).
5. Pick "None". Re-run the check — `CULTURE=NONE`.

Expected: flags are mutually exclusive, the decision clears the old before setting the new.

- [ ] **Step 4: Commit**

```bash
git add common/decisions/eotr_decisions.txt localization/english/eotr_l_english.yml
git commit -m "Task 6: Culture Policy setting decision"
```

---

## Task 7: Setting decision — Priority

**Files:**
- Modify: `common/decisions/eotr_decisions.txt` (append)
- Modify: `localization/english/eotr_l_english.yml` (append)

- [ ] **Step 1: Append the priority decision**

Append to `common/decisions/eotr_decisions.txt`:

```
# Setting 3 of 4: Priority
# Used only when both Religion and Culture policies produce a candidate for the same vassal.
eotr_set_priority = {
	picture = "gfx/interface/illustrations/decisions/fp2_decision_struggle_compromise.dds"
	decision_group_type = eotr_realm_directives

	desc = eotr_set_priority_desc
	selection_tooltip = eotr_set_priority_tooltip
	confirm_text = eotr_set_priority_confirm

	is_shown = {
		is_landed = yes
		is_ai = no
	}

	is_valid_showing_failures_only = {}

	widget = {
		gui = "decision_view_widget_decision_option_list_controller"
		controller = decision_option_list_controller

		item = {
			value = eotr_priority_religion_opt
			current_description = eotr_priority_religion_tooltip
			localization = eotr_priority_religion_label
		}
		item = {
			value = eotr_priority_culture_opt
			current_description = eotr_priority_culture_tooltip
			localization = eotr_priority_culture_label
		}
	}

	effect = {
		remove_character_flag = eotr_priority_religion
		remove_character_flag = eotr_priority_culture

		switch = {
			trigger = yes

			scope:eotr_priority_religion_opt ?= {
				custom_tooltip = eotr_priority_religion_effect_tooltip
				add_character_flag = eotr_priority_religion
			}
			scope:eotr_priority_culture_opt ?= {
				custom_tooltip = eotr_priority_culture_effect_tooltip
				add_character_flag = eotr_priority_culture
			}
		}
	}

	ai_will_do = { base = 0 }
	ai_check_interval = 0
}
```

Note: the option scope tokens (`eotr_priority_religion_opt`) are suffixed `_opt` to keep them distinct from the persistent flag names (`eotr_priority_religion`). Option scope tokens and character flag names must not collide.

- [ ] **Step 2: Append localization**

Append to `localization/english/eotr_l_english.yml`:

```yaml
 # Priority decision
 eotr_set_priority:0 "Set Conflict Priority"
 eotr_set_priority_desc:0 "When both your Religion and Culture policies produce a directive for the same vassal, this setting decides which wins. Has no effect when only one (or neither) policy is active."
 eotr_set_priority_tooltip:0 "Decide whether religion or culture wins when both apply to the same vassal."
 eotr_set_priority_confirm:0 "Set Priority"

 eotr_priority_religion_label:0 "Religion First"
 eotr_priority_religion_tooltip:0 "When both apply, the religion directive wins."
 eotr_priority_religion_effect_tooltip:0 "Priority set to #V Religion First#!."

 eotr_priority_culture_label:0 "Culture First"
 eotr_priority_culture_tooltip:0 "When both apply, the culture directive wins."
 eotr_priority_culture_effect_tooltip:0 "Priority set to #V Culture First#!."
```

- [ ] **Step 3: Verify**

1. Console: `reload`, `reload localization`.
2. Open decisions, pick "Set Conflict Priority" → "Religion First".
3. Verify:
```
effect { if = { limit = { has_character_flag = eotr_priority_religion } debug_log = "PRIO=RELIGION" } else_if = { limit = { has_character_flag = eotr_priority_culture } debug_log = "PRIO=CULTURE" } else = { debug_log = "PRIO=UNSET" } }
```
Expected: `PRIO=RELIGION`.
4. Pick "Culture First" via the decision. Re-check — `PRIO=CULTURE`.

- [ ] **Step 4: Commit**

```bash
git add common/decisions/eotr_decisions.txt localization/english/eotr_l_english.yml
git commit -m "Task 7: Priority setting decision"
```

---

## Task 8: Setting decision — Default Edict

**Files:**
- Modify: `common/decisions/eotr_decisions.txt` (append)
- Modify: `localization/english/eotr_l_english.yml` (append)

- [ ] **Step 1: Append the default edict decision**

Append to `common/decisions/eotr_decisions.txt`:

```
# Setting 4 of 4: Default Edict
# Used when no Religion or Culture candidate fires for a vassal.
# "None" option causes those vassals to have all directives cleared (no replacement).
eotr_set_default_edict = {
	picture = "gfx/interface/illustrations/decisions/fp2_decision_struggle_compromise.dds"
	decision_group_type = eotr_realm_directives

	desc = eotr_set_default_edict_desc
	selection_tooltip = eotr_set_default_edict_tooltip
	confirm_text = eotr_set_default_edict_confirm

	is_shown = {
		is_landed = yes
		is_ai = no
	}

	is_valid_showing_failures_only = {}

	widget = {
		gui = "decision_view_widget_decision_option_list_controller"
		controller = decision_option_list_controller

		item = {
			value = eotr_default_prosperity_opt
			current_description = eotr_default_prosperity_tooltip
			localization = eotr_default_prosperity_label
		}
		item = {
			value = eotr_default_bulwark_opt
			current_description = eotr_default_bulwark_tooltip
			localization = eotr_default_bulwark_label
		}
		item = {
			value = eotr_default_martial_opt
			current_description = eotr_default_martial_tooltip
			localization = eotr_default_martial_label
		}
		item = {
			value = eotr_default_none_opt
			current_description = eotr_default_none_tooltip
			localization = eotr_default_none_label
		}
	}

	effect = {
		remove_character_flag = eotr_default_prosperity
		remove_character_flag = eotr_default_bulwark
		remove_character_flag = eotr_default_martial
		remove_character_flag = eotr_default_none

		switch = {
			trigger = yes

			scope:eotr_default_prosperity_opt ?= {
				custom_tooltip = eotr_default_prosperity_effect_tooltip
				add_character_flag = eotr_default_prosperity
			}
			scope:eotr_default_bulwark_opt ?= {
				custom_tooltip = eotr_default_bulwark_effect_tooltip
				add_character_flag = eotr_default_bulwark
			}
			scope:eotr_default_martial_opt ?= {
				custom_tooltip = eotr_default_martial_effect_tooltip
				add_character_flag = eotr_default_martial
			}
			scope:eotr_default_none_opt ?= {
				custom_tooltip = eotr_default_none_effect_tooltip
				add_character_flag = eotr_default_none
			}
		}
	}

	ai_will_do = { base = 0 }
	ai_check_interval = 0
}
```

Note: `eotr_default_none` is stored as an explicit flag (not just absence-of-flag) so the player can distinguish "I picked None" from "I never set this". The evaluator effect from Task 4 already treats absence and `eotr_default_none` the same way (both leave the directive cleared) — so behavior is identical, but the explicit flag lets the UI show what was chosen.

- [ ] **Step 2: Append localization**

Append to `localization/english/eotr_l_english.yml`:

```yaml
 # Default Edict decision
 eotr_set_default_edict:0 "Set Default Edict"
 eotr_set_default_edict_desc:0 "When a vassal falls through both Religion and Culture rules, this directive is applied. Pick #V Foster Prosperity#! for economic building focus, #V Reinforce the Borders#! for fortification focus, #V Marshal the Hosts#! for military building focus, or #V None#! to leave such vassals with no directive."
 eotr_set_default_edict_tooltip:0 "Choose the fallback directive for vassals where no religion or culture rule applies."
 eotr_set_default_edict_confirm:0 "Set Default Edict"

 eotr_default_prosperity_label:0 "Foster Prosperity"
 eotr_default_prosperity_tooltip:0 "Fallback assigns [vassal_directive_building_focus_economy|E]."
 eotr_default_prosperity_effect_tooltip:0 "Default Edict set to #V Foster Prosperity#!."

 eotr_default_bulwark_label:0 "Reinforce the Borders"
 eotr_default_bulwark_tooltip:0 "Fallback assigns [vassal_directive_building_focus_fortification|E]."
 eotr_default_bulwark_effect_tooltip:0 "Default Edict set to #V Reinforce the Borders#!."

 eotr_default_martial_label:0 "Marshal the Hosts"
 eotr_default_martial_tooltip:0 "Fallback assigns [vassal_directive_building_focus_military|E]."
 eotr_default_martial_effect_tooltip:0 "Default Edict set to #V Marshal the Hosts#!."

 eotr_default_none_label:0 "None"
 eotr_default_none_tooltip:0 "No fallback directive; affected vassals have any previous directive cleared."
 eotr_default_none_effect_tooltip:0 "Default Edict set to #V None#!."
```

- [ ] **Step 3: Verify**

1. Console: `reload`, `reload localization`.
2. Open decisions, pick "Set Default Edict" → "Foster Prosperity".
3. Verify:
```
effect { if = { limit = { has_character_flag = eotr_default_prosperity } debug_log = "DEFAULT=PROSPERITY" } else_if = { limit = { has_character_flag = eotr_default_bulwark } debug_log = "DEFAULT=BULWARK" } else_if = { limit = { has_character_flag = eotr_default_martial } debug_log = "DEFAULT=MARTIAL" } else_if = { limit = { has_character_flag = eotr_default_none } debug_log = "DEFAULT=NONE" } else = { debug_log = "DEFAULT=UNSET" } }
```
Expected: `DEFAULT=PROSPERITY`.
4. Cycle through Bulwark, Martial, None; verify each time only one default flag is set.

- [ ] **Step 4: Commit**

```bash
git add common/decisions/eotr_decisions.txt localization/english/eotr_l_english.yml
git commit -m "Task 8: Default Edict setting decision"
```

---

## Task 9: Action decision — Apply Directives to the Realm

**Files:**
- Modify: `common/decisions/eotr_decisions.txt` (append)
- Modify: `localization/english/eotr_l_english.yml` (append)

This is the payoff. It iterates every sub-realm vassal and runs the evaluator from Task 4.

- [ ] **Step 1: Append the apply decision**

Append to `common/decisions/eotr_decisions.txt`:

```
# Action: Issue Directives to the Realm
# Iterates every sub-realm vassal (cascading through tiers) and invokes the
# evaluator on each. Hidden when the player has no matching vassals.
eotr_apply_directives = {
	picture = "gfx/interface/illustrations/decisions/fp2_decision_struggle_compromise.dds"
	decision_group_type = eotr_realm_directives

	desc = eotr_apply_directives_desc
	selection_tooltip = eotr_apply_directives_tooltip
	confirm_text = eotr_apply_directives_confirm

	is_shown = {
		is_landed = yes
		is_ai = no
		any_vassal_or_below = {
			is_landed = yes
			is_ai = yes
			highest_held_title_tier >= tier_county
		}
	}

	is_valid_showing_failures_only = {}

	effect = {
		custom_tooltip = eotr_apply_directives_effect_tooltip
		every_vassal_or_below = {
			limit = {
				is_landed = yes
				is_ai = yes
				highest_held_title_tier >= tier_county
			}
			eotr_evaluate_and_assign_directive = yes
		}
	}

	ai_will_do = { base = 0 }
	ai_check_interval = 0
}
```

- [ ] **Step 2: Append localization**

Append to `localization/english/eotr_l_english.yml`:

```yaml
 # Apply decision
 eotr_apply_directives:0 "Issue Directives to the Realm"
 eotr_apply_directives_desc:0 "Push your current Edicts of the Realm settings across every sub-realm vassal. Each vassal receives a directive matched to their faith, culture, and lands; vassals with nothing to do under your Religion or Culture policies receive your Default Edict (if any)."
 eotr_apply_directives_tooltip:0 "Apply your settings to every landed AI vassal in your sub-realm."
 eotr_apply_directives_confirm:0 "Issue Directives"
 eotr_apply_directives_effect_tooltip:0 "Every landed AI vassal at or below county tier receives a directive based on your current Edicts of the Realm settings."
```

- [ ] **Step 3: Verify the decision appears only when you have vassals**

1. Console: `reload`, `reload localization`.
2. As a single-county count with no vassals: open decisions. "Issue Directives to the Realm" should NOT be in the Edicts of the Realm group. (The four setting decisions should still be present.)
3. `play <a-king-id>` (switch to a king with vassals). Re-open decisions. "Issue Directives to the Realm" should now appear.

- [ ] **Step 4: Verify the action assigns expected directives**

1. As a king with vassals:
2. Open "Set Religion Policy" → Convert.
3. Open "Set Culture Policy" → Acceptance.
4. Open "Set Conflict Priority" → Religion First.
5. Open "Set Default Edict" → Foster Prosperity.
6. Open "Issue Directives to the Realm" → confirm.
7. For each vassal (pick a sample of three different vassals — try one same-faith-same-culture, one different-faith, and one same-faith with foreign lands), open their character window with debug mode on. Check the "Modifiers" / "Character flags" section.

Expected per the spec's algorithm:
- Same-faith vassal, has misaligned counties → `vassal_directive_convert_faith`
- Different-faith vassal whose culture matches yours and whose lands include any foreign culture → `vassal_directive_improve_cultural_acceptance` (religion didn't fire; culture acceptance did)
- Same-faith vassal, no misaligned counties on either axis → `vassal_directive_building_focus_economy` (default fallthrough)

If any vassal received the wrong directive, re-read the relevant branch of Task 4's effect. Possible failure modes:
- Wrong directive type: an `add_character_flag = vassal_directive_*` line is mistyped.
- No directive at all: priority/culture flag never got set; check Task 5–8 verifications.
- All vassals get the same directive: check that the evaluator runs once per vassal (the `every_vassal_or_below` block in Task 9).

- [ ] **Step 5: Verify idempotency**

1. Run "Issue Directives to the Realm" twice in a row.
2. Each vassal should still have exactly one `vassal_directive_*` flag (not two), because the evaluator's `remove_vassal_directives = yes` clears the prior flag before adding the new one.

- [ ] **Step 6: Verify the "clear everything" flow**

1. Open "Set Religion Policy" → None.
2. Open "Set Culture Policy" → None.
3. Open "Set Default Edict" → None.
4. Open "Issue Directives to the Realm" → confirm.
5. Inspect a vassal's character flags. They should have no `vassal_directive_*` flag at all.

Expected: the mod can also be used as a "wipe all directives" tool when all four settings are None.

- [ ] **Step 7: Commit**

```bash
git add common/decisions/eotr_decisions.txt localization/english/eotr_l_english.yml
git commit -m "Task 9: Apply Directives action decision + full integration"
```

---

## Task 10: Final cleanup and version bump

**Files:**
- Modify: `descriptor.mod`
- Modify: `README.md`

- [ ] **Step 1: Bump version to 1.0.0**

In `descriptor.mod`, change:

```
version="0.1.0"
```

to:

```
version="1.0.0"
```

Also update the launcher-side `~/Documents/Paradox Interactive/Crusader Kings III/mod/edicts_of_the_realm.mod` to match.

- [ ] **Step 2: Expand the README with usage notes**

Replace the body of `README.md` with:

```markdown
# Edicts of the Realm

A Crusader Kings 3 mod that lets you define a smart realm-wide policy for vassal directives and apply it across every sub-realm vassal in one click. Each vassal receives an appropriate `vassal_directive_*` flag based on their own faith and culture vs. the lands they hold.

Supported game versions: 1.18 "Crane", 1.19 "Scribe".

## Usage

Open the Decisions tab — there is a new group called "Edicts of the Realm" containing five decisions:

1. **Set Religion Policy** — Convert / None
2. **Set Culture Policy** — Convert / Acceptance / None
3. **Set Conflict Priority** — Religion First / Culture First (only matters when both Religion and Culture would fire for the same vassal)
4. **Set Default Edict** — Foster Prosperity / Reinforce the Borders / Marshal the Hosts / None
5. **Issue Directives to the Realm** — applies your settings to every landed AI vassal in your sub-realm

Settings persist across saves. You can change them at any time and re-issue directives.

## Algorithm

For each landed AI vassal at or below county tier (including sub-vassals), the mod:

1. Checks the Religion candidate: if Religion Policy = Convert AND the vassal shares your faith AND the vassal holds at least one county whose faith differs from theirs → `vassal_directive_convert_faith`.
2. Checks the Culture candidate: if Culture Policy = Convert AND the vassal shares your culture AND has at least one culture-mismatched county → `vassal_directive_convert_culture`. Otherwise, if Culture Policy = Acceptance AND the vassal has any culture-mismatched county (regardless of yours) → `vassal_directive_improve_cultural_acceptance`.
3. If both Religion and Culture fired, the Conflict Priority decides which wins.
4. If neither fired, the Default Edict is applied: `building_focus_economy` (Prosperity), `building_focus_fortification` (Bulwark), `building_focus_military` (Marshal), or nothing (None).

Heretic vassals never receive `convert_faith` and foreign-culture vassals never receive `convert_culture` — those directives spread the *vassal's* faith / culture, so applying them would be counter-productive.

## Compatibility

Uses only vanilla `vassal_directive_*` flags. All internal identifiers are namespaced `eotr_*`. Safe to run alongside "Better Mass Vassal Directive" — whichever is applied last wins (both call `remove_vassal_directives` before assigning).

## Credits

See `Credits.txt`.
```

- [ ] **Step 3: Commit**

```bash
git add descriptor.mod README.md
git commit -m "Task 10: bump to 1.0.0, finalize README"
```

- [ ] **Step 4: Optional — tag the release**

```bash
git tag -a v1.0.0 -m "Initial release"
```

---

## Self-review summary

**Spec coverage check (done by author against `docs/superpowers/specs/2026-05-17-edicts-of-the-realm-design.md`):**

- §3 Player-facing model → Tasks 5–9
- §4 Per-vassal algorithm → Task 4 (full algorithm in one scripted effect)
- §5 Threshold semantics ("any misaligned county") → Task 3 triggers use `any_held_county`
- §6.1 descriptor.mod → Task 1
- §6.2 decision group type → Task 2
- §6.3 decisions → Tasks 5–9 (one decision per task)
- §6.4 scripted effects → Task 4
- §6.5 scripted triggers → Task 3
- §6.6 localization → strings added incrementally per task
- §7 UI shape (custom group, hidden Apply when no vassals) → Task 9 (`is_shown` block)
- §8 Edge cases → exercised in Task 9 verification steps (idempotent re-application, clear-everything flow, hidden-when-unlanded)
- §9 Compatibility → README mentions in Task 10
- §10 YAGNI → no scripted GUI, no new directive types, no localization beyond English, no auto-apply — all respected

**Placeholder scan:** none. Every code block contains literal script; every verification step lists the exact console command and expected outcome.

**Type consistency:** all identifiers checked pairwise — `eotr_religion_convert` (the flag) is distinct from `eotr_religion_policy_convert` (the decision-scope option token), and the evaluator effect uses the flag name; same pattern for culture, priority, and default-edict. Decision option scope tokens with the `_opt` suffix (priority, default edict) avoid collision with persistent flag names.
