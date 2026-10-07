-- Cursor Finder — its window (/cursorfinder, the minimap button, or Options → AddOns): the marker (its shape, picked
-- from a row of icons, its colour, size and opacity), finding the cursor, what is shown of the unit under it, and when
-- all of it is on. The settings themselves live in Core.lua.
local ADDON, ns = ...
local W = ns.W
local GOLD = W.GOLD

local Window = {}
ns.Window = Window

local WIDTH = 380

local function heading(frame, text, anchor, gap, x)
	local t = W.Text(frame, "GameFontNormal", GOLD)
	t:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, -(gap or 14))
	t:SetText(text)
	return t
end

local function note(frame, anchor, text, gap, x)
	local t = W.Text(frame, "GameFontDisableSmall")
	t:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, -(gap or 2))
	-- (narrower by its own indent, so an indented note keeps clear of the window's right edge)
	t:SetWidth(WIDTH - 40 - (x or 0))
	t:SetWordWrap(true)
	t:SetText(text)
	return t
end

-- a value with the spellbook's page arrows either side
local function stepper(frame, label, anchor, key, step, low, high, show)
	local text = W.Text(frame, "GameFontHighlightSmall")
	text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
	text:SetText(label)
	local value = W.Text(frame, "GameFontNormal", GOLD)
	value:SetPoint("LEFT", text, "LEFT", 130, 0)
	value:SetWidth(44)
	value:SetJustifyH("CENTER")
	local less, more = W.Arrow(frame, "prev"), W.Arrow(frame, "next")
	less:SetPoint("RIGHT", value, "LEFT", -2, 0)
	more:SetPoint("LEFT", value, "RIGHT", 2, 0)
	local function paint() value:SetText(show(ns.Get(key))) end
	local function change(delta)
		local v = math.floor((ns.Get(key) + delta) * 100 + 0.5) / 100
		ns.Set(key, math.max(low, math.min(high, v)))
		paint()
	end
	less:SetScript("OnClick", function() change(-step) end)
	more:SetScript("OnClick", function() change(step) end)
	frame.paints[#frame.paints + 1] = paint
	return text
end

local MEDIA = [[Interface\AddOns\]] .. ADDON .. [[\Media\]]
local ICON, ICON_GAP = 34, 8

-- one marker of the row: its picture (gold), its name on hover, a click chooses it
local function shapeButton(frame, shape, index, anchor)
	local b = CreateFrame("Button", nil, frame)
	b:SetSize(ICON, ICON)
	b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", (index - 1) * (ICON + ICON_GAP), -8)
	b.tex = b:CreateTexture(nil, "ARTWORK")
	b.tex:SetAllPoints()
	b.tex:SetTexture(MEDIA .. (shape.file or shape.icon))
	b.tex:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
	b:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]], "ADD")
	-- the one chosen: the action bars' gold glow round it
	b.mark = b:CreateTexture(nil, "OVERLAY")
	b.mark:SetTexture([[Interface\Buttons\UI-ActionButton-Border]])
	b.mark:SetBlendMode("ADD")
	b.mark:SetPoint("CENTER")
	b.mark:SetSize(ICON * 1.75, ICON * 1.75)
	b.key = shape.key
	b:SetScript("OnClick", function(self)
		ns.Set("shape", self.key)
		Window:Paint()
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(shape.name, 1, 1, 1)
		if shape.key == "predator" then
			GameTooltip:AddLine("Three dots turn round the cursor and close in on an enemy under it: red, locked on.",
				GOLD[1], GOLD[2], GOLD[3], true)
		end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

local function Build()
	local frame = W.Window("CursorFinderWindow", "Cursor Finder")
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	frame:SetSize(WIDTH, 560)
	frame.checks, frame.paints = {}, {}

	local function check(label, key, anchor, x, y)
		local c = W.Check(frame, label)
		c:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -2)
		c.key = key
		c:SetScript("OnClick", function(self)
			ns.Set(self.key, self:GetChecked())
			Window:Paint()
		end)
		frame.checks[#frame.checks + 1] = c
		return c
	end

	local top = CreateFrame("Frame", nil, frame)
	top:SetSize(1, 1)
	top:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -30)

	-- the marker: its shape, then whether it is shown, its colour, the Predator's click, its size and opacity
	local ringHead = heading(frame, "The marker", top, 0)
	frame.shapes = {}
	for index, shape in ipairs(ns.Cursor.SHAPES) do
		frame.shapes[index] = shapeButton(frame, shape, index, ringHead)
	end
	local ring = check("A marker round the cursor", "ring", frame.shapes[1], -2, -8)
	local tint = check("In the colour of what is under it", "tint", ring)
	local tintNote = note(frame, tint, "Red: an enemy, yellow: neutral, green: friendly, blue: a player on your side, grey: dead or tagged by someone else, gold: nothing. The Predator's dots close in and lock on to enemies only.", 0, 30)
	local click = check("Predator: a click when it locks on", "lockSound", tintNote, -30, -4)
	local size = stepper(frame, "Marker size", click, "size", 8, 32, 128, function(v) return ("%d"):format(v) end)
	size:SetPoint("TOPLEFT", click, "BOTTOMLEFT", 2, -10)
	local alpha = stepper(frame, "Marker opacity", size, "alpha", 0.1, 0.2, 1,
		function(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end)

	-- finding it
	local findHead = heading(frame, "Finding the cursor", alpha, 18)
	local shake = check("Shake the mouse: the marker, big, closes in on the cursor", "shake", findHead, -2, -4)
	local pull = check("The same when a fight starts", "pull", shake)
	local now = W.Button(frame, "Show me now", 150, 22)
	now:SetPoint("TOPLEFT", pull, "BOTTOMLEFT", 4, -6)
	now:SetScript("OnClick", function() ns.Cursor:Find() end)
	local keyNote = note(frame, now, "A key for it too: Options > Keybindings > Cursor Finder.", 6)

	-- what is under it
	local underHead = heading(frame, "What is under the cursor", keyNote, 14, -2)
	local label = check("Name, level and health beside the cursor", "label", underHead, -2, -4)
	local arrow = check("An arrow over that mob's nameplate", "arrow", label)
	local arrowNote = note(frame, arrow, "The arrow needs the game's nameplates on (V). Over a chest, a herb or a door the label gives its name.", 0, 30)

	-- when
	local whenHead = heading(frame, "When", arrowNote, 14, -28)
	local combat = check("Only in a fight", "combatOnly", whenHead, -2, -4)
	frame.last = check("Only in dungeons, raids and scenarios", "dungeonOnly", combat)

	frame:HookScript("OnShow", function()
		Window:Paint()
		-- the height from what it holds, once it has been laid out
		C_Timer.After(0, function()
			local topY, bottomY = frame:GetTop(), frame.last:GetBottom()
			if topY and bottomY then frame:SetHeight(topY - bottomY + 16) end
		end)
	end)
	return frame
end

function Window:Paint()
	local frame = self.frame
	if not frame then return end
	for _, c in ipairs(frame.checks) do c:SetOn(ns.Get(c.key)) end
	local chosen = ns.Cursor:Shape().key
	for _, b in ipairs(frame.shapes) do b.mark:SetShown(b.key == chosen) end
	for _, paint in ipairs(frame.paints) do paint() end
end

function Window:Toggle()
	self.frame = self.frame or Build()
	self.frame:SetShown(not self.frame:IsShown())
end
