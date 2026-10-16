-- Settings page of Friends List (retail EUI_Friends_Options.lua, page
-- "Friends"). Part of EllesmereUIOptions (load on demand); skipped when
-- EllesmereUIFriends is not loaded. Setters only store: the runtime's
-- ns.applyHooks entry repaints the list.
-- Not on this page (no 5.4.8 counterpart): Show Region Icons.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIFriends") then
	return
end

local FRM = ns.Friends

local function F()
	return FRM.DB()
end

local CHROME_BORDER_TIP = "The Friends List window skin draws this border (Blizzard Skins+ > Window Skins)."

local function IconItems()
	local items = {}
	for _, key in ipairs(FRM.ICON_STYLE_ORDER) do
		items[#items + 1] = { name = FRM.ICON_STYLE_VALUES[key], value = key }
	end
	return items
end

local PAGES = {
	{
		key = "friends",
		name = "Friends",
		description = "Custom friends list with groups, notes, and realm grouping.",
		build = function(p)
			local shell = FRM.ChromeShell
			local function borderOff()
				return shell() or (F().borderSize or 0) == 0
			end

			p:Section("DISPLAY")

			-- Class Icon Theme | Class Color Names
			p:Dropdown("Class Icon Theme", nil,
				IconItems,
				function() return F().iconStyle or "modern" end,
				function() return FRM.ICON_STYLE_VALUES[F().iconStyle or "modern"] or "Modern" end,
				function(v) F().iconStyle = v end)
			p:Toggle("Class Color Names", nil,
				function() return F().classColorNames end,
				function(v) F().classColorNames = v end)

			-- Border Size | Border Color
			p:Slider("Border Size",
				shell() and CHROME_BORDER_TIP or nil,
				0, 4, 1,
				function() return F().borderSize or 0 end,
				function(v) F().borderSize = v end,
				shell)
			p:Label("Border Color",
				shell() and CHROME_BORDER_TIP or "Set Border Size above 0",
				borderOff)
			p:Swatch("Accent Colored",
				function() return ns.ResolveAccent() end,
				function() end,
				{
					readonly = true,
					active = function() return F().useClassColor == true end,
					onClick = function()
						F().useClassColor = true
						return true
					end,
					disabled = borderOff,
				})
			p:Swatch("Custom Color",
				function()
					local c = F()
					return c.borderR or 0.05, c.borderG or 0.05, c.borderB or 0.05
				end,
				function(r, g, b)
					local c = F()
					c.borderR, c.borderG, c.borderB = r, g, b
				end,
				{
					active = function() return not F().useClassColor end,
					onClick = function()
						local c = F()
						if c.useClassColor then
							c.useClassColor = false
							return true
						end
					end,
					disabled = borderOff,
				})

			-- Enable Accent Colors | Enable Faction Banners
			p:Toggle("Enable Accent Colors",
				"Accent colored labels on the friends window buttons. Needs the Friends List window skin (Blizzard Skins+ > Window Skins).",
				function() return F().accentColors ~= false end,
				function(v) F().accentColors = v end,
				function() return not shell() end)
			p:Toggle("Enable Faction Banners", nil,
				function() return F().factionBanners ~= false end,
				function(v) F().factionBanners = v end)

			-- Auto-Accept Friend Invites (+ guildmates cog)
			p:Toggle("Auto-Accept Friend Invites", "Auto-accepts all group invites from people on your friends list",
				function() return F().autoAcceptFriendInvites end,
				function(v) F().autoAcceptFriendInvites = v end)
			p:Cog("Auto Accept Settings", {
				{ type = "toggle", label = "Accept Invites from Guildmates",
				  get = function() return F().autoAcceptGuildInvites end,
				  set = function(v) F().autoAcceptGuildInvites = v end },
			}, {
				disabled = function() return not F().autoAcceptFriendInvites end,
				disabledTip = "Auto-Accept Friend Invites",
			})
		end,
	},
}

ns.RegisterSettingsModule({
	key = "friends",
	name = "Friends List",
	group = "UI Reskin Addons",
	tabs = PAGES,
	reset = function() FRM.Reset() end,
	resetTip = "Set all Friends List settings back to default.",
})
