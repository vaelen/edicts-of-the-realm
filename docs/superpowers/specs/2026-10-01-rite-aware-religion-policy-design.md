# Religion Policy under rites (CK3 1.20 "Crozier" port) — design

Status: **implemented in 1.3.0** (plan: `docs/superpowers/plans/2026-10-20-crozier-port.md`). First written 2026-10-01 against
1.20.0.2. Revised 2026-10-19 against the installed **1.20.1.1** game files
and after play-testing the rite system. The revision drops the planned
"Convert faith and rite" option and the Cousin guard (see the
"Decisions" list under "Behaviour").

## Why

1.20 splits religion into four levels (Rite < Faith < Religion < Family). What
used to be separate faiths (Catholic, Insular) are now rites of one faith.

These two vanilla mechanics behave differently:

| Mechanic                                       | Other-faith county | Same faith, other-rite county |
|------------------------------------------------|--------------------|-------------------------------|
| Court chaplain task "Convert Faith in County"  | converts           | converts (rite-only)          |
| `vassal_directive_convert_faith`               | converts           | **does nothing**              |

The second row comes from play-testing and matches the 1.20.1 script. The
vanilla Give Directive interaction only offers Convert Faith when the
vassal's sub-realm holds a county of a *different faith*
(`common/character_interactions/00_vassal_interactions.txt`, send_option
`convert_faith`: `any_sub_realm_county = { faith != scope:recipient.faith }`).
A rite-only mismatch never makes the directive available or useful.

So for this mod, **the directive is a faith-level tool.** Rites only matter
for which rite a converted county ends up with.

## What happens to a county the vassal converts

From `task_conversion.on_finish_task_county` in
`common/council_tasks/00_court_chaplain_tasks.txt` (1.20.1): when the
county's new faith is the vassal's faith, the county gets the **vassal's
rite** (`set_county_rite = scope:councillor_liege.rite`, where
`councillor_liege` is the vassal who employs the chaplain). The player's rite
plays no part.

## Terms

For a vassal V in player P's realm:

| Vassal class | Condition                               |
|--------------|-----------------------------------------|
| Aligned      | `V.rite = P.rite`                       |
| Cousin       | `V.faith = P.faith`, `V.rite != P.rite` |
| Foreign      | `V.faith != P.faith`                    |

## Behaviour

**Religion Policy stays a two-way radio (Convert / None).** No new setting,
no new variable, no migration change.

Candidate rule, unchanged from 1.19: V gets `vassal_directive_convert_faith`
when Religion Policy = Convert, `V.faith = P.faith`, and V holds at least one
county with `C.faith != V.faith`.

`faith` in 1.20 is the faith level (the parent of the rite), so the existing
triggers already compare the right thing:

| Vassal class | Candidate?                        | Converted counties end up |
|--------------|-----------------------------------|---------------------------|
| Aligned      | if it holds an other-faith county | P's faith, P's rite       |
| Cousin       | if it holds an other-faith county | P's faith, V's rite       |
| Foreign      | never                             | (n/a)                     |

Decisions:

- **Cousins qualify.** Their conversions bring counties into the player's
  faith, which is the policy's goal. The county lands on the cousin's rite,
  but the player's own chaplain can later rite-convert it with "Convert
  Faith in County". Excluding cousins would leave those counties on a
  foreign faith instead.
- **No Cousin guard.** The old draft blocked cousins that held a county of
  the player's rite, in case the directive made them rite-convert it. The
  directive does not drive rite-only conversion, so the risk is gone. AI
  vassals may still rite-convert on their own, but the directive doesn't
  change that.
- **No "Convert faith and rite" option.** No vanilla directive does rite-only
  conversion, and the mod outputs vanilla flags only.
- **Foreign stays "never"** (heresy rule from the original spec).

Everything downstream (Conflict Priority, Default Edict,
`remove_vassal_directives`, the output flag) is unchanged.

## Changes by file

`common/scripted_triggers/eotr_triggers.txt`, `common/scripted_effects/eotr_effects.txt`
- No logic change. Update the comments to say that `faith` is the faith
  level, the directive is faith-only, and cousins qualify on purpose.

`common/decisions/eotr_decisions.txt`
- Fix the stale "character flag" comments (lines 2 and 69). The settings
  live in primary-title variables.

