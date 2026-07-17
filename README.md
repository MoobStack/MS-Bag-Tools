# MS Bag Tools

**MS Bag Tools** is an addon designed as a functional extension to **pfUI's unified inventory and bank interfaces**. It adds organized sorting, efficient partial-stack consolidation, manual grey-item selling, configurable container fill orders and row widths, and persistent per-character locked squares.

- **Version:** 1.1.3
- **Publisher:** MoobStack
- **Internal addon name:** `MSBagTools`
- **Client:** World of Warcraft 1.12.1
- **Interface:** 11200

> Designed for the World of Warcraft 1.12.1 client using Interface 11200. Compatibility may vary across community-maintained client modifications.

---

## Changelog

### 1.1.3

- Rebranded **OctoBagTools** as **MS Bag Tools** under the MoobStack publisher.
- Renamed the main folder, TOC, source files, addon table, saved variables, frame names, UI branding, messages, and documentation to MS-prefixed names.
- Added `/msbag`, `/msbags`, and `/msbagtools` as the primary command aliases.
- Retained `/obag`, `/octobags`, and `/octobagtools` as legacy aliases.
- Added migration from `OctoBagToolsDB` and each character's `OctoBagToolsCharDB` without deleting the legacy saved data.
- Added a temporary legacy bridge for settings-preserving update installations.
- Updated compatibility language to World of Warcraft 1.12.1 and Interface 11200 without tying the addon to a specific server project.
- Preserved the working inventory sorting, bank sorting, stack consolidation, junk selling, locked-square, pfUI toolbar, and settings behavior from version 1.1.2.

### Legacy history

Versions **1.0.0 through 1.1.2** were published under the **OctoBagTools** name.

---

## Documentation

### Overview

MS Bag Tools was created primarily as an extension to **pfUI's single-window bag and bank system**. It supplements pfUI's unified storage interface without replacing it, adding tools for organizing, compacting, protecting, and managing stored items.

The addon supports two independent storage scopes:

| Scope | Containers |
|---|---|
| Inventory | Backpack `0` and equipped bags `1–4` |
| Bank | Main bank `-1` and accessible bank bags `5–11` |

Inventory and bank contents are never mixed during sorting or consolidation.

### Main features

- Organized inventory and bank sorting.
- Category, quality, and name sorting modes.
- Configurable inventory and bank fill orders.
- Configurable inventory and bank grid widths.
- Efficient consolidation of matching partial stacks.
- Manual grey-item selling at merchants.
- Persistent per-character locked squares.
- Configurable locked-square outline color and thickness.
- Separate inventory and bank square locks.
- pfUI inventory and bank header controls.
- Combat sorting protection.
- Per-character saved lock data.
- Migration from OctoBagTools settings.
- Legacy command aliases for existing macros and habits.

---

## pfUI integration

MS Bag Tools is designed to extend pfUI's unified bag and bank windows.

### Inventory header controls

| Button | Action |
|---|---|
| `S` | Sort inventory |
| `$` | Sell eligible grey junk at an open merchant |
| `L` | Toggle click-to-lock mode |
| `O` | Open MS Bag Tools settings |

### Bank header controls

| Button | Action |
|---|---|
| `S` | Sort the open bank |
| `L` | Toggle click-to-lock mode |
| `O` | Open MS Bag Tools settings |

The addon does not create a replacement inventory or bank window. It attaches its controls and functionality to pfUI's existing unified storage interface.

---

## Installation

### Clean installation

1. Completely exit World of Warcraft.
2. Extract the `MSBagTools` folder into:

   ```text
   World of Warcraft\Interface\AddOns\
   ```

3. Confirm the final path is:

   ```text
   World of Warcraft\Interface\AddOns\MSBagTools\MSBagTools.toc
   ```

4. Enable **MS Bag Tools** on the character-selection AddOns screen.
5. Log in and verify the installation:

   ```text
   /msbag status
   ```

Avoid a double-nested folder:

```text
Incorrect:
World of Warcraft\Interface\AddOns\MSBagTools\MSBagTools\MSBagTools.toc
```

---

