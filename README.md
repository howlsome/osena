# Osena

Sets all World of Warcraft UI text to a fixed 18px size for improved readability.

## Features

- Applies a uniform 18px font size across all discovered UI font objects
- Snapshots Blizzard's original font settings on first load for easy restoration
- Auto-apply on login/reload (toggle)
- Optional login message (toggle)
- Settings panel accessible via the modern Settings UI or the legacy Interface Options fallback
- Dynamic font discovery — scans global font objects and all FontString frames

## Installation

1. Copy the `Osena` folder into `_retail_/Interface/AddOns/`.
2. Ensure `osena.lua` is present and listed in `osena.toc`.
3. `/reload`

## Usage

- Open options: `/osena` (or Esc → Options → AddOns → Osena)
- Click **Apply 18px** to set all UI fonts to 18px
- Click **Restore Blizzard Defaults** to revert to the original captured font settings
- Toggle **Auto-apply on login and reload** to have 18px applied automatically
- Toggle **Show login message** to control the chat notification on load
- Click **Reset Settings** to return all options to their defaults

## Slash Commands

| Command         | Description                                             |
| --------------- | ------------------------------------------------------- |
| `/osena`        | Open the settings panel                                 |
| `/osena apply`  | Apply 18px to all fonts                                 |
| `/osena reset`  | Restore Blizzard font defaults                          |
| `/osena status` | Print current font state to chat                        |
| `/osena scan`   | Rescan and report the number of discovered font objects |

## Notes

- The addon snapshots Blizzard's font settings on first load so they can be restored later.
- Font discovery runs each time fonts are applied, picking up any newly created font objects.
- If changes are not visible, try `/reload` followed by `/osena apply`.