`localization/english/eotr_l_english.yml`
- `eotr_set_religion_policy_desc` and `eotr_religion_policy_convert_tooltip`:
  add one sentence: "Counties converted by a vassal of another rite of your
  faith adopt that vassal's rite."
- `eotr_set_auto_apply_desc`: no wording change. The hook set it describes
  stays the same.

`common/on_action/eotr_on_actions.txt` (hook repair, needed regardless)
- **Stop defining `effect` directly on vanilla on_actions.** Only one
  `effect` block per on_action survives the merge. In 1.20.1 vanilla
  defines its own `effect` on `on_title_gain`, `on_title_lost`,
  `on_character_culture_change`, `on_county_faith_change` and
  `yearly_global_pulse`. Ours either replaces vanilla's (breaking vanilla
  logic) or loses to it (our hook silently does nothing).
  `on_county_culture_change` and `on_primary_title_change` are empty in
  vanilla, but another mod could fill them, so they move too. Pattern: move
  each body into its own `eotr_<name>` on_action and attach it with
  `<vanilla_name> = { on_actions = { eotr_<name> } }`. `on_actions` lists
  append instead of replacing.
- **Replace `on_character_faith_change` with `on_rite_change`.** The old
  name is gone from 1.20.1 (no occurrences anywhere under `game/`).
  `on_rite_change` is the code on_action for "character changes faith or
  rite" (root = character, `scope:old_faith`, `scope:old_rite`). It also
  fires for rite-only changes, which can't affect any faith-level check, so
  add `NOT = { faith = scope:old_faith }` to the limit to skip them cheaply.
- **Do not add `on_county_rite_change`.** It fires only for rite-only county
  changes, and those cannot change `eotr_has_faith_misaligned_county`. The
  bounded set stays at **seven** hooks. (Vanilla 1.20.1 now has an `effect`
  on this hook for Great Schism progress, so if it is ever wired in later,
  use the append pattern.)

`descriptor.mod` and the launcher pointer
- `supported_version="1.20.*"`, bump `version`.

`README.md`
- "Supported game versions: 1.20 'Crozier'." Add a line to the Algorithm
  section: "faith" means faith, not rite; converted counties take the
  converting vassal's rite.

`CLAUDE.md`
- Target version and the 1.20 hook name (`on_rite_change`). Add the
  on_action append convention to "Conventions to preserve": never write
  `effect` on a vanilla on_action.

## Compatibility

- `on_rite_change` does not exist in 1.19. This release is 1.20-only; 1.2.3
  remains the last 1.19 build.
- Existing saves need no migration. The setting variables are unchanged.
- Outputs are still the vanilla `vassal_directive_convert_faith` flag only.

## Not doing

- A rite-level Religion Policy option (no vanilla directive does it).
- A Cousin guard or a separate Cousin setting.
- `on_county_rite_change` (see above).
- Per-county or per-vassal exemptions (already excluded by the original
  spec).
- `on_player_character_change` (new in 1.20). Settings live on the primary
  title, so succession is already covered.
- Anything using holy sites, saints, puppets, clerical regions, or dynamic
  decision options.

## Open questions (check in play)

1. Do counties converted by a Cousin vassal really end up on the cousin's
   rite in play? The script says yes. If players find this surprising, the
   tooltip line covers it. Only add a "same rite only" restriction if
   play-testing shows it's needed.
2. When a rite splits off into a new faith (Great Schism,
   `detach_rite_to_new_faith`, light heresy divergence), which hooks fire,
   if any? That can turn Cousins into Foreign vassals all at once. The
   yearly pulse is the fallback, and a manual Apply always works.
   **Resolved:** `on_rite_change` fires per character for both the
   schism and a rite detaching (see "Probe results so far").
3. 1.20.1 changelog: "Converting a character to another character's or
   county's faith now also copies the corresponding rite." Confirm that
   `on_rite_change` fires once per conversion (not twice, once for faith and
   once for rite). **Resolved:** once per change, up to twice in bulk
   changes, harmless (see "Probe results so far").

## Probe results so far (2026-10-20, 1.20.1.1, 867 start)

