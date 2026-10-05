-- Cursor Finder — its own buttons to open it: a round button on the minimap's rim — a click opens the window, a right-click turns the ring on or off, dragged it goes round the map —
-- and a page in the game's own settings (Options → AddOns → Cursor Finder) with the same button and the switch for
-- the minimap one.
local ADDON, ns = ...
local W = ns.W

local Launcher = {}
ns.Launcher = Launcher

local ICON = [[Interface\Icons\INV_Misc_Spyglass_03]]

local function own()
	if not ns.db then return {} end
	ns.db.minimap = type(ns.db.minimap) == "table" and ns.db.minimap or {}
	return ns.db.minimap
end

function Launcher:Shown() return own().hide ~= true end

function Launcher:SetShown(on)
	own().hide = not on
	if self.button then self.button:SetShown(on and true or false) end
	if self.check then self.check:SetChecked(on and true or false) end
end

-- ---------------------------------------------------------------------------------- the minimap button
-- its place on the rim: an angle round the minimap's middle (degrees, 0 = right, counter-clockwise)
local function place(button)
	local angle = math.rad(tonumber(own().angle) or 160)
	local radius = Minimap:GetWidth() / 2 + 6
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function tooltip(button)
	GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	GameTooltip:SetText("Cursor Finder", W.GOLD[1], W.GOLD[2], W.GOLD[3])
	GameTooltip:AddLine("Click: the window", 1, 1, 1)
	GameTooltip:AddLine("Right-click: the ring round the cursor on or off", 1, 1, 1)
	GameTooltip:AddLine("Drag: move round the minimap", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function BuildButton()
	if Launcher.button or not Minimap then return end
	local button = CreateFrame("Button", "CursorFinderMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture([[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]])

	-- the game's own minimap button: a dark disc, the icon in it, the gold-rimmed tracking border over both
	local back = button:CreateTexture(nil, "BACKGROUND")
	back:SetSize(20, 20)
	back:SetTexture([[Interface\Minimap\UI-Minimap-Background]])
	back:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(17, 17)
	icon:SetTexture(ICON)
	icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])
	border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

	button:SetScript("OnClick", function(_, which)
		if which == "RightButton" then
			ns.ToggleRing()
		else
			ns.Window:Toggle()
		end
	end)
	button:SetScript("OnEnter", tooltip)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- dragged round the rim: the angle from the map's middle to the cursor
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			if not (mx and cx) then return end
			own().angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
			place(self)
		end)
	end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

	place(button)
	button:SetShown(Launcher:Shown())
	Launcher.button = button
	-- a map that changes size (an addon's, the game's own options) keeps the button on its rim
	Minimap:HookScript("OnSizeChanged", function() place(button) end)
end

-- ---------------------------------------------------------------------------------- the settings page
local function BuildPage()
	if Launcher.page or not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
	local page = CreateFrame("Frame")
	local title = W.Text(page, "GameFontNormalLarge", W.GOLD)
	title:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -16)
	title:SetText("Cursor Finder")
	local about = W.Text(page, "GameFontHighlight")
	about:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	about:SetPoint("RIGHT", page, "RIGHT", -16, 0)
	about:SetWordWrap(true)
	about:SetText("The cursor kept in sight in a crowded fight: a ring round it in the colour of what is under it, a shake of the mouse that shows where it is, the name and health of the mob under it beside it and an arrow over that mob.")

	local open = W.Button(page, "Open Cursor Finder", 200, 24)
	open:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -16)
	open:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		ns.Window:Toggle()
	end)

	local check = W.Check(page, "Show the button on the minimap")
	check:SetPoint("TOPLEFT", open, "BOTTOMLEFT", -2, -12)
	check:SetScript("OnClick", function(self) Launcher:SetShown(self:GetChecked()) end)
	page:SetScript("OnShow", function() check:SetChecked(Launcher:Shown()) end)
	Launcher.check = check

	local slash = W.Text(page, "GameFontDisableSmall")
	slash:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 2, -12)
	slash:SetText("/cursorfinder — the window; /cursorfinder find — show where the cursor is; /cursorfinder on|off — the ring; /cursorfinder minimap — this button on or off; /cursorfinder why — why the ring is shown or not")

	local category = Settings.RegisterCanvasLayoutCategory(page, "Cursor Finder")
	Settings.RegisterAddOnCategory(category)
	Launcher.page, Launcher.category = page, category
end

ns.OnLogin(function()
	ns.safecall(BuildButton)
	ns.safecall(BuildPage)
end)
