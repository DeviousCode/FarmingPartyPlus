# Changelog

All notable changes to `FarmingPartyPlus` are documented in this file.

## [3.0.4] - 2026-06-02
### Added
- A craft-bag auto-add warning dialog for fishing sessions so hosts can disable the setting before `Fish` or `Perfect Roe` start bypassing tracked inventory flow.

### Changed
- Extended the synced loot payload handling so helper-provided `itemLink` data now drives proper item naming, tooltip links, and rarity colors on the host.
- Host-side synced pricing now prefers the host's own item-link valuation instead of trusting helper fallback values.
- Synced gutting history now logs consumed fish as `Processed` entries while preserving normal `Received` lines for `Fish` and `Perfect Roe`.
- Synced loot dedupe now tracks native-vs-helper counts so repeated gutting results do not collapse into missing or duplicated history lines.
- Fishing-session craft-bag warnings and gutting output handling now mirror the host's local behavior more closely.
- Scoreboard display and sync identity handling now align more closely around ESO display names / `@UserID` instead of character-name-first behavior.

### Fixed
- Restored loot-event handling for gutting outputs with duplicate guards so `Fish` and `Perfect Roe` count and log reliably again.
- Fixed synced item-link decoding and host-side value resolution so helper items keep correct casing, tooltip links, rarity colors, and prices.
- Fixed helper-slot reuse and tracked fish state so backpack slot changes stop producing stale-count sync corruption during gutting.
- Fixed the host sync protocol declaration so it matches the helper's `itemLink`-aware payload shape.
- Fixed malformed tooltip/link behavior for synced gutting entries that had previously been stored as plain text names.
- Fixed repeated helper gutting updates so native and synced group-loot copies no longer overcount, undercount, or race each other in loot history.
- Fixed sync self-ignore, duplicate suppression, and helper-active matching to prefer display-name identity before character-name fallback.

## [3.0.3] - 2026-06-01
### Added
- A `Recipes` whitelist category with a shared recipe tracking rule for valuable node recipes.
- A recipe minimum-value threshold, defaulting to `3000g` and bounded from `100g` to `50000g`.
- Account-wide whitelist profile save/load/delete support with per-profile names.
- A whitelist profile load confirmation dialog that reloads the UI on acceptance.

### Changed
- Reworked the top of the whitelist window to separate profile naming/saving from saved profile selection.
- Added live validation for whitelist profile names so they accept letters only, with no spaces.
- Refined the whitelist window layout and row widths to better fit longer rule labels.

### Fixed
- Fixed the recipe threshold UI by replacing the broken native slider behavior with a custom bar control.
- Fixed recipe slider endpoint behavior so clicking the min/max labels snaps to exact `100g` and `50000g`.
- Fixed recipe slider row overlap and improved the visible slider track, fill, and thumb state.
- Fixed the profile name field so it takes focus and accepts typed input correctly.

## [3.0.2] - 2026-06-01
### Added
- Helper-presence indicators in the members window, driven by observed sync traffic from `FarmingPartyPlusSync`.
- A dedicated loot-history toggle keybind plus `/fpp loot`, `/fpp log`, and `/fpploot` commands.
- A delayed ready message after `/reloadui` so the addon reports when tracking is actually ready.

### Changed
- Tightened the members window layout by reducing the spacing between columns and removing the visible `Items` label.
- Updated the loot history window toggle path so keybind and settings changes use the same visibility state.
- Extended the whitelist catalog to include `Fish` by default for fishing-session gutting output.

### Fixed
- Added local backpack fish-slot tracking so host-side gutting can subtract consumed fish and add `Fish` or `Perfect Roe` correctly.
- Added reset handling for local loot and sync session caches so `/fpp reset` clears active gutting/sync state.
- Fixed loot history window layout drift after show/hide by reapplying saved dimensions and anchoring the text buffer correctly.
- Reduced sync protocol ID size and enabled signed synced quantities so helper deltas can add and subtract tracked items safely.

## [3.0.1] - 2026-06-01
### Fixed
- Removed the circular optional dependency between `FarmingPartyPlus` and `FarmingPartyPlusSync`.
- Updated the `LibGroupBroadcast` integration to match the current handler registration and field option APIs.
- Fixed sync host object initialization so the receiver module initializes on the created instance.

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
