MS Bag Tools changelog
======================

1.1.3
-----
- Rebranded OctoBagTools as MS Bag Tools under the MoobStack publisher.
- Renamed the main folder, TOC, source files, addon table, saved variables,
  frame names, UI branding, messages, and documentation to MS-prefixed names.
- Added /msbag, /msbags, and /msbagtools as primary command aliases.
- Retained /obag, /octobags, and /octobagtools as legacy aliases.
- Added migration from OctoBagToolsDB and each character's
  OctoBagToolsCharDB without deleting the legacy saved data.
- Added a temporary legacy bridge for settings-preserving update installs.
- Updated compatibility language to World of Warcraft 1.12.1 and Interface
  11200 without tying the addon to a specific server project.
- Preserved the working inventory sorting, bank sorting, stack consolidation,
  junk selling, locked-square, pfUI toolbar, and settings behavior from 1.1.2.

Legacy history
--------------
Versions 1.0.0 through 1.1.2 were published under the OctoBagTools name.


MS Bag Tools 1.1.3
==================

Publisher: MoobStack
Internal addon name: MSBagTools

Designed for the World of Warcraft 1.12.1 client using Interface 11200.
Compatibility may vary across community-maintained client modifications.

Description
-----------

MS Bag Tools extends pfUI's unified inventory and bank interfaces with organized
sorting, efficient partial-stack consolidation, manual grey-item selling,
configurable fill orders and row widths, and persistent per-character locked
squares.

Inventory sorting covers containers 0 through 4. Bank sorting covers the main
bank container -1 and accessible bank-bag containers 5 through 11. Inventory
and bank contents are never mixed.

Inventory header controls:

   S   Sort inventory
   $   Sell grey junk at an open merchant
   L   Toggle click-to-lock mode
   O   Open settings

Bank header controls:

   S   Sort bank
   L   Toggle click-to-lock mode
   O   Open settings

Clean installation
------------------

1. Completely exit World of Warcraft.
2. Extract MSBagTools into Interface\AddOns.
3. Confirm:

   Interface\AddOns\MSBagTools\MSBagTools.toc

4. Enable MS Bag Tools at character selection.
5. Log in and enter /msbag status.

Updating from OctoBagTools 1.1.2
--------------------------------

Use the settings-preserving update patch. It contains two sibling folders:

   Interface\AddOns\MSBagTools\
   Interface\AddOns\OctoBagTools\

The second folder becomes a small legacy migration bridge. It loads the former
OctoBagToolsDB and OctoBagToolsCharDB saved variables before MS Bag Tools starts.
It does not run the old sorting addon code.

1. Completely exit World of Warcraft.
2. Extract the update patch into Interface\AddOns and replace existing files.
3. Enable MS Bag Tools and MS Bag Tools Legacy Migration.
4. Log into every character that used inventory or bank square locks.
5. Enter /msbag status on each character.
6. Confirm the Saved data line says legacy migration complete or that settings
   were imported this session.
7. Exit the client normally so MSBagToolsDB and MSBagToolsCharDB are saved.

The migration never erases OctoBagToolsDB or OctoBagToolsCharDB. After every
character has migrated and the new data has been verified, the legacy addon
folder may be disabled or deleted. The old saved-variable files may also be
removed manually after making a backup:

   WTF\Account\<Account>\SavedVariables\OctoBagTools.lua
   WTF\Account\<Account>\<Realm>\<Character>\SavedVariables\OctoBagTools.lua

Sorting and consolidation
-------------------------

The default inventory fill order is 0 > 4 > 3 > 2 > 1. The default bank fill
order is -1 > 5 > 6 > 7 > 8 > 9 > 10 > 11. Both orders and both grid widths are
configurable.

Category mode organizes quest items, consumables, materials, recipes,
equipment, containers, keys, miscellaneous items, and optional poor-quality
junk into stable subgroups. Stack consolidation skips full and non-stackable
items, fills matching partial stacks efficiently, and leaves at most one final
partial stack for each matching item.

Locked squares
--------------

Lock mode works in the inventory and while the bank is open. Locked squares are
excluded as sorting sources and destinations, retain their exact positions, and
receive a configurable outline. Locks are stored per character in
MSBagToolsCharDB. Resetting normal options preserves locks.

Sell Junk
---------

Sell Junk is manual and inventory-only. Open a merchant and click $ or enter
/msbag sell. Eligible grey items in containers 0 through 4 are sold one stack at
a time. Protected locked squares and temporary client locks are skipped. Bank
items are never sold.

Commands
--------

Primary aliases:

   /msbag
   /msbags
   /msbagtools

Legacy aliases retained for macros and existing habits:

   /obag
   /octobags
   /octobagtools

Configuration and actions:

   /msbag                         Open or close settings.
   /msbag config                  Open or close settings.
   /msbag options                 Open or close settings.
   /msbag sort [bags|bank]        Sort inventory or the open bank.
   /msbag sortbank                Sort the open bank.
   /msbag banksort                Sort the open bank.
   /msbag sell                    Sell eligible grey inventory items.
   /msbag junk                    Alias for Sell Junk.
   /msbag selljunk                Alias for Sell Junk.

Locks:

   /msbag lockmode
   /msbag locks
   /msbag lock <container> <slot>
   /msbag unlock <container> <slot>
   /msbag clearlocks [bags|bank]

Sorting method and layout:

   /msbag mode category|quality|name
   /msbag columns 4-24
   /msbag cols 4-24
   /msbag rowwidth 4-24
   /msbag row 4-24
   /msbag bankcolumns 4-24
   /msbag bankcols 4-24
   /msbag bankrow 4-24
   /msbag order [0 4 3 2 1]
   /msbag bagorder [0 4 3 2 1]
   /msbag fillorder [0 4 3 2 1]
   /msbag order reset
   /msbag movebag <0-4> left|right
   /msbag bankorder [-1 5 6 7 8 9 10 11]
   /msbag bankorder reset
   /msbag movebank <-1|5-11> left|right

Behavior and appearance:

   /msbag enable|disable
   /msbag stacks on|off
   /msbag junklast on|off
   /msbag quality on|off
   /msbag buttons on|off
   /msbag protect on|off
   /msbag announce on|off
   /msbag combat on|off
   /msbag theme on|off
   /msbag outline gold|red|blue|green|white
   /msbag thickness 1-4
   /msbag delay 0.10-0.30

Diagnostics:

   /msbag status
   /msbag reset
   /msbag help

Temporary legacy identifiers
----------------------------

The runtime aliases OctoBagTools and OctoBagTools_CommandDispatch remain
temporarily for integrations that referenced the former addon table. The old
slash aliases remain registered. The former saved-variable names are read only
for migration and are not erased.

Publisher disclaimer
--------------------

MoobStack is an independent community addon publisher. These addons are not
affiliated with, authorized by, or endorsed by Blizzard Entertainment or any
community server project. World of Warcraft and related marks are the property
of their respective owners.
