# Edicts of the Realm — Design

**Status:** Approved
**Date:** 2026-05-17
**Game:** Crusader Kings 3 (supported versions 1.18 "Crane" and 1.19 "Scribe")

## 1. Summary

A Crusader Kings 3 mod that lets the player define a small **policy** for how vassal directives should be assigned across the realm, then push that policy to every sub-realm vassal in a single action. Each vassal receives a *different* directive depending on the vassal's own faith and culture, the faith and culture of the lands the vassal directly holds, and a fallthrough "default edict" the player chooses.

The mod does not introduce new directive *types* — it only chooses which of the vanilla `vassal_directive_*` flags to apply to each vassal, then applies it via `add_character_flag`. This is the same mechanism the reference mod [Better Mass Vassal Directive](https://github.com/Wehrmachtserdbeere/better_mass_vassal_directive) uses, so behavior is well-understood and patch-stable.

## 2. Motivation

The reference mod (Better Mass Vassal Directive) reduced the tedium of issuing individual directives by adding a single decision that applies one chosen directive to every direct vassal. It has two limitations the player wants to remove:

1. **No filtering or per-vassal variation.** Every direct vassal receives the same directive, even when that's counter-productive (e.g. assigning `convert_faith` to a heretic vassal spreads heresy rather than the liege's faith).
2. **Direct vassals only.** Sub-vassals never receive a directive through the mod's single decision.

Edicts of the Realm addresses both by treating the directive as a function of each vassal's situation, and by cascading to all sub-realm vassals.

## 3. Player-facing model

The mod exposes **four persistent settings** and **one action**, presented as five decisions in a custom decision group called "Edicts of the Realm".

| # | Setting | Options | Persistence |
|---|---|---|---|
| 1 | Religion Policy | Convert / None | character flag on player |
| 2 | Culture Policy | Convert / Acceptance / None | character flag on player |
| 3 | Priority | Religion-first / Culture-first | character flag on player |
| 4 | Default Edict | Foster Prosperity / Reinforce the Borders / Marshal the Hosts / None | character flag on player |

Each setting decision works like a radio button: picking an option clears any sibling flag in the same category and adds the chosen one. Settings persist across saves.

The fifth decision, **"Issue Directives to the Realm"**, evaluates the current settings and applies a directive to every sub-realm vassal.

The Priority setting only meaningfully affects outcomes when settings 1 and 2 are both non-None; setting it at other times is harmless but inert.

## 4. Per-vassal evaluation algorithm

When the player invokes "Issue Directives to the Realm", the mod iterates:

```
every_vassal_or_below = {
    limit = {
        is_landed = yes
        is_ai = yes
        highest_held_title_tier >= tier_county
    }
    # ...evaluate and apply...
}
```

For each matched vassal, the mod runs the following decision tree.

### 4.1 Religion candidate

If the player has `eotr_religion_convert`:

- Vassal's faith == liege's faith **and** vassal holds at least one county whose faith ≠ vassal's faith → candidate = `vassal_directive_convert_faith`
- Otherwise → no religion candidate

Rationale: `convert_faith` makes the vassal spread *their own* faith. Assigning it to a vassal who shares the liege's faith spreads the liege's faith. Assigning it to a heretic vassal would spread heresy — so heretic vassals never receive this directive under this policy.

### 4.2 Culture candidate

If the player has `eotr_culture_convert`:

- Vassal's culture == liege's culture **and** vassal holds at least one county whose culture ≠ vassal's culture → candidate = `vassal_directive_convert_culture`
- Otherwise → no culture candidate

Else if the player has `eotr_culture_accept`:

- Vassal holds at least one county whose culture ≠ vassal's culture → candidate = `vassal_directive_improve_cultural_acceptance`
- Otherwise → no culture candidate

