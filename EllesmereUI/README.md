# EllesmereUI (5.4.8)

EllesmereUI for Mists of Pandaria (5.4.8), a backport of the retail EllesmereUI addons. Before version 3.0 this addon was called "Antrophy Utilities". Commands: `/eui` or `/au` open the settings window. Each module is one entry in the settings sidebar, with its pages as subtabs.

Since 3.1 the suite is split into addons like retail (see "Addons" below). Enable or disable each module in the AddOns list. `EllesmereUI` is required by all of them.

## Global Settings

The fixed second row of the sidebar, under Unlock Mode (like EllesmereUI). Page General > Display:

- **UI Scale** (0.40 to 1.00): scale of the whole game UI, saved in `EllesmereUIDB.ppUIScale` and set with `UIParent:SetScale`, so it can go below Blizzard's 0.64 minimum. 0.53 and 0.71 snap to 0.5333 and 0.7111, the pixel perfect values of 1440p and 1080p. It is applied when the addon loads, at login and whenever Blizzard re-applies its own scale. A change made in combat is applied when combat ends. The settings window keeps its size and place on the screen while you drag the slider. On first run the scale you already use is kept.
- **Window Scale** (75% to 200%, 5% steps): the slider in the top right corner of the settings window, like EllesmereUI. 100% = 1 window unit per screen pixel. Drag it (the window changes when you let go) or use the mouse wheel on it; Shift + mouse wheel anywhere on the window works too. The window glides to the new size. Saved in `EllesmereUIDB.panelScale`; the window position in `EllesmereUIDB.window`. The old corner resize grips are gone; a size set with them is kept (rounded to 5%).
- With ElvUI loaded, ElvUI keeps control of the scale and the slider is disabled (use ElvUI > General > UI Scale).

Since 3.2 the General page is the retail EllesmereUI one (`EllesmereUI_General.lua` in the core, page in `EllesmereUIOptions\EUI__General_Options.lua`):