## Updating from OctoBagTools 1.1.2

Use the settings-preserving migration update. It contains two sibling addon folders:

```text
World of Warcraft\Interface\AddOns\MSBagTools\
World of Warcraft\Interface\AddOns\OctoBagTools\
```

The temporary `OctoBagTools` folder is a migration bridge. It loads the legacy saved variables before MS Bag Tools initializes, but it does not run the former sorting addon implementation.

### Migration steps

1. Completely exit World of Warcraft.
2. Extract the migration update into:

   ```text
   World of Warcraft\Interface\AddOns\
   ```

3. Replace existing files when prompted.
4. Enable both:

   ```text
   MS Bag Tools
   MS Bag Tools Legacy Migration
   ```

5. Log into every character that previously used OctoBagTools.
6. On each character, enter:

   ```text
   /msbag status
   ```

7. Confirm that the saved-data status reports either:

   ```text
   legacy settings imported this session
   ```

   or:

   ```text
   legacy migration complete
   ```

8. Log out normally or exit the client so the new saved-variable files are written.

After every relevant character has migrated and the new data has been verified, the temporary legacy addon folder may be disabled or deleted:

```text
World of Warcraft\Interface\AddOns\OctoBagTools
```

### Migrated saved variables

```text
OctoBagToolsDB
    → MSBagToolsDB

OctoBagToolsCharDB
    → MSBagToolsCharDB
```

The migration preserves:

- Inventory and bank fill orders.
- Inventory and bank column settings.
- Sorting preferences.
- Junk-selling preferences.
- Appearance options.
- Inventory locked squares.
- Bank locked squares.
- Per-character lock data.

Legacy data is not erased automatically.

After successful migration and a backup, the old saved-variable files may be removed manually:

```text
WTF\Account\<Account>\SavedVariables\OctoBagTools.lua

WTF\Account\<Account>\<Realm>\<Character>\
SavedVariables\OctoBagTools.lua
```

---

## Sorting

### Inventory sorting

Inventory sorting covers:

```text
Bag 0 and equipped bags 1–4
```

Default inventory fill order:

```text
0 > 4 > 3 > 2 > 1
```

### Bank sorting

Bank sorting covers:

```text
Main bank -1 and accessible bank bags 5–11
```

Default bank fill order:

```text
-1 > 5 > 6 > 7 > 8 > 9 > 10 > 11
```

The bank must remain open while bank sorting is in progress.

### Sorting modes

#### Category

Organizes items into stable top-level sections and practical subgroups:

1. Quest items
2. Consumables
3. Materials
4. Recipes
5. Equipment
6. Ammunition
7. Containers
8. Keys
9. Miscellaneous
10. Poor-quality junk, when Junk Last is enabled

Consumables are grouped into:

```text
Food
Drinks
Bandages
Potions
Elixirs
Flasks
Scrolls
Item enhancements
Combat utility
Other consumables
```

Materials are grouped into:

```text
Herbs
Cloth
Leather, hides, and scales
Ore
Metal bars
Stone
Gems
Elemental materials
Enchanting materials
Engineering materials
Cooking ingredients
Alchemy supplies
Spell and class reagents
Other materials
```

Equipment is grouped into:

```text
Weapons
Armor
Shields and off-hands
Jewelry
Cosmetic equipment
Other equippable items
```

#### Quality

Sorts primarily by item rarity, then applies stable subgroup, name, and identity tie-breakers.

#### Name

Sorts primarily by item name while keeping duplicate items adjacent.

---

## Stack consolidation

When complete stack consolidation is enabled, MS Bag Tools:

- Skips full stacks.
- Skips non-stackable items.
- Skips empty squares.
- Skips user-locked squares.
- Skips genuinely server-locked squares.
- Groups matching stackable items by item identity.
- Fills earlier partial stacks using later partial stacks.
- Leaves at most one final partial stack for each matching item.
- Places full stacks before the remaining partial stack.
- Compacts newly freed squares toward the bottom of the selected storage area.

Example:

```text
Before:
Swiftthistle x17
Swiftthistle x5

After:
Swiftthistle x20
Swiftthistle x2
```

