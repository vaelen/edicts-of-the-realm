# Edicts of the Realm

<p align="center"><img src="thumbnail.png" alt="Edicts of the Realm" width="240"></p>

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
