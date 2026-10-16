-- Settings for Quality of Life > Shifter (retail EUI_QoL_Shifter_Options.lua).
-- Tab builder only: EUI_QoL_Options.lua adds the tab. All keys live in the
-- EllesmereUIDB root, like retail. Setters only store; the runtime follows
-- them through ns.applyHooks.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIQoL") then
	return
end

local function DB()
	if type(EllesmereUIDB) ~= "table" then EllesmereUIDB = {} end
	return EllesmereUIDB
end

-- "CharacterFrame" -> "Character", "PetJournalParent" -> "Pet Journal Parent"
local function PrettifyName(name)
	local pretty = name:gsub("Frame$", "")
	pretty = pretty:gsub("(%l)(%u)", "%1 %2"):gsub("(%u)(%u%l)", "%1 %2")
	return pretty
end

local function SavedWindows()
	local items, seen = {}, {}
	local function collect(tbl)
		if type(tbl) ~= "table" then return end
		for name in pairs(tbl) do
			if not seen[name] then
				seen[name] = true
				items[#items + 1] = { value = name, name = PrettifyName(name) }
			end
		end
	end
	collect(DB().shifterPositions)
	collect(DB().shifterScales)
	table.sort(items, function(a, b) return a.name < b.name end)
	if #items == 0 then
		items[1] = { value = "", name = "No saved windows" }
	end
	return items
end

ns.QoLO_BuildShifterPage = function(p)
	p:Paragraph("Shift + Left-Click Drag to permanently save a panel's position.\nCtrl + Left-Click Drag for a temporary move that resets when the panel closes.\nShift + Scroll to permanently zoom a panel. Ctrl + Scroll for a temporary zoom.")

	p:WideButton(function() return "Reset All Positions & Zoom" end,
		"Resets all saved panel positions and zoom levels and reloads your UI.",
		function() return false end,
		function()
			ns.ShowConfirmPopup({
				title = "Reset Shifter Positions & Zoom",
				message = "This will reset all saved panel positions and zoom levels and reload your UI.",
				confirmText = "Reset",
				cancelText = "Cancel",
				reload = true,
				onConfirm = function()
					if ns._ResetShifterPositions then ns._ResetShifterPositions() end
				end,
			})
		end)

	p:Section("Shifter")
	p:Toggle("Enable Shifter", "Lets you move and zoom Blizzard windows (Character, Spellbook, Talents, Bags, Auction House, ...) with Shift or Ctrl held.",
		function() return DB().shifterEnabled and true or false end,
		function(v) DB().shifterEnabled = v end)
	p:Dropdown("Reset Specific Window", "Puts one window back to its default position and zoom and reloads your UI.",
		SavedWindows,
		function() return "" end,
		function() return "Choose Window..." end,
		function(frameName)
			if not frameName or frameName == "" then return end
			ns.ShowConfirmPopup({
				title = "Reset Window Position & Zoom",
				message = "Reset " .. PrettifyName(frameName) .. " to its default position and zoom and reload your UI?",
				confirmText = "Reset",
				cancelText = "Cancel",
				reload = true,
				onConfirm = function()
					local db = DB()
					if db.shifterPositions then db.shifterPositions[frameName] = nil end
					if db.shifterScales then db.shifterScales[frameName] = nil end
				end,
			})
		end)
	p:Toggle("Move Windows Without Shift", "When enabled, left-click dragging a window will save its position without needing to hold Shift. Ctrl+drag still does a temporary move.",
		function() return DB().shifterNoShift and true or false end,
		function(v) DB().shifterNoShift = v end)

	p:Section("Loot Windows")
	p:Toggle("Move Loot Windows in Unlock Mode", "Adds Bonus Roll, Group Loot, and Alert Toast movers to Unlock Mode.",
		function() return DB().shifterLootUnlock and true or false end,
		function(v) DB().shifterLootUnlock = v end)

	local function topBarUnlockOff() return not DB().shifterTopBarUnlock end
	p:Section("Blizzard Top Bar Event Text")
	p:Toggle("Move Top Bar Event Text in Unlock Mode", "Adds a mover for Blizzard's top-center event text (battleground scores, world PvP and event status).",
		function() return DB().shifterTopBarUnlock and true or false end,
		function(v) DB().shifterTopBarUnlock = v end)
	p:Toggle("Hide Unlock Mode Overlay", "Hides the Top Bar Event Text mover in Unlock Mode while keeping its saved position applied.",
		function() return DB().shifterTopBarHideOverlay and true or false end,
		function(v) DB().shifterTopBarHideOverlay = v end, topBarUnlockOff)
end