Inventory consolidation affects inventory only. Bank consolidation affects bank storage only.

---

## Locked squares

Lock mode works in the inventory and while the bank is open.

Locked squares:

- Retain their exact position.
- Are excluded as sorting sources.
- Are excluded as sorting destinations.
- Receive a configurable outline.
- Can remain locked whether occupied or empty.
- Are saved separately for each character.
- Can protect grey items from Sell Junk.

Resetting normal addon options does not remove locked squares.

### Locking through the UI

1. Click the `L` button in the inventory or bank header.
2. Click a square to lock or unlock it.
3. Click `L` again to leave lock mode.

---

## Sell Junk

Sell Junk is manual and inventory-only.

To sell eligible grey items:

1. Open a merchant.
2. Click the `$` button in the pfUI inventory header, or enter:

   ```text
   /msbag sell
   ```

The addon:

- Scans inventory containers `0–4`.
- Sells eligible poor-quality grey items one stack at a time.
- Skips protected locked squares.
- Skips temporary client-locked items.
- Verifies each sale before counting it.
- Reports the confirmed result when complete.
- Never sells bank items.
- Never sells automatically when a merchant opens.

---

## Configuration

Open the settings window with:

```text
/msbag
```

The configuration UI includes controls for:

- Enabling or disabling MS Bag Tools.
- Choosing category, quality, or name sorting.
- Enabling complete partial-stack consolidation.
- Placing poor-quality items last.
- Choosing quality direction.
- Blocking sorting in combat.
- Showing or hiding pfUI header controls.
- Protecting locked grey items from junk selling.
- Enabling or disabling completion announcements.
- Using pfUI's active font.
- Choosing lock-outline color and thickness.
- Setting inventory movement delay.
- Setting inventory and bank columns.
- Configuring inventory and bank fill orders.
- Sorting inventory or the open bank immediately.
- Selling junk.
- Entering lock mode.
- Clearing locks.
- Restoring defaults.

---

## Commands

### Primary slash aliases

```text
/msbag
/msbags
/msbagtools
```

### Legacy aliases

```text
/obag
/octobags
/octobagtools
```

### Configuration and actions

| Command | Description |
|---|---|
| `/msbag` | Open or close settings. |
| `/msbag config` | Open or close settings. |
| `/msbag options` | Open or close settings. |
| `/msbag sort` | Sort the carried inventory. |
| `/msbag sort bags` | Sort the carried inventory. |
| `/msbag sort bank` | Sort the open bank. |
| `/msbag sortbank` | Sort the open bank. |
| `/msbag banksort` | Sort the open bank. |
| `/msbag sell` | Sell eligible grey inventory items at an open merchant. |
| `/msbag junk` | Alias for Sell Junk. |
| `/msbag selljunk` | Alias for Sell Junk. |

### Square locks

| Command | Description |
|---|---|
| `/msbag lockmode` | Toggle click-to-lock mode. |
| `/msbag locks` | Alias for Lock Mode. |
| `/msbag lock <container> <slot>` | Lock a specific inventory or bank square. |
| `/msbag unlock <container> <slot>` | Unlock a specific inventory or bank square. |
| `/msbag clearlocks` | Clear all inventory and bank locks for the character. |
| `/msbag clearlocks bags` | Clear only inventory locks. |
| `/msbag clearlocks bank` | Clear only bank locks. |

Examples:

```text
/msbag lock 0 1
/msbag unlock 4 8
/msbag lock -1 6
/msbag lock 5 3
```

### Sorting method and layout

| Command | Description |
|---|---|
| `/msbag mode category` | Use organized category sorting. |
| `/msbag mode quality` | Sort primarily by item quality. |
| `/msbag mode name` | Sort primarily by item name. |
| `/msbag columns 4-24` | Set inventory boxes per row. |
| `/msbag cols 4-24` | Alias for inventory columns. |
| `/msbag rowwidth 4-24` | Alias for inventory columns. |
| `/msbag row 4-24` | Alias for inventory columns. |
| `/msbag bankcolumns 4-24` | Set bank boxes per row. |
| `/msbag bankcols 4-24` | Alias for bank columns. |
| `/msbag bankrow 4-24` | Alias for bank columns. |

