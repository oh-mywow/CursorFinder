-- Cursor Finder — the cursor itself: a marker that follows it (a ring, a crosshair, corners, a diamond, a triangle, a
-- flag, or the Predator's three red dots that close in on an enemy), the same marker big and closing in on it to find
-- it (a shake of the mouse, the key, the start of a fight), and what is under it — the name, level and health of
-- that unit beside the cursor, an arrow over its nameplate, or the name of the object the game's tooltip shows.
--
-- Secret values (Midnight): the name of a unit may be a secret where the map restricts identities, its health
-- always is. Both go straight into the sinks that take a secret as it comes (FontString:SetText /
-- SetFormattedText, StatusBar:SetMinMaxValues / SetValue) and are never read, compared or joined here. Whether the
-- unit under the cursor is the target may be a secret too: then it is simply not said.
local ADDON, ns = ...
local W = ns.W

local Cursor = {}
ns.Cursor = Cursor

local MEDIA = [[Interface\AddOns\]] .. ADDON .. [[\Media\]]
local GOLD = W.GOLD
local GREY = { 0.55, 0.55, 0.55 }
local FRIEND = { 0.4, 0.75, 1 }      -- a player who is on our side (the selection colour's blue is too dark)

local function secret(value) return issecretvalue and issecretvalue(value) or false end

-- a yes/no about a unit; no when the game will not say (a secret, or an error)
local function ask(fn, ...)
	local ok, value = pcall(fn, ...)
	if not ok or secret(value) then return false end
	return value and true or false
end

-- ---------------------------------------------------------------------------------- the state of play
-- in a fight: from the events, since InCombatLockdown() still says no while PLAYER_REGEN_DISABLED runs
local fighting, inDungeon = false, false

local function readInstance()
	local inside, kind = IsInInstance()
	inDungeon = inside and (kind == "party" or kind == "raid" or kind == "scenario") or false
end

-- in a fight by any of three: our own flag from the events, the game's lockdown, the player's combat state (so a
-- fight already on when the addon looked, or an event missed, still counts)
local function plain(value) return not secret(value) and value and true or false end
local function inFight()
	if fighting then return true end
	if InCombatLockdown and plain(InCombatLockdown()) then return true end
	return UnitAffectingCombat and plain(UnitAffectingCombat("player")) or false
end

-- the "only in a fight" / "only in dungeons" switches
local function allowed()
	if ns.Get("combatOnly") and not inFight() then return false end
	if ns.Get("dungeonOnly") and not inDungeon then return false end
	return true
end

-- turning the camera with a mouse button held hides the cursor: everything of ours goes with it
local function mouselooking() return IsMouselooking and IsMouselooking() or false end

-- the cursor over the world itself, not over a window or a bar
local function overWorld()
	local top
	if GetMouseFoci then
		local foci = GetMouseFoci()
		top = foci and foci[1]
	elseif GetMouseFocus then
		top = GetMouseFocus()
	end
	return top == nil or top == WorldFrame
end

-- ---------------------------------------------------------------------------------- the frames
-- the cursor's spot: an empty frame moved to the cursor every frame; everything else hangs off it
local spot = CreateFrame("Frame", nil, UIParent)
spot:SetSize(1, 1)
spot:SetPoint("CENTER")

local ring = CreateFrame("Frame", "CursorFinderRing", UIParent)
ring:SetFrameStrata("TOOLTIP")
ring:SetPoint("CENTER", spot, "CENTER")
ring:Hide()
local band = ring:CreateTexture(nil, "ARTWORK")
band:SetTexture(MEDIA .. "Ring")
band:SetAllPoints()
-- the find: a second ring, big at first, that closes in on the cursor
local beacon = ring:CreateTexture(nil, "OVERLAY")
beacon:SetTexture(MEDIA .. "Ring")
beacon:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
beacon:SetPoint("CENTER")
beacon:Hide()

-- ---------------------------------------------------------------------------------- the markers
-- A texture of Media/ (tools/make_media.py draws them, the cursor's tip at the middle, white to be tinted), or the
-- Predator: three dots turning round the cursor that close in on an enemy under it and lock on (see Hunt below);
-- its dots take the colour of what is under the cursor as every marker does: gold over nothing, red on an enemy.
Cursor.SHAPES = {
	{ key = "predator", name = "Predator", icon = "Predator" },
	{ key = "ring", name = "Ring", file = "Ring" },
	{ key = "crosshair", name = "Crosshair", file = "Crosshair" },
	{ key = "corners", name = "Corners", file = "Corners" },
	{ key = "diamond", name = "Diamond", file = "Diamond" },
	{ key = "triangle", name = "Triangle", file = "Triangle" },
	{ key = "flag", name = "Flag", file = "Flag" },
}

function Cursor:Shape()
	local key = ns.Get("shape")
	for _, shape in ipairs(Cursor.SHAPES) do
		if shape.key == key then return shape end
	end
	return Cursor.SHAPES[1]
end

local dots, lines = {}, {}
for index = 1, 3 do
	local d = ring:CreateTexture(nil, "OVERLAY")
	d:SetTexture(MEDIA .. "Dot")
	d:Hide()
	dots[index] = d
	local l = ring:CreateLine(nil, "ARTWORK")
	l:SetThickness(1.5)
	l:SetColorTexture(1, 1, 1, 1)
	l:Hide()
	lines[index] = l
end

-- The hunt: the dots' angle (degrees) and distance from the tip, how far the lock has gone (0-1), what is under the
-- cursor ("enemy", "other" or nil) and its colour, set by the look ten times a second; the dots move every frame.
local hunt = { angle = 0, radius = nil, lock = 0, flash = 0, target = nil, locked = false,
	colour = { GOLD[1], GOLD[2], GOLD[3] } }

local function huntStep(elapsed, finding, findTime)
	local size = ns.Get("size")
	local wide, tight = size * 0.41, size * 0.19
	local enemy = hunt.target == "enemy"
	local want = enemy and tight or wide
	-- found again (a shake, the key): the dots come in from far away
	if finding > 0 then
		local t = 1 - finding / findTime
		want = wide * (1 + 5 * (1 - t) * (1 - t))
	end
	hunt.radius = hunt.radius or want
	hunt.radius = hunt.radius + (want - hunt.radius) * math.min(1, elapsed * 12)
	if enemy then
		-- turning to the lock: one dot above the tip, two beside it, clear of the pointer
		local goal = math.floor(hunt.angle / 120 + 0.5) * 120
		hunt.angle = hunt.angle + (goal - hunt.angle) * math.min(1, elapsed * 10)
	else
		hunt.angle = (hunt.angle + 40 * elapsed) % 360
	end
	local close = enemy and math.abs(hunt.radius - tight) < 1.5
	hunt.lock = hunt.lock + ((close and 1 or 0) - hunt.lock) * math.min(1, elapsed * 14)
	if close and not hunt.locked then
		hunt.flash = 0.18
		if ns.Get("lockSound") and PlaySound then
			PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856, "SFX")
		end
	end
	hunt.locked = close
	hunt.flash = math.max(0, hunt.flash - elapsed)

	local opacity = ns.Get("alpha")
	-- a little brighter as the lock closes; otherwise as bright as the other markers
	local alpha = enemy and (0.85 + 0.15 * hunt.lock) or 0.85
	local r, g, b = hunt.colour[1], hunt.colour[2], hunt.colour[3]
	local dotSize = math.max(10, size * 0.32) * (1 + 0.6 * hunt.flash / 0.18)
	local spots = {}
	for index = 1, 3 do
		local a = math.rad(hunt.angle - 90 + (index - 1) * 120)
		-- (the angle runs as on the screen, y downwards; the game's y goes up)
		local x, y = hunt.radius * math.cos(a), -hunt.radius * math.sin(a)
		spots[index] = { x, y }
		local d = dots[index]
		d:ClearAllPoints()
		d:SetPoint("CENTER", ring, "CENTER", x, y)
		d:SetSize(dotSize, dotSize)
		d:SetVertexColor(r, g, b)
		d:SetAlpha(alpha * opacity)
	end
	for index = 1, 3 do
		local from, to = spots[index], spots[index % 3 + 1]
		local l = lines[index]
		l:SetStartPoint("CENTER", ring, from[1], from[2])
		l:SetEndPoint("CENTER", ring, to[1], to[2])
		l:SetColorTexture(r, g, b, 1)
		l:SetAlpha(0.7 * hunt.lock * opacity)
	end
end

local function huntShown(on)
	for index = 1, 3 do
		dots[index]:SetShown(on)
		lines[index]:SetShown(on)
	end
	if not on then hunt.radius, hunt.lock, hunt.locked = nil, 0, false end
end

-- beside the cursor: a small tooltip-like box, kept on the screen
local LABEL_WIDTH = 176
local label = CreateFrame("Frame", "CursorFinderLabel", UIParent, "BackdropTemplate")
label:SetFrameStrata("TOOLTIP")
label:SetSize(LABEL_WIDTH, 54)
label:SetClampedToScreen(true)
W.Backdrop(label, 0.75)
label:Hide()
label.name = W.Text(label, "GameFontNormal")
label.name:SetPoint("TOPLEFT", label, "TOPLEFT", 9, -8)
label.name:SetPoint("RIGHT", label, "RIGHT", -9, 0)
label.name:SetWordWrap(false)
label.info = W.Text(label, "GameFontHighlightSmall", { 0.8, 0.8, 0.8 })
label.info:SetPoint("TOPLEFT", label.name, "BOTTOMLEFT", 0, -3)
label.percent = W.Text(label, "GameFontHighlightSmall")
label.percent:SetPoint("RIGHT", label, "RIGHT", -9, 0)
label.percent:SetPoint("TOP", label.info, "TOP")
label.percent:SetJustifyH("RIGHT")
label.health = CreateFrame("StatusBar", nil, label)
label.health:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
label.health:SetStatusBarColor(0, 1, 0)
label.health:SetPoint("TOPLEFT", label.info, "BOTTOMLEFT", 0, -4)
label.health:SetPoint("RIGHT", label, "RIGHT", -9, 0)
label.health:SetHeight(8)
local healthBack = label.health:CreateTexture(nil, "BACKGROUND")
healthBack:SetAllPoints()
healthBack:SetColorTexture(0, 0, 0, 0.6)

-- over the mob: an arrow that bobs above its nameplate
local arrow = CreateFrame("Frame", "CursorFinderArrow", UIParent)
arrow:SetSize(26, 26)
arrow:SetFrameStrata("LOW")
arrow:Hide()
arrow.tex = arrow:CreateTexture(nil, "ARTWORK")
arrow.tex:SetTexture(MEDIA .. "Arrow")
arrow.tex:SetAllPoints()
arrow.bob = arrow.tex:CreateAnimationGroup()
arrow.bob:SetLooping("BOUNCE")
local move = arrow.bob:CreateAnimation("Translation")
move:SetOffset(0, 6)
move:SetDuration(0.35)
move:SetSmoothing("IN_OUT")
arrow:SetScript("OnShow", function(self) self.bob:Play() end)
arrow:SetScript("OnHide", function(self) self.bob:Stop() end)

-- ---------------------------------------------------------------------------------- what is under the cursor
-- the unit's colour as the game draws its nameplate: red an enemy, yellow neutral, green friendly; grey for the
-- dead and for a mob someone else has tagged; a player on our side in light blue
local function colourOf(unit)
	if ask(UnitIsDead, unit) or ask(UnitIsTapDenied, unit) then return GREY[1], GREY[2], GREY[3] end
	if ask(UnitIsPlayer, unit) and not ask(UnitCanAttack, "player", unit) then return FRIEND[1], FRIEND[2], FRIEND[3] end
	local r, g, b = UnitSelectionColor(unit)
	if secret(r) or r == nil then return GOLD[1], GOLD[2], GOLD[3] end
	return r, g, b
end

local function isTarget(unit)
	return ask(UnitExists, "target") and ask(UnitIsUnit, unit, "target")
end

-- the words are the game's own, so the line reads in the client's language like its "Level"
local RARE = ITEM_QUALITY3_DESC or "Rare"
local RANK = { worldboss = BOSS or "Boss", elite = ELITE or "Elite", rare = RARE,
	rareelite = RARE .. ", " .. (ELITE or "Elite") }

local function infoOf(unit)
	local parts = {}
	local level = UnitLevel(unit)
	if secret(level) or not level or level <= 0 then
		parts[1] = (LEVEL or "Level") .. " ??"
	else
		parts[1] = (LEVEL or "Level") .. " " .. level
	end
	local rank = UnitClassification(unit)
	if not secret(rank) and rank and RANK[rank] then parts[#parts + 1] = RANK[rank] end
	if isTarget(unit) then parts[#parts + 1] = "|cffffd100" .. (TARGET or "Target") .. "|r" end
	return table.concat(parts, ", ")
end

-- an object of the world (a chest, a herb, a door): the first line of the game's own tooltip for it
local function objectName()
	if not (GameTooltip and GameTooltip:IsShown() and GameTooltip:GetOwner() == UIParent) then return nil end
	local line = _G.GameTooltipTextLeft1
	local text = line and line:GetText()
	if secret(text) then return text end
	if not text or text == "" then return nil end
	return text
end

local function paintUnit(unit, r, g, b)
	label.name:SetText((UnitName(unit)))
	label.name:SetTextColor(r, g, b)
	label.info:SetText(infoOf(unit))
	label.info:Show()
	if ask(UnitIsDead, unit) then
		label.health:Hide()
		label.percent:SetText(DEAD or "Dead")
	else
		label.health:SetMinMaxValues(0, UnitHealthMax(unit))
		label.health:SetValue(UnitHealth(unit))
		label.health:Show()
		-- (without the game's 0-100 curve the percent would come as a fraction: then none is shown)
		if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
			label.percent:SetFormattedText("%d%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
		else
			label.percent:SetText("")
		end
	end
	label.percent:Show()
	label:SetHeight(54)
	label:Show()
end

local function paintObject(text)
	label.name:SetText(text)
	label.name:SetTextColor(1, 1, 1)
	label.info:Hide()
	label.percent:Hide()
	label.health:Hide()
	label:SetHeight(28)
	label:Show()
end

local function placeArrow(unit, r, g, b)
	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
	if not ok or not plate or (plate.IsForbidden and plate:IsForbidden()) or ask(UnitIsDead, unit) then
		arrow:Hide()
		return
	end
	arrow:ClearAllPoints()
	if not pcall(arrow.SetPoint, arrow, "BOTTOM", plate, "TOP", 0, 2) then
		arrow:Hide()
		return
	end
	arrow.tex:SetVertexColor(r, g, b)
	arrow:Show()
end

-- what went wrong last, for /cursorfinder why; each new problem is also told once to the game's error handler
local problems, lastProblem = {}, nil
local function remember(part, problem)
	lastProblem = ("%s: %s"):format(part, tostring(problem))
	if problems[lastProblem] then return end
	problems[lastProblem] = true
	if geterrorhandler then geterrorhandler()("Cursor Finder, " .. lastProblem) end
end

-- one part of the look on its own: a unit the game hides more of in a fight can break the label or the arrow,
-- never the ring
local function part(name, fn, ...)
	local ok, a, b, c = pcall(fn, ...)
	if not ok then remember(name, a) return false end
	return true, a, b, c
end

local function underCursor()
	if UnitExists("mouseover") then return "mouseover" end
	return nil
end

-- the label on the cursor's right, or on its left where the right would run off the screen
local cursorX, labelSide = 0, nil
local function placeLabel()
	local gap = ns.Get("size") / 2 + 6
	local side = cursorX + gap + LABEL_WIDTH > UIParent:GetWidth() and "left" or "right"
	if side == labelSide then return end
	labelSide = side
	label:ClearAllPoints()
	if side == "right" then
		label:SetPoint("LEFT", spot, "CENTER", gap, 0)
	else
		label:SetPoint("RIGHT", spot, "CENTER", -gap, 0)
	end
end

local function paintLabel(unit, r, g, b)
	if not overWorld() then label:Hide() return end
	placeLabel()
	if unit then paintUnit(unit, r, g, b) return end
	local object = objectName()
	if secret(object) or object then paintObject(object) else label:Hide() end
end

-- one look, ten times a second and whenever the unit under the cursor changes
local finding = 0
function Cursor:Look()
	-- first the ring itself, from nothing that can fail: the switches, the fight, the camera
	local show = allowed() and not mouselooking()
	local wantRing = show and ns.Get("ring") and true or false
	local predator = self:Shape().key == "predator"
	band:SetShown(wantRing and not predator)
	huntShown((wantRing or finding > 0) and predator)
	ring:SetShown(wantRing or finding > 0)

	-- then what is under the cursor, each part on its own
	local okUnit, unit = part("unit", underCursor)
	if not okUnit then unit = nil end
	local r, g, b = GOLD[1], GOLD[2], GOLD[3]
	if unit then
		local ok, cr, cg, cb = part("colour", colourOf, unit)
		if ok then r, g, b = cr, cg, cb end
	end
	if ns.Get("tint") then band:SetVertexColor(r, g, b) else band:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]) end
	-- the Predator's dots the same colour as any marker; they close in on enemies only
	if ns.Get("tint") then
		hunt.colour[1], hunt.colour[2], hunt.colour[3] = r, g, b
	else
		hunt.colour[1], hunt.colour[2], hunt.colour[3] = GOLD[1], GOLD[2], GOLD[3]
	end
	hunt.target = nil
	if unit then
		local okHostile, hostile = part("hostile", function()
			return ask(UnitCanAttack, "player", unit) and not ask(UnitIsDead, unit)
		end)
		hunt.target = (okHostile and hostile) and "enemy" or "other"
	end

	if show and ns.Get("label") then
		if not part("label", paintLabel, unit, r, g, b) then label:Hide() end
	else
		label:Hide()
	end
	if show and ns.Get("arrow") and unit then
		if not part("arrow", placeArrow, unit, r, g, b) then arrow:Hide() end
	else
		arrow:Hide()
	end
end

local function look() part("look", Cursor.Look, Cursor) end

-- /cursorfinder why: what the ring is going by right now
function Cursor:Why()
	local L = ns.L
	local function yes(v) return v and L.yes or L.no end
	ns.Print(L.whyFight:format(yes(inFight()), yes(fighting), yes(InCombatLockdown and plain(InCombatLockdown())),
		yes(UnitAffectingCombat and plain(UnitAffectingCombat("player"))), yes(inDungeon)))
	ns.Print(L.whySettings:format(yes(ns.Get("ring")), yes(ns.Get("combatOnly")), yes(ns.Get("dungeonOnly")),
		yes(mouselooking())))
	ns.Print(L.whyRing:format((allowed() and not mouselooking() and ns.Get("ring")) and L.shown or L.hidden,
		yes(ring:IsShown()), yes(band:IsShown()), ns.Get("size"), math.floor(ns.Get("alpha") * 100 + 0.5)))
	ns.Print(L.lastError:format(lastProblem or L.none))
end

-- ---------------------------------------------------------------------------------- finding it
local FIND_TIME = 0.6
local lastFind = 0

function Cursor:Find()
	finding = FIND_TIME
	lastFind = GetTime()
	ring:Show()
	-- the marker itself closes in on the cursor; the Predator's dots come in from far away (huntStep)
	if self:Shape().key == "predator" then
		huntShown(true)
	else
		beacon:Show()
	end
end

-- a shake: four quick turns of the mouse left and right within 0.8 s, each swing at least 30 units long
local SHAKE_SPEED, SHAKE_SWING, SHAKE_TURNS, SHAKE_WINDOW = 900, 30, 4, 0.8
local lastX, direction, swing, turns = nil, 0, 0, {}

local function shaken(now, dx, elapsed)
	if elapsed <= 0 or math.abs(dx) / elapsed < SHAKE_SPEED then return false end
	local d = dx > 0 and 1 or -1
	if d == direction then
		swing = swing + math.abs(dx)
		return false
	end
	if direction ~= 0 and swing >= SHAKE_SWING then turns[#turns + 1] = now end
	direction, swing = d, math.abs(dx)
	while turns[1] and now - turns[1] > SHAKE_WINDOW do table.remove(turns, 1) end
	return #turns >= SHAKE_TURNS
end

-- ---------------------------------------------------------------------------------- every frame
local driver = CreateFrame("Frame")
driver:Hide()
local since = 0
driver:SetScript("OnUpdate", function(_, elapsed)
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	x, y = x / scale, y / scale
	spot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	cursorX = x

	if ns.Get("shake") and lastX then
		local now = GetTime()
		if shaken(now, x - lastX, elapsed) and now - lastFind > 1.2 then
			wipe(turns)
			Cursor:Find()
		end
	end
	lastX = x

	if dots[1]:IsShown() then huntStep(elapsed, finding, FIND_TIME) end
	if finding > 0 then
		finding = finding - elapsed
		if finding <= 0 then
			beacon:Hide()
			-- (the look that comes next puts back what the switches want)
			if not band:IsShown() and not (ns.Get("ring") and Cursor:Shape().key == "predator" and allowed()) then
				ring:Hide()
				huntShown(false)
			end
		else
			local t = 1 - finding / FIND_TIME
			local size = math.max(ns.Get("size"), 40) * (1 + 5 * (1 - t) * (1 - t))
			beacon:SetSize(size, size)
			beacon:SetAlpha(0.35 + 0.65 * (1 - t * t))
		end
	end

	since = since + elapsed
	if since >= 0.1 then
		since = 0
		look()
	end
end)

-- ---------------------------------------------------------------------------------- settings and events
function Cursor:Refresh()
	local size = ns.Get("size")
	ring:SetSize(size, size)
	band:SetAlpha(ns.Get("alpha"))
	local shape = self:Shape()
	if shape.file then
		band:SetTexture(MEDIA .. shape.file)
		beacon:SetTexture(MEDIA .. shape.file)
	end
	labelSide = nil
	placeLabel()
	look()
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		fighting = true
		if ns.Get("pull") and (inDungeon or not ns.Get("dungeonOnly")) then Cursor:Find() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		fighting = false
	elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		readInstance()
	end
	look()
end)

-- at login the events and the frame loop come first, so nothing read after them can leave the addon dead
ns.OnLogin(function()
	for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
		"ZONE_CHANGED_NEW_AREA", "UPDATE_MOUSEOVER_UNIT" }) do
		events:RegisterEvent(event)
	end
	driver:Show()
	fighting = plain(UnitAffectingCombat("player"))
	readInstance()
	Cursor:Refresh()
end)
