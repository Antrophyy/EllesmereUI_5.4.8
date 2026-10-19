# Upstream sync ledger

Upstream: https://github.com/EllesmereGaming/EllesmereUI (retail). This repo forked it at `c436c600` (v9.5.5).

**Reviewed through:** `58e738ff` (v9.6.2, 2026-10-19). The next sync reviews `58e738ff..upstream/main`.

## How a sync runs

1. `git fetch https://github.com/EllesmereGaming/EllesmereUI main:refs/remotes/upstream/main`, then list `git log --no-merges <reviewed>..upstream/main`. Never merge or cherry-pick: the code shares almost no text with upstream, so every change is ported by hand.
2. Triage each commit as **adapt** (port to 5.4.8 APIs), **skip** (with a reason) or **later**. Release commits carry real changes; read the What's New notes in `EllesmereUIOptions/EUI__General_Options.lua` to find them.
3. The owner strikes anything they don't want. Ports are written to the AddOns folder uncommitted, tested in game, then committed to main one feature at a time with an `Upstream: <sha>` trailer.
4. Update the verdicts below and move **Reviewed through** forward. Finish with `git merge -s ours upstream/main` (records the reviewed upstream commits as merged without changing any file, so GitHub shows 0 behind), all in the same push.

## Sync 1: `c436c600..58e738ff` (227 commits, v9.5.5 to v9.6.2)

Size: S small, M medium, L large.

### Adapt

