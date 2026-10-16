-- Settings page of QoL Addons > Reforge (ReforgeLite moved into EllesmereUI).
-- Part of EllesmereUIOptions (load on demand); skipped when EllesmereUIReforge is not loaded.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIReforge") then
	return
end

local function DB()
	return ns.GetReforgeDB()
end

local REFORGE_PAGES = {
	{
		key = "reforge",
		name = "Reforge",
		description = "Finds the best reforge for your stat weights and caps (ReforgeLite). Open it with /reforge or at a reforger.",
		build = function(p)
			p:Section("General")
			p:Toggle("Open Window When Reforging", "Opens the Reforge window when you talk to a reforging NPC, and closes it when you leave.",
				function() return DB().openOnReforge end, function(v) DB().openOnReforge = v and true or false end)
			p:Button("Reforge Window", "Opens or closes the Reforge window (same as /reforge).", "Open / Close", function()
				ns.ToggleReforgeWindow()
			end)

			p:Section("Window")
			p:Button("Window Position", "Puts the Reforge and Result windows back in the middle of the screen, at the default size.", "Reset Position", function()
				ns.ResetReforgeWindow()
			end)
			p:Button("Debug Data", "Shows the data of the last calculation, to copy it for a bug report.", "Show Data", function()
				ns.ShowReforgeDebug()
			end)
		end,
	},
}

ns.RegisterSettingsModule({
	key = "reforge",
	name = "Reforge",
	group = "QoL Addons",
	tabs = REFORGE_PAGES,
	reset = function() ns.ResetReforgeSettings() end,
	resetTip = "Set the Reforge settings back to default. Stat weights, caps and presets are kept.",
})