- **Hooks are deferred.** Code on_actions triggered by a console or script
  change don't run until the next game day. Nothing fires while paused. When
  they run, they see the state at that moment, not the state at the time of
  the change.
- **Script changes do fire the hooks.** Console `set_character_rite` fired
  `on_rite_change` once (rite-only: `old_faith` = the faith at the time).
  Each console `set_county_faith` fired `on_county_faith_change` once.
- **Great Schism (Q2, schism case): covered.** `event great_schism.0001`
  fired `on_rite_change` for every Christian character, about 5,500 entries.
  - Western-rite characters fired once (`christian_faith` → `catholic`).
  - Greek-rite characters fired twice: `christian_faith` → `catholic`, then
    `catholic` → `orthodox`. The schism effect parks every rite under
    Catholicism first.
  - The test vassal (Greek rite, holding the directive) was among them, so
    the repaired `on_rite_change` hook will re-evaluate him.
- **Q3: answered.** One fire per ordinary change. Bulk religion changes can
  fire twice per character in the same tick. Both fires run deferred
  against the final state, so the evaluator gives the same result twice:
  wasted CPU, but the output is correct. No dedup guard needed.
- **The `old_faith` filter is safe but leaky.** Because the hooks are
  deferred, `old_faith` can be an intermediate faith (`catholic` for the
  Greek-rite vassal), so some fires the filter could skip still get
  evaluated. It never skips a fire where the faith actually changed. Keep
  it.
- **Rite detaches to a new faith (Q2, heresy/divergence case): covered.**
  `detach_rite_to_new_faith` on `byzantine_rite`:
  - `on_faith_created` fired immediately, not deferred (founder = the
    vassal, `diverged: no`).
  - On the next day, `on_rite_change` fired once for each of about 990
    Greek-rite characters (`christian_faith` → the new faith). The test
    vassal was one of them.
  - **Q2 is closed:** both split paths fire the per-character hook, so
    `on_faith_created` is not needed and the set stays at seven hooks.
- **Queued hooks survive save/load.** Changes made while paused, and saved
  before the next day, fired after the save was reloaded.
- **Still to run:** open question 1 (watch the vassal's chaplain convert the
  pagan county and check which rite it ends up on).

## Probe for open questions 2 and 3

A temporary logging file, `common/on_action/eotr_zz_probe.txt`. Never
commit it. `scripts/launcher-mod.sh upload` packages `git archive HEAD`, so
an untracked file can't ship by accident. It uses the `on_actions` append
pattern, so it also tests the hook-repair convention.

```
on_rite_change          = { on_actions = { eotr_probe_rite_change } }
on_county_faith_change  = { on_actions = { eotr_probe_county_faith_change } }
on_county_rite_change   = { on_actions = { eotr_probe_county_rite_change } }
on_faith_created        = { on_actions = { eotr_probe_faith_created } }

eotr_probe_rite_change         = { effect = { debug_log = "EOTR_PROBE on_rite_change"         debug_log_scopes = yes } }
eotr_probe_county_faith_change = { effect = { debug_log = "EOTR_PROBE on_county_faith_change" debug_log_scopes = yes } }
eotr_probe_county_rite_change  = { effect = { debug_log = "EOTR_PROBE on_county_rite_change"  debug_log_scopes = yes } }
eotr_probe_faith_created       = { effect = { debug_log = "EOTR_PROBE on_faith_created"       debug_log_scopes = yes } }
```

`debug_log_scopes` prints root plus the saved scopes (`old_faith`,
`old_rite`), so each log line shows who changed and from what. Read the
results with `grep -A8 EOTR_PROBE debug.log`. `debug_log` writes to
**`debug.log`**, not `error.log` (confirmed in 1.20.1). Before each test,
note the `debug.log` line count so you only read the new lines.

Baseline, observed on a fresh 867 start: `on_rite_change` fires about
2,300 times for about 1,900 characters (some up to 3 times) during
post-history setup, before the game is unpaused. Ignore that burst. It
does mean our hook must stay cheap, which the `top_liege` gate already
ensures.

Console syntax: `effect` takes the effect body directly, with no
`= { }` around it (`effect title:c_x.holder = { ... }`). `character:<N>`
looks up **history** character IDs, so it fails for most characters in a
running game (`Referencing non-existent character in script link`).
Target a vassal through a title it holds: `title:<key>.holder`. The
title key is shown in the title's view in debug mode.

