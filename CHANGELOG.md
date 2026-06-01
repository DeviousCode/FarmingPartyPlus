# Changelog

All notable changes to `FarmingPartyPlus` are documented in this file.

## [3.0.0] - 2026-06-01
### Added
- New `FarmingPartyPlus` addon identity, folder, saved variables, slash commands, and bindings so it can coexist with the original `Farming Party`.
- Material whitelist mode designed for organized farming groups that want to count only selected items.
- Dedicated whitelist window with grouped categories, individual item toggles, per-category `All On` and `All Off`, and global whitelist controls.
- Expanded whitelist coverage for ore, logs, cloth and leather, jewelry dust, alchemy reagents, enchanting materials, provisioning, furnishing materials, bait, and fishing drops.
- Optional helper companion addon, `FarmingPartyPlusSync`, in its own folder for future sync-based accuracy improvements.
- Legacy slash command aliases for players used to the original addon, including `/fp` and `/fpc`.
- Ranked chat score output using ESO user IDs.

### Changed
- Reworked tracking flow to support whitelist-first farming runs without relying only on item quality.
- Updated the settings panel with clearer section ordering, colored headers, and a reload reminder without forcing `/reloadui`.
- Refreshed the whitelist window visuals with clearer toggle states and more noticeable action buttons.
- Clicking a member name in the scoreboard now opens that member's item breakdown directly.
- Updated addon metadata and API compatibility for current ESO live versions.

### Fixed
- Resolved loot tracking failures caused by self and group looter name resolution.
- Fixed whitelist matching so enabled materials count reliably and unrelated items no longer slip through.
- Enforced gear and motif exclusions correctly while whitelist mode is active.
- Fixed `Minimum Item Quality` comparisons so changing the setting no longer throws number-versus-string errors.
- Corrected several UI and data-persistence issues discovered during the `FarmingPartyPlus` fork.
