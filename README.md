# Osena

Apply fixed-size presets across the WoW UI, with one-click restore to Blizzard’s defaults.

## Features

- Presets: Small (18), Medium (20), Large (24), XL (28), XXL (32)
- One-click “Apply All” to resize all discovered UI fonts
- Auto-apply on login/reload (toggle)
- “Default Blizz” to restore captured Blizzard font settings
- Short, non-wrapping button labels to avoid overflow

## Installation

1. Copy the `Osena` folder into `_retail_/Interface/AddOns/`.
2. Ensure `Osena.lua` is present and listed in `Osena.toc`.
3. `/reload`

## Usage

- Open options: `/osena` (or Esc → Options → AddOns → Osena)
- Pick a preset from the dropdown → click **Apply All**
- Enable/disable **Auto-apply** on login/reload
- Restore Blizzard defaults: click **Default Blizz**

## Notes

- Preset order is fixed (Small → XXL). Small is the default.
- The addon snapshots Blizzard’s font settings on first load for restoration.
- If you see no visible change, try `/reload` and click **Apply All** once more.

## Slash Commands

- `/osena` — open settings
- `/osena scan` — rescan and list discovered fonts in chat