### Inventory fill order

| Command | Description |
|---|---|
| `/msbag order` | Display the current inventory fill order. |
| `/msbag order 0 4 3 2 1` | Set the complete inventory fill order. |
| `/msbag bagorder ...` | Alias for inventory order. |
| `/msbag fillorder ...` | Alias for inventory order. |
| `/msbag order reset` | Restore `0 > 4 > 3 > 2 > 1`. |
| `/msbag movebag <0-4> left` | Move a bag earlier in the fill order. |
| `/msbag movebag <0-4> right` | Move a bag later in the fill order. |

### Bank fill order

| Command | Description |
|---|---|
| `/msbag bankorder` | Display the current bank fill order. |
| `/msbag bankorder -1 5 6 7 8 9 10 11` | Set the complete bank fill order. |
| `/msbag bankorder reset` | Restore the default bank fill order. |
| `/msbag movebank <-1\|5-11> left` | Move a bank container earlier. |
| `/msbag movebank <-1\|5-11> right` | Move a bank container later. |

### Behavior and appearance

| Command | Description |
|---|---|
| `/msbag enable` | Enable MS Bag Tools. |
| `/msbag disable` | Disable MS Bag Tools without unloading it. |
| `/msbag stacks on\|off` | Toggle complete partial-stack consolidation. |
| `/msbag junklast on\|off` | Toggle placing poor-quality items last. |
| `/msbag quality on\|off` | Toggle higher-quality items first. |
| `/msbag buttons on\|off` | Show or hide pfUI header controls. |
| `/msbag protect on\|off` | Protect locked grey items from Sell Junk. |
| `/msbag announce on\|off` | Toggle completion summaries. |
| `/msbag combat on\|off` | Toggle combat sorting protection. |
| `/msbag theme on\|off` | Toggle use of pfUI's active font. |
| `/msbag outline gold` | Use a gold lock outline. |
| `/msbag outline red` | Use a red lock outline. |
| `/msbag outline blue` | Use a blue lock outline. |
| `/msbag outline green` | Use a green lock outline. |
| `/msbag outline white` | Use a white lock outline. |
| `/msbag thickness 1-4` | Set lock-outline thickness. |
| `/msbag delay 0.10-0.30` | Set the delay between inventory operations. |

### Diagnostics and reset

| Command | Description |
|---|---|
| `/msbag status` | Print version, storage, sorting, migration, lock, and compatibility diagnostics. |
| `/msbag reset` | Restore default options while preserving locked squares. |
| `/msbag help` | Print the command reference in chat. |

---

## Temporary legacy identifiers

The following identifiers remain temporarily for migration and integration compatibility:

```text
OctoBagTools
OctoBagTools_CommandDispatch
OctoBagToolsDB
OctoBagToolsCharDB
/obag
/octobags
/octobagtools
```

The former saved-variable names are used only for migration and are not erased automatically.

---

## Troubleshooting

### Commands are not recognized

Confirm that this path exists:

```text
Interface\AddOns\MSBagTools\MSBagTools.toc
```

Then verify that **MS Bag Tools** is enabled on the AddOns screen.

### pfUI header buttons are missing

Run:

```text
/msbag buttons on
```

Then close and reopen the inventory or bank window.

### Bank sorting does not start

The bank must be open:

```text
/msbag sort bank
```

Keep the bank open until the completion message appears.

### Grey items were not sold

Confirm that:

- A merchant is open.
- The item is poor-quality grey.
- The square is not protected by a persistent lock.
- The item is not temporarily client-locked.

Check diagnostics:

```text
/msbag status
```

---

## Compatibility

MS Bag Tools targets:

```text
World of Warcraft 1.12.1
Interface 11200
```

Compatibility may vary across community-maintained client modifications.

---

## Publisher disclaimer

MoobStack is an independent community addon publisher. These addons are not affiliated with, authorized by, or endorsed by Blizzard Entertainment or any community server project. World of Warcraft and related marks are the property of their respective owners.