Append check, done once: after any character conversion, run
`effect title:<key>.holder = { debug_log_scopes = yes }`, or check
`has_character_flag = changed_rite_flag` in the character debug view. Vanilla's
`on_rite_change` effect sets that flag. If it's set, vanilla's effect still
ran next to our appended on_action.

### Probe test A: how often `on_rite_change` fires per conversion (Q3)

Any start date. Pick an AI vassal and get its ID from the character debug
tooltip. Run each line from the console, then count the new `EOTR_PROBE
on_rite_change` lines:

| Case                         | Console effect (on `title:<key>.holder`)              | Expect |
|------------------------------|-------------------------------------------------------|--------|
| Plain faith change           | `set_character_faith = faith:<other>`                 | 1      |
| Copy another's faith         | `set_character_faith = title:<key2>.holder.faith`     | 1?     |
| Faith change with conversion | `set_character_faith_with_conversion = faith:<other>` | 1?     |
| Rite only, same faith        | `set_character_rite = rite:<sibling rite>`            | 1      |

Also do one in-game conversion on the player, through the faith view's
convert button, to cover the code path script can't reach.

The rite-only row must show `scope:old_faith` equal to the current faith.
That is what the planned `NOT = { faith = scope:old_faith }` filter relies on.

Stakes: the evaluator is idempotent, so a double fire only re-evaluates the
same vassal twice and still produces the right flag. If a row shows 2, note
it in the hook comment. A dedup guard isn't worth the code.

### Probe test B: which hooks fire when a rite splits off (Q2)

Start in 867, before the schism, and set up the test realm first:

- Player on `roman_rite`.
- One Cousin vassal on an eastern Chalcedonian rite that holds a pagan
  county, so it has `vassal_directive_convert_faith` after Apply.
- Auto-apply on.

Save, and reload that save before each case:

1. **Great Schism:** console `event great_schism.0001`. It's a hidden
   event with no scope, and it runs `pam_apply_great_schism_creation_effect`
   (rites move to `faith:catholic` and `faith:orthodox` through
   `set_parent_faith`).
2. **Rite detaches to a new faith:**
   `effect title:<cousin's title>.holder = { detach_rite_to_new_faith = { target = rite:<cousin's rite> } }`.
   Light heresy divergence and declared heresy (`pam_declare_rite_heresy_effect`)
   both use this same effect, so this case covers them too.

For each case, record:

- which probe lines fire, and for whom (one per character, one per county,
  only `on_faith_created`, or nothing);
- whether the Cousin, now Foreign, still has `convert_faith`. If it does,
  the directive is stale and would spread the new faith until January 1.

Decision rule:

- Any per-character hook fires (`on_rite_change`) → covered, no change.
- Only `on_faith_created` fires → ask whether to add it as an eighth hook.
  That breaks the "seven hooks" YAGNI rule, but faith creation is rare, so
  the CPU cost is negligible. The body would re-apply for every player with
  auto-apply on, like `yearly_global_pulse`. The case for it: a stale
  `convert_faith` on a newly Foreign vassal can finish a chaplain
  conversion to the wrong faith before the next yearly pulse.
- Nothing fires → same choice, `on_faith_created` is still the hook to use.
  Otherwise accept the yearly fallback and tell players in the README to
  re-Apply after a schism.

## Verification (when implemented)

No test framework; smoke-test in `-debug_mode`:

1. `error.log` has no `eotr` lines.
2. Vanilla behaviour on the shared hooks still works. For example, a
   `false_conversion` event or the Great Schism progress still fires on a
   county faith change with the mod on.
3. For each vassal class, set up one vassal with console effects
   (`set_character_faith`, `set_county_faith`), run Apply, and check the
   vassal's flag. Include a Cousin with only other-rite counties: it should
   get **no** convert_faith (falls through to the Default Edict).
4. With auto-apply on, convert an AI vassal's faith and confirm it is
   re-evaluated right away. Then change only its rite and confirm nothing
   is re-evaluated.
5. Load a 1.2.3 save with Convert set and confirm the viewer still shows
   "Convert".