| # | Change | Area | Size | Upstream commits | Status |
|---|---|---|---|---|---|
| A1 | Merchant Bulk Buy (shift-click to buy any amount) (MoP has BuyMerchantItem/GetMerchantItemMaxStack) | Blizzard Skins+ | M | `2b67ef8a` | ported |
| A2 | Also Show Below N seconds for Show When Missing buffs | Cooldown Manager | S | `aee0936b` `2c7c28c6` `8ad495b0` | ported |
| A3 | Textured Background (bar backgrounds use the bar texture) (Resource Bars part is inside the 9.6 release commit) | Unit Frames, Nameplates, Resource Bars | M | `b8f827b0` `da3147c4` `95316fae` | ported (UF health background already used the bar texture) |
| A4 | Cast bar Uninterruptible Color override (in the 9.6.1 release commit) | Resource Bars | S | `5702f938` | ported |
| A5 | Cast bar pushback shows added time; cast icon no longer covers portrait border | Unit Frames | S | `5702f938` `d8704bb4` | ported |
| A6 | Action Bars: Attack / Shoot / Auto Shot and pet Attack flash fixes | Action Bars | S | `3d49c22a` `0afcdc19` `bbedb352` | not needed (already fine on 5.4.8) |
| A7 | Character Sheet model/text above the inset; Equipment Manager popup skin (GearManagerDialogPopup on 5.4.8) | Blizzard Skins+ | S | `bd2c672d` `3b7af73d` `1c6f432e` `ccb0e581` | ported |
| A8 | Minimap: flyout addon buttons going dark; re-apply after free move drag | Minimap | S | `3860733b` `324fc4b2` | ported |
| A9 | Options: dropdown subnav flyouts overlapping; nameplate preview spacing | Options | S | `e75bf13f` `a1779584` | not needed (already fine on 5.4.8) |
| A10 | Cooldown Manager: frames above action bars drift up in combat | Cooldown Manager | S | `c6e9fd54` | not needed (already fine on 5.4.8) |
| A11 | Cooldown Manager: remove/reorder spells while editing an override (only if our CDM overrides match) | Cooldown Manager | M | `1224550d` | not needed (already fine on 5.4.8) |
| A12 | Moonkin Form per-form hide for the class resource (Eclipse) bar | Resource Bars | S | `d3fcfac7` | ported |
| A13 | Movement Alert: plays chosen sound; no false ready after a form change | QoL | S | `5702f938` `033c7b1d` | ported |
| A14 | Swing Timer spark width, overhang and per-weapon colors | Resource Bars | S | `5857a480` | ported |
| A15 | Interruptible While Kick Ready (important casts) | Nameplates | S | `95316fae` | not needed (already fine on 5.4.8) |
| A16 | Dispel Glow styles (pandemic half does not apply on MoP) | Nameplates | M | `95316fae` | ported |
| A17 | Bags: Item Level Never / Default / Custom Colored | Bags | S | `95316fae` | ported |
| A18 | Hide Power Bar under Blizzard / Classic looks | Unit Frames | M | `95316fae` | not needed (no Blizzard / Classic looks on our Unit Frames) |
| A19 | Resource Bars page previews power and health bars | Options | S | `f469f214` | ported |
| A20 | Unit Frames: raid marker shows at once; absorb text clears; ToT power bar vs portrait ring | Unit Frames | S | `95316fae` `5d444d44` | not needed (marker and absorb text already update; no Blizzard Style look) |
| A21 | Important buffs on cursor only in combat (talent reminder parts skipped) | AuraBuff Reminders | S | `58e738ff` | ported |
| A22 | Conditional overrides: Party condition | Profiles / Overrides | S | `033c7b1d` | ported |
| A23 | Quest Tracker sorting, filters, auto-track, progress colors and alerts, header filter button (built for WoW Forever's classic quest log, close to MoP's) | Quest Tracker | L | `bd9ca2ad` `c6e77f11` `06d2b308` `e8dbfff6` `98ddb34f` `202e3a0d` `cf792145` `9d541c8f` | later |
| A24 | Raid Frames Buff Manager: Raid/Party preview, override list, Show In preview | Raid Frames | L | `05b9ecae` `4914bc3e` `e653b111` `e2b44065` `a8c6b86f` `ef2fe3d6` | ported (Raid / Party preview switch; no override list, our Buff Manager has no per-override copies) |
| A25 | Rename Raid Frames to Raid & Party Frames in the UI (cosmetic, your call) | Raid Frames | S | `ec37aefa` | ported |
| A26 | Hide Banners and Toasts (MoP has level-up and alert toasts, no boss banner) | QoL | M | `95316fae` | skipped (owner's call) |
| A27 | Combat-time CPU and freeze fixes spread through the release commits (needs profiling against our code, not a straight port) | General | L | `95316fae` `ccb0e581` `033c7b1d` `5702f938` `5d444d44` | ported the bag search pause; the rest targets retail-only aura code |

### Skip

<details><summary>Locales (the port ships no locale addon): 77 commits</summary>

- `d2be8e79` locale
- `c0a70f96` locale keys
- `e3011462` esES: block 1, common labels (474 strings) by alvaro1929
- `59033693` esES: block 2, section headers (298 strings) by alvaro1929
- `0b430776` esES: block 3, core options (667 strings) by alvaro1929
- `c4f305eb` esES: block 3 macro labels and consumables (official names from the game client)
- `05f66291` esES: block 4, action bars (178 strings) by alvaro1929
- `7677232d` esES: block 5, nameplates (304 strings) by alvaro1929
- `137426d7` Regenerate locale keys after merging main
- `e07b1f58` add new German Locals, better Translations
- `dd14076b` ptBR: Forever Essentials active stance, classic windows and gold tracker, swing timer options, alert toast and banner hiding, and textured bar backgrounds
- `e92b294e` esES: unit frames (block 6) and official spell names
- `ccac7ca8` add more German Localstrings
- `a9ff8094` Regenerate the locale key list
- `b686c1e1` Update _keys.txt
- `8efc7925` more Germanlocals
- `3cca370f` Regenerate the locale key list
- `ea0706d8` more german localstrings
- `cda7fb06` esES: official spell names for cast bar preview
- `b0054972` esES: raid frames (block 7)
- `7f194ef5` esES: cooldown manager (block 8)
- `20a309db` Regenerate the locale key list
- `19dc3ca2` esES: quality of life (block 9)
- `914ec849` esES: resource bars (block 10)
- `9b5effe1` Update deDE.lua
- `12231f4c` esES: aura buff reminders (block 11) and official names
- `0b6cf443` esES: official PvP zone and item names
- `f1a13f19` Regenerate the locale key list
- `d5fe04d6` esES: Blizzard skin (block 12)
- `f3917cff` esES: bags and minimap (block 13)
- `eb191a2a` esES: damage meters and mythic+ timer (block 14)
- `bf6d8c90` esES: mythic+ affix names
- `0af04659` esES: Quickdraw and loadout manager (block 15)
- `d28f25f1` Regenerate the locale key list
- `e160fbac` esES: overrides, profiles, chat, friends, quest tracker (block 16)
- `c4b2ab79` esES: glow templates and misc (block 17)
- `3f93d20c` Regenerate the locale key list
- `5aafe6ef` esES: WoW Forever reagent names
- `cf2f4a3e` esES: data bars (block 18)
- `486aadc7` ptBR: Forever Essentials fishing and pet summon, swing timer attack state and movement guide, Group Finder options, merchant bulk buy, pandemic borders and low bag-space visibility
- `2a902034` esES: options and code labels (block 19)
- `90045936` esES: shared options (block 20)
- `fe31ab8e` esES: misc strings (block 21)
- `70c52ec2` esES: numbered labels (Damage Meter 1-5, Group 2-8...)
- `ff0e20b7` esES: shorter labels so they fit like the English ones
- `7e6d94ef` esES: shorter page tabs so they don't overlap the search bar
- `46d10b15` esES: assembled strings, part 1 (block 23)
- `8f2611cc` Locale keys: regenerate _keys.txt
- `18a11192` esES: shorter Blizzard Skins tabs
- `aa37b847` esES: shorter tab label overrides
- `8434ebe8` esES: assembled strings, part 2 (block 25)
- `3d2f7066` esES: assembled strings, part 3 (block 26)
- `252498aa` esES: assembled strings, part 4 (block 27)
- `f704e661` esES: fix \r in two keys (block 27)
- `26477626` esES: assembled strings, part 5 (block 28)
- `bbbbd8bf` esES: final review pass (natural wording for 'automatically')
- `2a5a74d5` Translate new features (Group Finder, Bulk Buy, Fishing, Pet Summon, Swing Timer, CDM)
- `91e179ff` Unify crosshair terminology in koKR localization
- `8eac62df` Translate Quest Tracker sorting, filtering, and progress colors in koKR
- `3dc784c6` Translate Swing Timer spark options in koKR
- `c5c26fde` Translate Forever Essentials map markers and gathering skill in koKR
- `e663eb40` add more German Localsstrings
- `ed487135` Update deDE.lua
- `22a2fdd3` add more new German Localstrings, wording fixes
- `84268a6b` esES: 247 frases nuevas de la 9.6 (buscador de grupos, Forever, pesca, misiones)
- `0967227b` esES: nombres oficiales de los hechizos del buscador de grupos
- `befd7494` esES: 390 textos visibles que no tenía ningún idioma (editor de macros de Forever, chatarra, mapa…)
- `6cd69316` ptBR: Group Finder filters and listing options, quest tracker sorting and filtering, world map markers, gathering skill tooltips, bulk buy, swing timer and nameplate options
- `8fadd4ec` zhTW: translate 349 new keys, Group Finder and Forever features
- `77fc5013` koKR: add translations for new features and options
- `ec4a0d5e` Translate new features and options in koKR locale
- `b28e09c2` koKR: add translations for Raid Frames preview switch and kit overrides
- `0c1d70ff` locales tool ran
- `e74a25af` ptBR: Raid Frames Buff Manager preview notes, Unit Frames textured background requirements, quest tracker header toggle and sounds, Group Finder keystone level
- `ca5234ed` added more new German Localstrings
- `fdecd04f` add more Localstrings
- `aa112af6` Regenerate the locale key list

</details>

<details><summary>File split / restructure (our files are laid out differently): 48 commits</summary>

- `290aded4` Move the Tracking Bars code into nine new files (verbatim)
- `6d9971d6` Wire the Tracking Bars files through ns._buffBarInternals
- `e921b81f` Point the Tracking Bars wake test at the file that holds the sleeper
- `92819870` Point comments at the files the Tracking Bars split moved their code to
- `ac766cd0` Move the Chat code into eight new files (verbatim)
- `27c83e3f` Wire the Chat files through ns._internals
- `ed2e7da2` Move the Minimap code into nine new files (verbatim)
- `52dfe3a5` Wire the Minimap files through ns._internals
- `a9ffc3df` Point three outside comments at the new Minimap files
- `ccfa55b0` Minimap split: mark the moved zone text REGEN listener as allowed
- `ce5294c9` Move the Damage Meters code into eight new files (verbatim)
- `200b5275` Wire the Damage Meters files through ns._dmInternals
- `d30759c0` Point two Damage Meters comments at the files the split moved their code to
- `cef44705` Move the AuraBuff Reminders code into ten new files (verbatim)
- `d2e5a1a0` Wire the AuraBuff Reminders files through ns._abrInternals
- `da51a504` Allow the moved GetSpecializationInfo line in the guardrails check
- `39a12dd9` Move the Spec Overrides code into eight new files (verbatim)
- `cfa387c3` Wire the Spec Overrides files through EUI_NS._soInternals
- `deb01db4` Spec Overrides split: mark the moved combat-end registration as allowed
- `8653c521` Move the Bags code into nine new files (verbatim)
- `f18cb651` Wire the Bags files through ns._bagsInternals
- `f7e4c0ed` Point four Bags comments at the files the split moved their code to
- `9f558d85` Mark the moved PLAYER_REGEN_ENABLED registration for the guardrails check
- `40f4575b` Move the Resource Bars code into twelve new files (verbatim)
- `b826264d` Wire the Resource Bars files through ns._internals
- `b45d8886` Drop the alias locals EllesmereUIResourceBars.lua no longer reads
- `43a11a74` Move the rest of the Action Bars main file into fourteen new files (verbatim)
- `ec2752b9` Wire the Action Bars main-file parts through ns._internals
- `3a8fa8f6` Action Bars split: drop the 200-local remarks from the comments
- `87685a1e` Action Bars split: mark the moved combat-end registrations for the guardrails check
- `c0b41fbe` Move the Raid Frames preview code into eight new files (verbatim)
- `a183d92f` Wire the Raid Frames preview files through ns._previewInternals
- `f24c29db` Raid Frames preview split: name the file that holds ShowPartyPreview
- `25bc160d` Raid Frames preview: import the chain's names from ns._internals in each file
- `7fe39c20` Raid Frames preview: register db, PP and containerFrame with ns._internals, drop ns._PreviewBind
- `4a9931e2` Raid Frames preview: pass the party role and class tables to ApplyPreviewData
- `6e492faf` Raid Frames preview: fade the overlay out through ns._overlayContainer
- `330b408f` Raid Frames preview: create previewFrames and previewClassTokens once
- `2d8344cb` Raid Frames size preview: call ns.HidePartyPreview
- `1c63fd61` Raid Frames party preview: put the raid health and power values back
- `e5a65099` Move the Player Aura Bars code into eight new files (verbatim)
- `7c6b6fac` Wire the Player Aura Bars files through ns._pabInternals
- `20e74e62` Player Aura Bars split: point comments at the file that holds the code
- `56ece0eb` Player Aura Bars split: keep the two function assignments as they were
- `ab5aa334` Move the Blizzard Skin code into five new files (verbatim)
- `47064f59` Wire the Blizzard Skin files through ns._internals
- `07e31c2a` Blizzard Skin split: point four comments at the files that hold the code
- `42332dbb` Blizzard Skin split: review follow-ups

</details>

<details><summary>Group Finder (retail Premade Groups API): 29 commits</summary>

- `1faa8735` feat(groupfinder): add Group Finder module
- `96e1ab50` feat(groupfinder): confirm the reload when switching the module on or off
- `5deeabdd` feat(groupfinder): cannot be turned on while Premade Groups Filter is loaded (note beside the toggle)
- `0ce171c2` feat(groupfinder): Cancel on the reload confirm puts the Enable toggle back
- `b24c593e` feat(groupfinder): N/A on an empty applications bar; Members in Tooltip merged into the Group Settings menu; Raider.IO colours follow Colored Group Names
- `13e41ee1` feat(groupfinder): Role Icon Size and applicant columns in the Group Settings menu; Bar Texture under Applications
- `6e331d0a` feat(groupfinder): boxed Role Icon Size buttons; Score & Progress Columns label
- `61cff728` feat(groupfinder): Dungeons & Raids bottom tabs flush left
- `f1e4fa52` fix(groupfinder): applications bar counts each application once, in its own category
- `8ee4afaa` feat(groupfinder): applicant Progress column removed; Invite / Decline as glyph buttons
- `af1a2ef3` fix(groupfinder): applicant Score hidden once the application has an outcome; left-aligned
- `24b29603` feat(groupfinder): switches itself off at login when Premade Groups Filter is loaded
- `df8f2a72` chore(groupfinder): brief comments; plain tooltips through ShowWidgetTooltip
- `78b7b5b0` chore(groupfinder): addon list description
- `ad614ffc` feat(groupfinder): hover summaries for the Group Settings options
- `e98d400e` feat(groupfinder): hover summaries for the Filters menu's Misc options
- `74acd15f` feat(groupfinder): SharedMedia textures for the applications bar
- `0c494bd8` feat(groupfinder): Bloodlust / Battle Res filter tooltips list the counted spells
- `6ab07190` feat(groupfinder): class-coloured spells in the Bloodlust / Battle Res tooltips
- `2fc9f961` feat(groupfinder): review round
- `2f2c1a1c` feat(groupfinder): Dungeon Names switch (short names on the dungeon squares); newer Premade Groups rail art
- `94662721` fix(groupfinder): dungeon/arena tooltips add only the names (Blizzard lists roles and classes); Quick Sign Up row matches QoL's double-click
- `0900a411` fix(groupfinder): rewards table re-placed once the names are measured
- `7fb453e5` feat(groupfinder): filtered-out rows faded like the list behind the Filters menu
- `5294e1b0` chore(groupfinder): shorter comments
- `f03e1293` fix(groupfinder): Raids button glyph on a clear background
- `660599e7` Feat: add an optional keystone level to dungeon squares
- `ec8a7817` fix(groupfinder): leaver icon drawn above the spec/class icon layer
- `0aa42fcc` Group Finder: apply the locale dungeon abbreviation override to square names

</details>

<details><summary>WoW Forever only: 12 commits</summary>

- `5e75fa1b` Forever Essentials: Most Valuable Reward
- `d271f255` Forever Essentials: Map Markers
- `351068a2` Forever Essentials: Fishing Key, Double-Click to Cast, Bobber Indicator, Fishing Sounds
- `21ad6241` Forever Essentials: Show Zone Levels on the world map
- `98205a22` Forever Essentials: Auto Summon Pet, Favorites per Character
- `971abcd6` Forever Essentials: Map Markers, right-click opens the map a transport or an exit leads to
- `68b53a7d` Add optional low bag-space visibility for junk items
- `c26ed95b` Map Markers: drop the right-click navigation, pass right clicks through once per pin out of combat
- `6f93295c` Forever Essentials: Gathering Skill in Tooltips
- `cb427318` AuraBuff Reminders: WoW Forever spell groups (one reminder while none is active)
- `2230a919` AuraBuff Reminders options: WoW Forever spell group sections
- `18ddaecf` feat(resourcebars): Swing Timer follows the Resource Bars style on WoW Forever

</details>

<details><summary>Swing Timer aim / movement (Auto Shot works while moving on MoP): 6 commits</summary>

- `a48441ad` Swing Timer: rename Show Shot Pending to Show Attack Pending
- `fc4c83b8` Swing Timer: Auto Shot aim time and Show Aim Window
- `ac5b4114` Swing Timer: Aim Window dropdown with a Wind-Up Bar mode
- `063b1e2e` Swing Timer: Attack State and Movement Guide
- `bfb1079a` Swing Timer: Auto Shot's aim runs inside its swing
- `3125e9fa` Swing Timer: drop the unshipped Aim Window from the migration

</details>

<details><summary>Pandemic (no pandemic mechanic on MoP): 3 commits</summary>

- `e2ffdf42` feat(raidframes): add per-indicator pandemic borders
- `a3a9f2b8` fix(raidframes): allocate pandemic regions only for opted-in displays
- `71edee27` fix: preserve pandemic registration when restyling buff icons

</details>

<details><summary>Dead-code cleanup in code we lay out differently: 2 commits</summary>

- `b1fd7e48` Minimap: remove code nothing calls
- `e1cfde7d` Action Bars: remove the state-page read that never ran from the page cycling

</details>

<details><summary>Talking Head (not in MoP): 2 commits</summary>

- `d46a6568` Talking Head: add option to mute sound lines too Hide Talking Head: more robust hiding mechanic
- `fc64aff0` Hide the head of the talking head too!

</details>

<details><summary>Balance Astral Power / always-mana (retail druid forms): 2 commits</summary>

- `92aef1c3` Power Bar update for new Balance druid option
- `7ac9150d` Unitframe Power Balance New Option

</details>

<details><summary>Damage Meters (we run our own engine): 1 commits</summary>

- `b334d877` Damage Meters: drop the unused DM_TYPES table, clear the regen stamp on the group pre-warm

</details>

<details><summary>Micro-optimisation in restructured code: 1 commits</summary>

- `90418855` Resource Bars: hand the primary power type on only when it changed

</details>

<details><summary>Honor levels (not in MoP): 1 commits</summary>

- `0d2291fd` fix(factions): draw the honor badge on the Honor Portrait faction indicator

</details>