Rationale: `convert_culture` mirrors `convert_faith` (only safe to assign when vassal already shares liege's culture). `improve_cultural_acceptance` operates on the vassal's culture's relationship with the cultures of the vassal's own lands, so the liege's culture is *not* a factor — only the vassal-vs-lands diversity matters.

### 4.3 Resolution

- Both candidates present → apply the one named by the player's Priority flag (`eotr_priority_religion` → religion candidate; `eotr_priority_culture` → culture candidate).
- Exactly one candidate present → apply it.
- Neither candidate present → apply the Default Edict's directive:
  - `eotr_default_prosperity` → `vassal_directive_building_focus_economy`
  - `eotr_default_bulwark` → `vassal_directive_building_focus_fortification`
  - `eotr_default_martial` → `vassal_directive_building_focus_military`
  - `eotr_default_none` → assign nothing (only clear)

### 4.4 Application

Before assigning a new flag, run `remove_vassal_directives = yes` on the vassal to clear any vanilla or prior-run directive flag. Then `add_character_flag = vassal_directive_<chosen>` (unless the resolution is "assign nothing", in which case only the clear runs).

## 5. Threshold semantics

A county is "misaligned" with its holder's faith (or culture) iff `county.faith ≠ holder.faith` (resp. culture). The "lands have misalignment" test fires if **at least one** held county is misaligned — there is no majority threshold. The vanilla `convert_faith` / `convert_culture` directives operate per-county and will simply do nothing for vassals with zero misaligned counties, so a stricter threshold would gain nothing and reduce responsiveness.

"Held county" means a county the vassal personally holds the title of, not counties held by *their* sub-vassals.

## 6. Files

```
subject-directives-mod/
├── descriptor.mod
├── thumbnail.png
├── README.md
├── common/
│   ├── decision_group_types/
│   │   └── eotr_decision_group.txt
│   ├── decisions/
│   │   └── eotr_decisions.txt
│   ├── scripted_effects/
│   │   └── eotr_effects.txt
│   └── scripted_triggers/
│       └── eotr_triggers.txt
└── localization/
    └── english/
        └── eotr_l_english.yml
```

### 6.1 `descriptor.mod`

Standard CK3 mod descriptor: `name`, `version`, `supported_version`, tags including "Decisions", "Gameplay", "Utilities".

### 6.2 `common/decision_group_types/eotr_decision_group.txt`

Defines a custom decision group `eotr_realm_directives` so all five decisions cluster together in the decisions UI rather than scattering through the generic group.

### 6.3 `common/decisions/eotr_decisions.txt`

Five decisions:

1. `eotr_set_religion_policy` — option list controller: Convert / None. On pick: clear `eotr_religion_convert`, then set the chosen flag (or none).
2. `eotr_set_culture_policy` — option list: Convert / Acceptance / None. On pick: clear `eotr_culture_convert` and `eotr_culture_accept`, then set the chosen flag (or none).
3. `eotr_set_priority` — option list: Religion-first / Culture-first. On pick: clear both priority flags, then set the chosen flag.
4. `eotr_set_default_edict` — option list: Foster Prosperity / Reinforce the Borders / Marshal the Hosts / None. On pick: clear all four default-edict flags, then set the chosen flag.
5. `eotr_apply_directives` — the action. Effect calls the scripted effect `eotr_evaluate_and_assign_directive` for every matched vassal via `every_vassal_or_below`.

All decisions: `decision_group_type = eotr_realm_directives`, `ai_will_do = { base = 0 }`, `ai_check_interval = 0` (player-only).

Each setting decision's description includes a tooltip showing the *current* value via `has_character_flag` checks, so the player can see at a glance what is set.

`eotr_apply_directives` is `is_shown` gated on the player having at least one matching vassal (`any_vassal_or_below = { ... }` with the same limits as the iteration).

### 6.4 `common/scripted_effects/eotr_effects.txt`

One main effect, `eotr_evaluate_and_assign_directive`, run in the scope of each candidate vassal with `root` = liege. Contains the resolution tree from Section 4. Uses nested `if = { limit = { ... } ... else = { ... } }` blocks rather than `switch` because the conditions need to inspect both the vassal scope and root flags simultaneously.

Pseudocode:

```
eotr_evaluate_and_assign_directive = {
    # religion candidate
    if = {
        limit = {
            root = { has_character_flag = eotr_religion_convert }
            faith = root.faith
            eotr_has_faith_misaligned_county = yes
        }
        set_variable = { name = eotr_religion_pick value = yes }
    }
    # culture candidate
    if = {
        limit = {
            root = { has_character_flag = eotr_culture_convert }
            culture = root.culture
            eotr_has_culture_misaligned_county = yes
        }
        set_variable = { name = eotr_culture_pick value = flag:convert }
    }
    else_if = {
        limit = {
            root = { has_character_flag = eotr_culture_accept }
            eotr_has_culture_misaligned_county = yes
        }
        set_variable = { name = eotr_culture_pick value = flag:accept }
    }

    # resolve
    remove_vassal_directives = yes
    if = {
        limit = {
            has_variable = eotr_religion_pick
            has_variable = eotr_culture_pick
        }
        if = {
            limit = { root = { has_character_flag = eotr_priority_religion } }
            add_character_flag = vassal_directive_convert_faith
        }
        else = {
            # culture path
            if = {
                limit = { var:eotr_culture_pick = flag:convert }
                add_character_flag = vassal_directive_convert_culture
            }
            else = {
                add_character_flag = vassal_directive_improve_cultural_acceptance
            }
        }
    }
    else_if = {
        limit = { has_variable = eotr_religion_pick }
        add_character_flag = vassal_directive_convert_faith
    }
    else_if = {
        limit = { has_variable = eotr_culture_pick }
        if = {
            limit = { var:eotr_culture_pick = flag:convert }
            add_character_flag = vassal_directive_convert_culture
        }
        else = {
            add_character_flag = vassal_directive_improve_cultural_acceptance
        }
    }
    else = {
        # default edict fallthrough
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
        # else: eotr_default_none or unset — leave cleared
    }

    # cleanup
    remove_variable = eotr_religion_pick
    remove_variable = eotr_culture_pick
}
```

### 6.5 `common/scripted_triggers/eotr_triggers.txt`

Two triggers, both evaluated in the scope of a character (the vassal):

```
eotr_has_faith_misaligned_county = {
    any_held_county = {
        NOT = { faith = prev.faith }
    }
}

eotr_has_culture_misaligned_county = {
    any_held_county = {
        NOT = { culture = prev.culture }
    }
}
```

### 6.6 `localization/english/eotr_l_english.yml`

All visible strings: decision names, descriptions, option labels, confirm text, "Currently: X" tooltips. UTF-8 BOM required (CK3 convention).

## 7. UI and visibility

- All five decisions live in the custom `eotr_realm_directives` decision group, so they appear together in the player's decisions UI.
- Setting decisions are always visible to landed rulers (`is_shown = { is_landed = yes }`).
- The Apply decision is visible only when the player has at least one matching sub-realm vassal.
- Each setting decision's description names the *current* setting using `has_character_flag` lookups.
- No scripted GUI / .gui file work. Stays within standard decision UI to minimize patch risk.

## 8. Edge cases

| Case | Behavior |
|---|---|
| Player is unlanded | No decisions visible. |
| Player has no vassals | Setting decisions still visible (for configuration); Apply decision hidden. |
| Vassal is at war with player / in rebellion / in faction | Directive still applied. Matches reference mod behavior. |
| Vassal holds no counties | All misalignment checks return false; vassal falls through to Default Edict. Building-focus directives still apply meaningfully if vassal holds *any* barony via the held title. If the directive has nothing to operate on, vanilla handles it gracefully. |
| Mod applied repeatedly | `remove_vassal_directives = yes` runs each time, so the latest application always supersedes prior ones. Idempotent. |
| Player has no Default Edict set and no candidates fire | Vassal's directive is cleared and nothing new is set. Acceptable behavior — equivalent to picking Default = None. |
| Tributaries / non-vassal subjects | Not touched. `every_vassal_or_below` does not include them. |

## 9. Compatibility

- All character flags introduced by this mod use the `eotr_` prefix to avoid collision with other mods.
- The mod uses only vanilla `vassal_directive_*` flags as outputs, so vanilla and other mods that read those flags (including Better Mass Vassal Directive) continue to interpret them correctly.
- Running Edicts of the Realm alongside Better Mass Vassal Directive is harmless — they both clear directives before assignment, so whichever was applied last wins. They do not corrupt each other's state.

## 10. Out of scope (YAGNI)

- New directive *types* beyond the vanilla `vassal_directive_*` set.
- Per-vassal manual overrides or vassal-exemption lists.
- Auto-apply triggers (on_marriage, on_succession, on_yearly, etc.). Application is purely manual.
- Localization beyond English. Other languages can be added in a follow-up.
- Compatibility patches for other mods that add custom directive types.
- A scripted GUI for the settings. The mod stays within standard decision UI.
- Tributaries, non-feudal subjects, or special vassal types beyond what `every_vassal_or_below` already covers.
- AI usage. The decisions explicitly set `ai_will_do = { base = 0 }`; AI rulers do not invoke them.