- **Top row**: Reset ALL EUI Addon Settings (type "Confirm"; wipes every `EllesmereUI*DB` and deletes all profiles like retail, keeps the UI scale and per-character data such as Reforge weights), Optimize My FPS and Graphics / Restore My Graphics Settings (5.4.8 graphics CVars, backup in `EllesmereUIDB.gfxBackup`, "What Does This Do?" lists them), Uninstall EUI (puts back every CVar EUI changed, recorded in `EllesmereUIDB.restoreOnUninstall`, disables all EllesmereUI addons for this character, reloads).
- **Display**: UI Accent Color (Class Color or Custom Color; colors the whole settings window live), EUI Options Theme (11 themes: EllesmereUI, Original, Forever, Horde, Alliance, Faction (Auto), Midnight, Dark, Pixels, Class Colored, Custom Color with its own swatch; window art in `media\ui\themes\`, crossfade), UI Scale, EUI Buttons (Escape menu "EllesmereUI" button, Escape menu "EUI Unlock Mode" button, minimap button: left-click settings, right-click Unlock Mode, middle-click hide, drag to move).
- **Combat**: Max Camera Distance (`cameraDistanceMaxFactor` 1-2.6), Cast Actions on Key Down, Lag Tolerance (5.4.8 Custom Lag Tolerance: `reducedLagTolerance` + `maxSpellStartRecoveryOffset`), Combat Text (Damage, Healing, Periodic, Pet Melee, Pet Spell), Combat Text Font (`DAMAGE_TEXT_FONT`, needs a logout; fonts in `media\fonts`).
- **Developer**: Suppress Lua Errors (default on, applied at login), Show Spell ID on Tooltip (spells, auras, items).
- At login, like EllesmereUI: camera distance 2.6 and key down are set only where the game default is still in use.
- **Fonts page** (`EllesmereUI_Fonts.lua`, settings in `EllesmereUIDB.fonts`, same keys as EllesmereUI): Global Font (26 fonts in `media\fonts` + LibSharedMedia; cog: Apply to All Game Text), Outline Mode, Outline Icon Text (Unit Frames icons), Name Font (`UNIT_NAME_FONT`, needs a logout), Game Text Scale (75-125%), and per module (Action Bars, Unit Frames, Blizzard Skins+ / Character Sheet, Damage Meters / Spell History) a font override, Module Outline and its text sizes. Font changes ask for a reload. Not ported: Disable Slug Outline (retail renderer), the Combat & World Text card, cards for modules without text.
- **First Time Setup** (3.16, `EllesmereUI_FirstInstall.lua`, retail port): on the first login of a new install (EllesmereUIDB empty when the core loads) a "Welcome to EllesmereUI" popup: Core / QoL / UI Reskin columns with a checkbox per installed module, Check All / Uncheck All, Reload UI (turns unchecked addons off for this character). Added: Import Profile (keeps the addon choices, opens Profiles with the paste box). Open it again with `/eui setup` or Profiles > First Time Setup. Not ported: Cursor Circle checkbox, the retail style picker.
- **Profiles** (3.16, own sidebar row under Global Settings like retail "Profiles & Presets", `EllesmereUI_Profiles.lua` + `EllesmereUI_ProfilesRetail.lua`, page `EllesmereUIOptions\EUI_Profiles_Options.lua`): Import Profile / Export Profile cards, Active Profile (switch = reload), New Profile (copy, no reload), Rename, Delete; Export with an addon checklist + Include Unlock Mode Layout / Global Settings, string in a copy box. Import: paste, then a page with Profile Name, addon checklist and Include toggles; it makes a new profile, makes it active and reloads. A profile = copy of each module's SavedVariables (minus private data: DataBars character list, Interrupt Tracker caches, Reforge per-character data, Top Bar first-login marker) + core keys (theme, accent, fonts, UI scale; Unlock Mode links). Other profiles live in `EllesmereUIDB.profiles`, the active one is the live SavedVariables. Strings: this port writes `!EUIM_` (same LibDeflate encoding as retail; retail refuses them), and reads retail `!EUI_` strings, also full account ones: retail module profiles are converted (same keys for Action Bars, Nameplates, Unit Frames, Resource Bars, Bags, Minimap, Chat, DataBars; only matching parts for QoL Battle Res / Bloodlust, Quest Tracker, Spell History, Blizzard Skins+ incl. character sheet, Top Bar from NaowhUI), Unlock Mode links to retail-only elements are dropped and those elements keep the current position. Not ported: Assign to Spec (a switch reloads), profile keybinds, Popular Presets, Overrides.
- **Not ported** (no 5.4.8 support): EUI Options Language, Disable Sync Icons (no profiles), Increase Game Image Quality, Combat Text Size, Prevent Swiftmend Icon Dim. The old "Pixel Perfect Scale" button is gone (not in EllesmereUI); the footer reset still sets the pixel perfect scale.

## Action Bars (Core Addons)

The EllesmereUI Action Bars (`EllesmereUIActionBars`, retail 9.3.8), rebuilt on the 5.4.8 API with the same look, settings, keys and defaults. Settings: `/eui` > Core Addons > Action Bars (pages Bar Display, XP Bar, Menu, Bags & Rep Bars, Bar Animations). Move the bars in Unlock Mode.

- **Bar Display header** (fixed above the settings, like retail): the keyboard button (Quick Keybind Mode), the centered bar picker and a live preview of the selected bar (grid, icons, border, icon background, texts at real size). Click an icon or a text in the preview to scroll to and flash its setting.
- **Quick Keybind Mode** (keyboard button or `/kb`; 5.4.8 has no Blizzard Quick Keybind, so this port has its own): every bar not set to Never comes up with its empty slots and a highlight on each button. Hover a button and press a key (with Shift / Ctrl / Alt), a mouse button or the mouse wheel to bind it; right-click clears it. Okay saves (Character Specific Keybindings or account), Cancel puts the saved bindings back, Escape = Okay, combat ends the mode.

- **Bars**: Action Bar 1 (Main), 2-5 (Blizzard's bottom left / bottom right / right / left pages), 9 (page 2) and 10 (page 10; for druids also the Moonkin bar), Stance Bar, Pet Bar, Micro Menu, Bag Bar, Extra Action Button, XP and Reputation bars. Blizzard's own bars are switched off (ElvUI pattern).
- **Buttons**: our own secure buttons (SecureActionButtonTemplate + ActionButtonTemplate, like LibActionButton) with our own update code, so Blizzard's action bar code never runs on them (no taint). Paging (forms, stances, vehicle, override, possess, `[bar:N]`, Modifier/Target paging, class form pages) and visibility are secure state drivers, so they work in combat. Stance / pet buttons use Blizzard's StanceButtonTemplate / PetActionButtonTemplate.
- **Keys**: the standard binding commands (ACTIONBUTTON1, MULTIACTIONBAR1BUTTON1, SHAPESHIFTBUTTON1, BONUSACTIONBUTTON1, and "EllesmereUI Action Bar 9 / 10" in Key Bindings) go to our buttons through override bindings (off during pet battles). Cast Actions on Key Down applies to keys; a mouse click acts on release. The key press shows the pushed art.
- **Look** (EllesmereUI style): square icons with Icon Zoom, 1 px black border (size 0-4, custom or class color), flat Icon Background (color + opacity), the EllesmereUI square highlight / pushed / checked art in the Bar Interactions color (Light / Medium / Strong / Solid Color / Border / None), keybind / charges / macro text in the module font (positions and offsets), cooldown numbers (5.4.8 has none: this port draws them; Charge Recharge Numbers), Desaturate on Cooldown, Alpha when on CD, CD Swipe Opacity, Out of Range Coloring (keybind red while out of range like retail), Hide Charge Count at 0, Show Equipped Item Color, Blizzard Icon Background, Cropped shape, Bar Background (color, opacity, border, multipliers), Custom Proc Glow (Pixel Glow, Action Button Glow, Auto-Cast Shine; None = Blizzard's glow), square spell flyouts.
- **Visibility**: the EllesmereUI checklist (Never / Always / Mouseover, Match All / Any, Show / Hide lanes: combat, group, instances, mounted, target, enemy, resting), Bar Opacity, Show All Bars on Mouseover, Show When Spellbook Is Open, Show During Drag, Click Through, Toggle Action Bar key, Always Show Buttons.
- **First run**: a new `EllesmereUIActionBarsDB` gets the retail EllesmereUI "Naowh" profile (positions, 36 px buttons, spacing 1, mouseover bars 1-5 and pet, rows, icon order, text offsets, hidden stance / micro / bag / XP bars, black 70% icon background, Hide Charge Count at 0); retail countdownForCooldowns was on, so Cooldown Numbers are on. Reset Action Bars goes to the EllesmereUI defaults.
- **Not in 5.4.8, left out**: Action Bars 6-8 (pages 13-15 do not exist), custom button shapes other than Cropped (no mask textures), textured border styles, End Caps, Blizzard / Classic stock styles, CD swipe color, cooldown edge art, One Button Assist, Show Item Rank, Hide Casting Animations, Skyriding paging, House Favor and Queue Status bars, the XP bar art styles / dividers / text slots / quest XP overlay.
- ElvUI: if ElvUI's action bars are on for a character, EllesmereUI Action Bars stay off there (chat hint).
- Saved settings: `EllesmereUIActionBarsDB.profile` (same keys as the EllesmereUI profile). Art in `EllesmereUIActionBars/Media` (EllesmereUI highlight art, converted to TGA).

## Unit Frames (Core Addons)

The EllesmereUI unit frames, rebuilt with the 5.4.8 API (own engine, no oUF). Settings: `/eui` > Core Addons > Unit Frames. While the page is open, every enabled frame is shown with sample data so you can see your changes.

- **Frames**: Player, Target, Focus, Target of Target, Focus Target (off by default), Pet, Boss 1-5. Same sizes, positions, look and defaults as EllesmereUI: 1 px black border (white on hover), flat bars, class / reaction colors, #111111 background behind missing health, Expressway font with a shadow, "240K | 77%" health text.
- **Tabs**: Main Frames (Player / Target / Focus, picked with "Edit Frame"), Boss Frames ("Activate Boss Preview" shows 5 sample frames), Mini Frames (Target of Target / Focus Target / Pet).
- **Sections** like EllesmereUI: Display, Portrait, Health Bar, Power Bar, Cast Bar, Text Bar, Class Resource, Buffs and Debuffs, Absorbs and Heals, Extras. Gear icons open the extra settings (EllesmereUI cog popups); the sync icon (green while the frames differ) copies a setting to the other frames ("Apply to All"); "Apply All Settings From" copies a whole frame.
- **Moving**: Unlock Mode (top row of the sidebar). Every frame, the boss group, a detached player cast bar and a detached class resource have a mover.
- **Mapped to MoP**: class resource = combo points (on target), holy power, chi, shadow orbs, soul shards, burning embers (partial), demonic fury and eclipse (bars), DK runes (rune colors, cooldown fill), arcane charges and maelstrom weapon (aura stacks). Absorbs use `UnitGetTotalAbsorbs`, heal absorbs `UnitGetTotalHealAbsorbs`, heal prediction `UnitGetIncomingHeals`. Kick tick and "interrupt on cooldown" color use your class interrupt (`GetSpellCooldown`). Debuff filter "Boss Debuffs" uses the 5.4.8 boss debuff flag (retail "important" does not exist). Threat % works on all clients (`UnitDetailedThreatSituation`).
- **DK disease copies:** when the client reports Blood Plague (55078) or Frost Fever (55095) multiple times from the same caster, EUI shows one icon per disease/caster. The copy with the latest expiry supplies the timer, stack count, and original tooltip index; counts are not added together. This display-only rule is shared by unit frames, nameplates (including cached auras), Player Aura Bars, raid-frame debuffs, and Co-Tank debuffs. Different casters, unknown casters, and other spells stay separate. `/euiauras target` prints the raw entries, source GUIDs, expirations, and whether a copy was hidden; combat effects and damage are unchanged.
- **My Debuff Size (%)**: Unit Frames > Main Frames > **Target or Focus** > Buffs and Debuffs, and Unit Frames > **Boss Frames** > Buffs and Debuffs. Enlarge your debuff icons (including your pet/vehicle) to 100-200% of the normal icon size; 100% is the unchanged default, 125% is a modest increase. In Simple Boss Display the base size is the frame height. Other casters and buffs keep their normal size, and text sizes remain separately configurable. Mixed-size rows/columns wrap without overlapping, including cropped icons, ownership changes, and previews. Each frame type has an independent `debuffMineScale` setting in `EllesmereUIUnitFramesDB.target`, `.focus`, or `.boss`; the Boss setting applies to all five boss frames.
- **My Debuffs First**: in the same Target, Focus, and Boss settings, group your debuffs (including pet/vehicle) ahead of other casters, after disease-copy consolidation and before Max Count is applied. Each group keeps the client's aura order rather than sorting by changing durations. Works with My Debuff Size and previews, in both normal and Simple Boss Display. Off by default to preserve existing ordering; each frame type stores its own `debuffMineFirst`.
- **Debuff Growth Direction**: a visible dropdown in Buffs and Debuffs, no longer hidden in the Debuff Settings cog. Choices are Auto, Up, Down, Left, and Right. Select **Right** to put the first icons (your debuffs with My Debuffs First enabled) on the left. Auto retains the existing anchor-based layout; in Simple Boss Display it grows away from the selected side. Explicit directions work in both boss display modes. The controls are disabled only when that frame's debuffs are hidden.
- **Not in 5.4.8, left out**: Player Aura Bars tab, textured border styles (only Solid), portrait masks (detached shapes: Portrait, Square, Circle for 2D), portrait dragons, Blizzard / Classic stock styles, Skyriding / Housing / Party Mode visibility, nicknames, Important Cast Glow, Tracked Auras popup (spell ID lists), pet happiness, spell target API (the cast's target is the caster's target at cast start).
- **Combat**: secure frames cannot be moved or resized in combat. Changes made in combat are applied when combat ends. Frames hidden by a visibility condition fade out (alpha 0) instead of hiding.
- Saved settings: `EllesmereUIUnitFramesDB` (same keys as the EllesmereUI profile).

After first installing the disease-copy update (which adds `EllesmereUI_Auras.lua` to the core TOC), fully close and restart WoW. The 5.4.8 client can keep the previous TOC/file list through `/reload`; the updated modules then cannot find the new shared function, so debuffs fail to render. Install the core and affected modules together. Later changes to already-loaded files, including My Debuff Size, only need `/reload`.

Aura display regression checks (Lua 5.1, from the repository root): `lua EllesmereUI\tests\AuraDisplay.lua`. The tests replay duplicate disease entries through all five displays and verify Target, Focus, and Boss self-debuff controls, sizing, ordering, and layout with mocked client APIs; no game installation is accessed.


## Interrupt Tracker

Interrupt cooldown tracker, extracted from `ExRT` / `ExCD2` logic for Mists of Pandaria (`## Interface: 50400`).

## What it keeps

- raid/party interrupt roster tracking
- spec-sensitive interrupt spell selection
- talent/glyph cooldown adjustments for interrupt spells (Disrupting Shout talent; Asphyxiate hides Strangulate). Stuns are not tracked.
- pet-owner interrupt tracking for hunter / warlock / death knight pets
- running cooldown persistence across reloads

## Settings

`/eui` and `/au` are the only commands. It opens the settings window (EllesmereUI art and layout, 1040 x 757, settings in two columns: sidebar entry "Interrupt Tracker" with subtabs General, Sorting, Appearance, Test & Help; switch toggles, flat sliders with a number box, dropdowns with font/texture preview, color swatches). Interface Options has a small page with an "Open settings" button. Options:

- enable, lock (also a footer button; unlocked shows a green move box), click through, show when solo, hide dead or offline players, grow direction (Up = anchor at the bottom, default; Down = anchor at the top). The frame is moved in Unlock Mode
- Appearance: Layout (sizes), Bars (texture, gray icon, ready/active/cooldown/dead colors), Text (font, font size, class colored names or own name color, spell name on/off and color, timer color)
- **Roles** multi-select (Tank, Damage, Healer; default Tank + Damage). Role comes from the spec (inspect / spells they cast) or the group role.
- **Sort by: Cooldown**. Ready interrupts on top, shortest total cooldown first. Then interrupts on cooldown, least time left first. Dead or offline players at the bottom.
- **Reverse order** reverses the order inside each group (ready stays on top)
- **Test mode**: shows fake players who use interrupts at random, die and disconnect. Good to check the look. Not saved after reload.
- width, line height, visible lines, scale, alpha, font size
- bar texture and font (Blizzard, ExRT media if ExRT is installed, LibSharedMedia). Long lists are split into pages.
- class color names, icon desaturation, cooldown-only display
- bars always have a dim background track, so an empty (0%) bar is still visible

## Character Sheet (Blizzard Skins)

The EllesmereUI character sheet (`EllesmereUIBlizzardSkin_CharacterSheet.lua`), made for 5.4.8. Settings: `/eui` > UI Reskin Addons > Blizzard Skins > Character Sheet.

- **Style**: EllesmereUI (sheet art + dark overlay), Modern (flat color + opacity), Blizz Default (Blizzard's sheet with the EllesmereUI stats and slot text), Off. A change between EllesmereUI / Modern and the others needs a UI reload.
- **Size**: Width (540-900, default 640) and Height (424-720, default 500) sliders for EllesmereUI and Modern; EllesmereUI's own sheet is 540 x 424. The right slot column and the stats follow the right edge, the slot rows spread over the height, the model fills the middle, the weapons stay centered. Every tab uses the same size: the Reputation rows stretch to the full width and extra rows are created for a taller sheet (NUM_FACTIONS_DISPLAYED follows the height), the Currency list fills the sheet with rows as wide as the list.
- **Layout like EllesmereUI**: sheet that is always open wide, slots in 2 columns, weapons at the bottom, own player model (left drag rotates, right drag pans, wheel zooms, drop an item to equip), stats column on the right with Character / Titles / Equipment labels, flat bottom tabs with an accent underline, eye button to hide the slot text.
- **Reputation and Currency tabs** (EllesmereUI and Modern, like EllesmereUI's Skin_RepCurrency): header rows with a faint plate, white hover and a chevron in place of the +/- box; flat reputation bars on a dark trough with a 1 px border; white Expressway text (currencies you have 0 of stay gray); slim 4 px scrollbar thumbs; the reputation detail popup as a dark panel and the currency options popup with the sheet backdrop, both with flat checkboxes (green tick) and the plain X. Retail EllesmereUI keeps currency rows stock only because of a retail-only transfer taint, so here they get the same rows as reputation.
- **Fonts and sizes like EllesmereUI** (Expressway): item level 18, section titles 11, stat rows 10, slot item level 11, upgrade level 11, enchant 9 (setting), labels 10, tabs 9, titles list 11.
- **Core Options**: Item Details (Item Level, Upgrade Level, Gems), Icon Zoom, Enchants (None / Text / Colored Text) and Enchant Text Size, Gear Flyout Item Levels, Hide Slot Flyout Arrows, Show Item Durability (Above Model / Stats Header / Frame Footer, label on/off).
- **Stat Display**: Stat Sections (Attributes, Secondary, Attack, Defense, Currencies, PvP), Secondary Text (Percent / Value / Value (Percent)), Secondary Highlights, Show Mana, Currencies (Valor, Justice), Blizzard UI Color (Blizz Default), a color per section. Section titles collapse on click; the arrows move sections. Order and collapsed state are saved.
- **Mapped to MoP**: upgrade track -> item upgrade level (1/2); crests -> Valor and Justice; tertiary stats -> Hit and Expertise (Secondary), Resilience and PvP Power (PvP); missing enchant check on the MoP enchant slots (rings only for enchanters), at level 90.
- **Not in 5.4.8, left out**: Mythic+ rating, PvP item level, Season Panel, Socket Panel, Upgrades tab, Diminishing Returns tooltips, the inspect sheet.
- Item level, upgrade level and enchant come from a scanning tooltip (5.4.8 `GetItemInfo` has the base item level only).
- ElvUI: if its Skins > Character Frame is on, the sheet removes ElvUI's borders on these frames and prints a hint to turn that skin off.
- Saved settings: `EllesmereUIBlizzardSkinDB.charSheet`.

## Bags (UI Reskin Addons)

The retail EllesmereUI Bags addon (`EllesmereUIBags`, 9.3.8), run on 5.4.8. Settings: `/eui` > UI Reskin Addons > Bags (pages Bags and Bank, same options and keys as EllesmereUI). Text sizes and the Bags font are also on Global Settings > Fonts.

- **Same code as retail**: the retail files run unchanged where they can. `EllesmereUIBags_Compat.lua` builds a private environment (`setfenv` on line 1 of every other file) with the retail APIs rebuilt on 5.4.8: `C_Container`, `C_Item`, `ItemLocation`, `C_Timer`, `Enum`, `C_TooltipInfo`, `C_CurrencyInfo`, `C_EquipmentSet`, `MenuUtil` context menus, the EllesmereUI popups, widget tooltip, pixel borders and Lite DB. Nothing of it is written into the real globals.
- **Bag window**: header (title, item count, search, sort, bag slots, close), collapsible category sidebar (drag to reorder, group, ungroup; right-click menu: rename, groups, hide in All Items; Add Category with icon picker), All Items / OneBag / MultiBag / category / group views, Pinned and Recent Items, middle-click pin/unpin, assign items to categories, quality borders, item level on gear, quest item border and "!" marker, unusable items in red, merged duplicates, Armory slot groups, gold tracking tooltip (all characters), currency footer, resize grip, Auto-Size, Shift-drag to move, stack splitter with Auto Split (bags, bank, guild bank), List display (reload).
- **Bank**: the EllesmereUI bank window. 5.4.8 has no bank tabs: the main bank is tab "Bank" and every bag in a bank bag slot is a tab of its own (its name and icon). The bag-slot button shows the 7 bank bag slots (drag bags in/out; a slot not bought yet opens Blizzard's purchase popup, as does "Buy Bank Bag Slot" in the sidebar). OneBank, All Bank Tabs, category sidebar, grouping by category / expansion, list view.
- **Mapped to MoP**: no reagent bag (container 5 is the first bank bag in 5.4.8), no warband bank (no warband gold, gold transfer or deposit buttons), no Housing category; profession bags (herb, mining, ...) get the "Special Bags" category and their own OneBag sections, as on WoW Forever. Item classes come from the localized `GetItemInfo` types. Item level, upgrade level ("Show Gear Track Rank" shows the item upgrade level, e.g. 1/2), soulbound / BoE and red (unusable) text are read from a scanning tooltip. Expansion nesting guesses the expansion from the required level / item ID. Sort: OneBag sorts by category like retail; MultiBag and the bank use a sort of this port (Blizzard's clean-up arrived in 6.0). Atlases and file IDs are mapped to 5.4.8 art (pinned = star, recent = pocket watch, quest = "!"). Custom category icons take an icon name (e.g. `INV_Misc_Bag_08`), not a file ID.
- **Not in 5.4.8, left out**: reagent bag window, warband bank, bank tab settings (names, icons, deposit filters), keystones, upgrade-track colors, controller (gamepad) support. Round icons in the List display use `SetPortraitToTexture` (no mask textures in 5.4.8).
- **First run**: a new `EllesmereUIBagsDB` gets the bag settings of the retail EllesmereUI profile ("Naowh"): OneBag default, Auto-Size, collapsed sidebar, The Armory / Adventure Prep groups, Group Armory by Slot, no duplicate merging, Randomize and OneBag warning hidden, text sizes 14. Reset Bags goes to the EllesmereUI defaults.
- ElvUI Bags (if on) take the same keys: a chat hint says so at login.
- Saved settings: `EllesmereUIBagsDB.profile`; per-character data (pinned items, item assignments, gold history, tracked currencies) in `EllesmereUIDB` like retail.
- Art in `EllesmereUIBags/Media` (EllesmereUI art, converted to TGA).

## Minimap (UI Reskin Addons)

The retail EllesmereUI Minimap (`EllesmereUIMinimap`, 9.3.8), rebuilt on the 5.4.8 API with the same look, settings and keys. Settings: `/eui` > UI Reskin Addons > Minimap. Move it in Unlock Mode. Its text font is on Global Settings > Fonts (module "Minimap").

- **Map**: taken out of Blizzard's MinimapCluster (hidden with its zone text, border ring, north tag, world map button, voice chat button and round zoom buttons). Shapes Square, Rectangular (4:3 crop, retail mask art) and Circle; Size 100-600; Border Size 0-4 in Accent / Class / Custom color; Rotate Minimap; Reset Zoom after N seconds; Scroll to Zoom; Opacity (Visibility cog); Visibility checklist like the Action Bars (Never / Always / Mouseover, Show / Hide lanes). Ping works on the whole visible map (the stock code pings only inside a circle).
- **Buttons**: addon buttons (LibDBIcon and other named minimap buttons, also the EllesmereUI button) go into one group behind a toggle (flyout grid, In-Group Button Size); Ungroup Minimap Buttons puts picked ones on the button row; Button Row Position / Icon Spacing / Distance from Map / Grow Tooltip/Popup; Free Move (Shift + drag, Reset Button Positions); Button Backgrounds; Mouseover Extra Buttons; Friends Online button with the EllesmereUI friends tooltip (guild + Battle.net / character friends, left-click whisper, right-click Whisper / Invite, notes, row cap).
- **Blizzard elements** (EllesmereUI black boxes, 5.4.8 art): Tracking (opens the tracking menu), Calendar (calendar page with today's date; hover = saved instance lockouts, server time, weekly reset), Mail (senders on hover; on the row or pinned to a corner), Difficulty flag, Zoom +/- (small EllesmereUI buttons, shown on hover), Element Row Position. **Show Queue Status**: the 5.4.8 queue eye, Never / On Hover / Always, pinned to a map corner with X / Y and scale (it takes the place of retail's Omnium Folio row).
- **Text**: Clock (Inside Map / Edge Box, position, scale, offsets, hover = lockouts), Zone Text (sub zone, reactive PvP colors), Coordinates (Never / On Hover / Always, decimals), FPS/MS (local / world MS, interval, text size), Instance Difficulty as Text ("25H", "14F" for Flexible, "CM" for Challenge Mode, "HS" heroic scenario; Reactive colors), Accented Text (accent or custom color for AM/PM, FPS/MS words, difficulty letter).
- **Middle-click** the map: the EllesmereUI micro menu (Character, Spellbook, Talents, Group Finder, PvP, Dungeon Journal, Achievements, Mounts & Pets, Quest Log, Friends, Guild, Calendar, Game Menu, Shop, Support). Panels that open on click go through secure `/click` buttons. Not in combat.
- **First run**: a new `EllesmereUIMinimapDB` gets the retail "Naowh" minimap settings (255 px, button size 28, mouseover extra buttons, mail at the top left corner, no clock, coordinates on hover, difficulty as text at the top right, ...). Reset Minimap goes to the EllesmereUI defaults (the map starts from Blizzard's size and place again).
- **Not in 5.4.8, left out**: Blizzard / Classic stock styles, textured border styles, Textured Circle, Icon Size, Great Vault, M+ Portals, Crafting Orders, Omnium Folio, Addon Compartment, housing map, Battle.net favorites. Weekly reset time: 5.4.8 has no API, so it is the daily reset moved to Tuesday (US) or Wednesday (other regions).
- ElvUI: if ElvUI's minimap is on for a character, EllesmereUI Minimap stays off there (chat hint). Turn off ElvUI > Maps > Minimap > Enable.
- Saved settings: `EllesmereUIMinimapDB.profile.minimap` (same keys as the EllesmereUI profile).

## Chat (UI Reskin Addons)

The retail EllesmereUI Chat (`EllesmereUIChat`, 9.3.8) on the 5.4.8 chat frames, with the same look, settings and keys. Settings: `/eui` > UI Reskin Addons > Chat (pages Chat, Tabs, Sidebar). Move the main window in Unlock Mode. Its font is on Global Settings > Fonts (module "Chat") or the Chat page's own Font.

- **Panel**: one dark panel behind each chat window and its input box (Background Opacity / color / texture), 1 px inner borders (Hide Borders, custom or accent color), outer Border Size 0-4 in Custom / Accent / Class color (Show Behind), Lock Main Chat Size, Visibility checklist (Never / Always + Show / Hide conditions), Idle Fade (delay, strength; 100 = fully hidden and click-through; hover or typing wakes it).
- **Tabs**: EllesmereUI tabs over Blizzard's tabs (Blizzard's still click, drag, open the tab menu): background colors and texture, active underline, font / size / colors, Tab Height, Inner Padding X (tab width = label + padding), Tab Spacing, own border or synced with the panel, Tabs Inside Chat Panel band, whisper alert glow.
- **Sidebar**: Friends (online count), Guild (online count), Durability, Copy Chat, Voice/Channels (Social > Chat tab), Settings, Scroll to Bottom (pulses while not at the bottom). Visibility Always / Mouseover / Never, left or right, width, separate with spacing, icon size / spacing / color, Free Move Icons (Shift + drag), icon order (cog on Sidebar Icons).
- **Input box**: height, font and size, Input on Top; Up / Down recall your sent lines without Alt.
- **Text**: Timestamps (formats or Blizzard's setting) and Timestamp All Messages, Shortened Channel Names ([P], [PL], [G], [O], [R], [RL], [I], world channels by number or letters Ge / T / LD / WD / LFG), Class Colored Names (group members in Say / Yell / Party / Raid text), clickable URLs (copy popup), Copy Chat popup (last 500 lines of the window), Remember Last Chat Lines (per character, `EllesmereUIChatScrollDB`, not inside instances), link tooltips on hover (off with Hide Tooltip on Hover), Whisper Sound (EllesmereUI sounds and SharedMedia; "None" also silences Blizzard's).
- **First run**: a new `EllesmereUIChatDB` gets the retail "Naowh" chat settings (no background or borders, no sidebar, idle fade to fully hidden after 30 s, font size 18, outline, tab font 14, ...). Reset Chat goes to the EllesmereUI defaults.
- **Not in 5.4.8, left out**: Blizzard / Classic / WoW Forever styles, textured border styles, M+ Portals, Chat Bubbles link, BNet toast mover. Font changes apply live (no reload).
- ElvUI: if ElvUI's chat is on for a character, EllesmereUI Chat stays off there (chat hint). Turn off ElvUI > Chat > Enable.
- Saved settings: `EllesmereUIChatDB.profile.chat` (same keys as the EllesmereUI profile).

## Damage Meters

`EllesmereUIDamageMeters` is a separate, toggleable addon with its own entry under `/eui` > UI Reskin Addons > Damage Meters. It records the combat log itself (`EllesmereUIDamageMeters_Engine.lua`); no Details! or other meter addon is needed.

- **Damage Meters tab:** damage/DPS, healing/HPS (pets, guardians and shield absorbs included), damage taken, enemy damage taken, interrupts, dispels, and death recaps. Click a bar for its breakdown; right-click for the home screen. The segment menu selects Current, Overall, or any stored fight. Windows, timers, fonts, textures, keybinds, and Unlock Mode remain independently configurable.
- **Apply Modern Look:** an opt-in modern style: flat class-colored bars, compact dark headers, class/spec icons, rank, total, and rate. It keeps window positions, sizes, selected meters, bookmarks, and Spell History.
- **Combat Data tab:** effective or activity DPS/HPS time, number of stored fights, Reset Data, and Overall resets for a new raid boss / Challenge Mode.
- Fights are kept for the session only (cleared by a reload or logout). Reset Data is blocked during combat. Spec icons show for you and for group members another addon has inspected; others show their class icon.

Developer regression check (Lua 5.1, from the repository root): `lua EllesmereUIDamageMeters/tests/Engine.lua`. It feeds mock combat log events to the engine and does not read or write a game installation.

## Notes

- The Interrupt Tracker does not depend on `ExRT`.
- If you still use `ExRT` and have its interrupt bars enabled, you will see duplicates until one of them is disabled.

## Media

- `EllesmereUI/media/Expressway.ttf` is the font of the settings window and the modules (copied from EllesmereUI). If it is missing, Arial Narrow is used.
- `EllesmereUI/media/ui/*.tga` is the settings window art and icons, converted from EllesmereUI's PNG files (32-bit TGA, power-of-two sizes). The window picture is cut into 9 tiles. This art belongs to EllesmereUI: fine for personal use, do not publish it.
- `EllesmereUIUnitFrames/media/` is the unit frame art from EllesmereUI (bar textures, absorb styles, class art at 512 x 512, combat and leader icons, elite badge, portrait ring), converted to uncompressed 32-bit TGA with power-of-two sizes.
- `EllesmereUIBlizzardSkin/media/charsheet/*.tga` is the character sheet art, converted the same way: `sheet-bg` (the shown part of `modern_blizz.png`), `character-bg` (model background), arrow, eye and close icons (30 x 30 in 32 x 32).

## Addons

| Addon | What | Saved settings |
|---|---|---|
| `EllesmereUI` | Core: shared table `EllesmereUI`, `/eui`, Interface Options page, font/texture lists, Global Settings UI Scale, art and font | `EllesmereUIDB` (UI scale, Window Scale, window position, color picker colors) |
| `EllesmereUIOptions` | Settings window, load on demand (loaded by `/eui`). One `EUI_*_Options.lua` page file per module; pages of disabled modules are not shown | - |
| `EllesmereUIActionBars` | Action Bars (retail EllesmereUI Action Bars) | `EllesmereUIActionBarsDB` |
| `EllesmereUIUnitFrames` | Unit Frames | `EllesmereUIUnitFramesDB` |
| `EllesmereUIQoL` | Quality of Life: skip cinematics, auto gossip | `EllesmereUIQoLDB` |
| `EllesmereUIQuestTracker` | Quest Tracker: auto accept / turn in | `EllesmereUIQuestTrackerDB` |
| `EllesmereUIBlizzardSkin` | Blizzard Skins: Character Sheet | `EllesmereUIBlizzardSkinDB.charSheet` |
| `EllesmereUIDamageMeters` | Damage Meters (built-in combat engine), Spell History | `EllesmereUIDamageMetersDB.dm`, `.spellHistory` |
| `EllesmereUIInterruptTracker` | Interrupt Tracker (not a retail module) | `EllesmereUIInterruptTrackerDB` |
| `EllesmereUIBags` | Bags and bank (retail EllesmereUI Bags) | `EllesmereUIBagsDB` |
| `EllesmereUIMinimap` | Minimap (retail EllesmereUI Minimap) | `EllesmereUIMinimapDB` |
| `EllesmereUIChat` | Chat (retail EllesmereUI Chat) | `EllesmereUIChatDB`, per character `EllesmereUIChatScrollDB` |

- Before 3.1 all modules saved into `EllesmereUIDB.<key>`. At the first login with 3.1 each module moves its old table into its own saved variable (`ns.ModuleDB` in `EllesmereUI.lua`). A disabled module keeps its old data until it is enabled.
- A module file starts with `local ns = EllesmereUI`. Modules add their apply function to `ns.applyHooks` and their movers to `ns.unlockElements`; the settings window reads both.
- A new module needs its own folder and `.toc` (`## Dependencies: EllesmereUI`) and an `EUI_<Name>_Options.lua` in `EllesmereUIOptions` that calls `ns.RegisterSettingsModule` (listed in that `.toc` in sidebar order).
- New addon folders or files are only seen after a game restart (a `/reload` is not enough).
- Color picker: the EllesmereUI popup (color square, hue and alpha bars, New / Prev, Hex#, Opacity, Favorites and Recent Colors, saved in `EllesmereUIDB.colorPicker`), not Blizzard's ColorPickerFrame. Changes show live; Cancel, X, Escape or a click outside put the old color back. Right-click a recent color to make it a favorite.
