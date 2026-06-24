# Changelog

All notable changes to **Edicts of the Realm** are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this mod adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] — 2026-06-24

### Changed
- **Settings now survive succession.** Previously the four policy settings and the Automatic Application toggle were stored as character flags on the player, so they were wiped whenever your character changed (e.g. your ruler died and an heir took over) and had to be re-entered. Settings are now stored as variables on the player's **primary title** instead, which the heir inherits along with the title — so they carry across succession automatically. (One-time note: existing saves will read as "Not set" the first time you load this version, since the old settings lived on the previous character; re-pick each setting once and they will persist from then on.)

### Added
- **Settings follow a change of primary title.** When your primary title itself changes — for example forming an empire, where a higher title becomes primary while the old one is kept — the settings are migrated onto the new primary title via the `on_primary_title_change` hook, so they are not stranded on the now-secondary title. This is a storage migration only; it does not re-apply directives on its own.

## [1.1.0] — 2026-05-20

### Added
- **Automatic Application** — new master toggle in the Edicts of the Realm decision group. When on, vassal directives are re-evaluated automatically on:
  - Every January 1st (yearly tick).
  - Every title transfer (inheritance, grant, conquest, revocation) — both the gainer and the loser are re-evaluated.
  - Any AI vassal converting faith or culture.
  - The player themselves converting faith or culture (all "shares faith/culture with liege" checks invert realm-wide).
  - Any county in the realm converting faith or culture — the holder and every intermediate liege up to (but not including) the player are re-evaluated.
  - Picking **On** also runs an immediate full apply.
  Picking **Off** stops the automatic refreshes but leaves existing directives in place. The manual *Issue Directives to the Realm* decision remains available either way.
- **View Current Settings** decision — a read-only summary of the current Religion Policy, Culture Policy, Conflict Priority, Default Edict, and Automatic Application state. Confirming the decision closes the panel with no side effects.

### Fixed
- **Setting flags now persist across saves.** Previously, picking an option in any of the four policy decisions (Religion Policy, Culture Policy, Conflict Priority, Default Edict) appeared to take effect in-session but the underlying character flag was never serialized — reloading any save reverted every setting to "Not set", and the *Issue Directives to the Realm* action silently produced no assignments because the evaluator never saw a player-side setting flag. The root cause was a wrong scope operator (`scope:X ?= { add_character_flag = Y }`) that shifted scope into the option-list boolean tag instead of the player. Replaced with the standard `if = { limit = { scope:X = yes } add_character_flag = Y }` pattern used by vanilla decisions.

## [1.0.0] — 2026-05-18

Initial release.
