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

Description
-----------

MS Bag Tools is a MoobStack utility that adds organized inventory and bank
sorting, efficient partial-stack consolidation, manual grey-item selling,
configurable container fill orders and row widths, and persistent
per-character locked squares to unified bag interfaces.

Designed for the World of Warcraft 1.12.1 client using Interface 11200.
Compatibility may vary across community-maintained client modifications.

Header controls
---------------

Inventory: S Sort, $ Sell Junk, L Lock Mode, O Options.
Bank: S Sort, L Lock Mode, O Options.

Primary commands
----------------

   /msbag                         Open or close settings.
   /msbag sort [bags|bank]        Sort inventory or the open bank.
   /msbag sell                    Sell eligible grey inventory items.
   /msbag lockmode                Toggle click-to-lock mode.
   /msbag lock <container> <slot>
   /msbag unlock <container> <slot>
   /msbag clearlocks [bags|bank]
   /msbag mode category|quality|name
   /msbag columns 4-24
   /msbag bankcolumns 4-24
   /msbag order 0 4 3 2 1
   /msbag bankorder -1 5 6 7 8 9 10 11
   /msbag movebag <bag> left|right
   /msbag movebank <bag> left|right
   /msbag stacks on|off
   /msbag junklast on|off
   /msbag quality on|off
   /msbag buttons on|off
   /msbag protect on|off
   /msbag announce on|off
   /msbag combat on|off
   /msbag theme on|off
   /msbag outline <color>
   /msbag thickness 1-4
   /msbag delay 0.10-0.30
   /msbag status
   /msbag reset
   /msbag help

Additional primary aliases: /msbags and /msbagtools.
Legacy aliases retained: /obag, /octobags, and /octobagtools.

Migration
---------

The update package copies OctoBagToolsDB into MSBagToolsDB and copies each
character's OctoBagToolsCharDB into MSBagToolsCharDB. Legacy data is not erased.
Log into every affected character once before removing the legacy bridge.

Publisher disclaimer
--------------------

MoobStack is an independent community addon publisher. These addons are not
affiliated with, authorized by, or endorsed by Blizzard Entertainment or any
community server project. World of Warcraft and related marks are the property
of their respective owners.

