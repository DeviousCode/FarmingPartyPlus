![Farming Party Plus Banner](fpp.png)

# Farming Party Plus

`Farming Party Plus` is an Elder Scrolls Online addon for tracking party farming loot with a cleaner focus on node runs, material filtering, and host-side event tracking.

It is designed for players who want to run organized farming groups without cluttering the totals with junk gear, white trash drops, or low-priority materials.

## What It Does

- Tracks loot for you and your group from one host client
- Supports a material whitelist for node farming
- Lets you toggle exactly which materials count
- Shows tracked loot in a scoreboard window and item breakdown window
- Logs loot to chat and the loot window
- Supports optional helper sync through a separate addon

## Main Features

### Node Farming Whitelist

Whitelist mode is the core feature of `Farming Party Plus`.

Instead of tracking loot only by item quality, you can choose exactly what counts. This is useful for:

- ore runs
- wood runs
- cloth runs
- jewelry dust runs
- alchemy mat runs
- enchanting rune runs
- provisioning ingredient runs
- furnishing mat runs
- bait and fishing runs

When whitelist mode is enabled, only the items you turn on will count.

### Category-Based Filtering

The whitelist window groups items into clear sections so it is easy to build a custom farm profile:

- `Ore`
- `Logs`
- `Cloth & Leather`
- `Jewelry Dust`
- `Alchemy`
- `Enchanting`
- `Provisioning`
- `Common Bait`
- `Rare Bait`
- `Fishing`
- `Furnishing Mats`

Each category supports:

- individual item toggles
- `All On`
- `All Off`

### Standard Tracking Mode

If whitelist mode is turned off, the addon falls back to the more traditional tracking model:

- minimum item quality
- gear on or off
- motifs on or off
- self loot on or off
- group loot on or off

## Installation

### Main Addon

Install this folder into your ESO addons directory:

- `FarmingPartyPlus`

Typical path:

- `Documents\Elder Scrolls Online\live\AddOns\FarmingPartyPlus`

### Required Libraries

`Farming Party Plus` expects these libraries:

- `LibAddonMenu-2.0`
- `LibAsync`
- `LibPrice`

### Optional Sync Helper

There is also an optional separate helper addon:

- `FarmingPartyPlusSync`

This is not required for normal host tracking.

Its purpose is to provide optional sync support for cases where local-only events are not fully exposed to the host client. If it is not installed, the main addon still works normally.

### Optional Sync Library

If you want to use the optional sync path, install:

- `LibGroupBroadcast`

`LibGroupBroadcast` is not required for normal `FarmingPartyPlus` use. It is only needed for:

- `FarmingPartyPlusSync`
- optional sync receive support in `FarmingPartyPlus`

## Commands

### Main Commands

| Command | Description |
| --- | --- |
| `/fpp` | Toggle the main member scoreboard window |
| `/fpp reset` | Reset all tracked loot data |
| `/fpp start` | Start tracking |
| `/fpp stop` | Stop tracking |
| `/fpp status` | Show current tracking state |
| `/fpp update` | Refresh party members |
| `/fpp filters` | Open the whitelist window |
| `/fpp whitelist on` | Enable whitelist mode |
| `/fpp whitelist off` | Disable whitelist mode |
| `/fpp sync` | Show optional sync receiver status |
| `/fppc` | Output current scores to the chat input |
| `/fpphelp` | Print command help |
| `/fp` | Legacy alias for `/fpp` |
| `/fpc` | Legacy alias for `/fppc` |

### Helper Command

If you are testing the optional sync helper:

| Command | Description |
| --- | --- |
| `/fppsync` | Show helper sync sender status |

## Recommended Use

### For a Farming Party Host

Use `FarmingPartyPlus` if you are the player running the event and want:

- the scoreboard
- the loot windows
- whitelist filtering
- chat output
- host-side tracking

### For a Simple One-Client Setup

You only need:

- `FarmingPartyPlus`

This is the standard setup.

### For Optional Helper Testing

Use:

- `FarmingPartyPlus` on the host
- `FarmingPartyPlusSync` on helper-only clients
- `LibGroupBroadcast` on both clients

The helper addon is designed to stay quiet if the full addon is already installed on that same client.

## Notes

- Saved variables update on `/reloadui`, logout, or exit
- Group loot tracking depends on what the ESO API exposes to the host client
- Some actions are easier to see locally than remotely, which is why optional sync exists as a separate path
- Gear and motif filters still apply when whitelist mode is active

## Credits

Originally based on `Farming Party`, which was originally based on `Group Loot` by Temeez.

Pricing support is intended to work with libraries and tools commonly used by ESO trading addons.
