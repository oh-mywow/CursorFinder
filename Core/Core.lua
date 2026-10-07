-- Cursor Finder — the mouse cursor kept in sight in a crowded fight: a marker round it (the Predator's three
-- dots by default, or a ring, a crosshair…) in the colour of what is under it, a shake of the mouse (or a key, or
-- the start of a fight) that sends the marker big and closing in on it, the name, level and health of the unit under
-- it beside it, and an arrow over that unit's nameplate (Cursor.lua). Its looks are the default interface's own
-- (Widgets.lua); it needs no other addon.
--
-- Client: WoW Forever beta (Interface 16001, the retail-family UI, secret values: see Cursor.lua).
local ADDON, ns = ...
CursorFinder = ns

function ns.Print(text) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Cursor Finder:|r " .. tostring(text)) end

function ns.safecall(fn, ...)
	local ok, problem = pcall(fn, ...)
	if not ok and geterrorhandler then geterrorhandler()(problem) end
	return ok
end

local onLogin = {}
function ns.OnLogin(fn) onLogin[#onLogin + 1] = fn end

-- ---------------------------------------------------------------------------------- chat text
-- What the addon says in the chat: English, and Russian on a Russian client. The windows are in English.
local L = {
	ringOn = "marker round the cursor: on",
	ringOff = "marker round the cursor: off",
	buttonShown = "minimap button: shown",
	buttonHidden = "minimap button: hidden",
	help = "/cursorfinder — the window; /cursorfinder find — show where the cursor is; /cursorfinder on|off — the marker; /cursorfinder minimap — the minimap button on or off; /cursorfinder why — why the marker is shown or not",
	yes = "yes",
	no = "no",
	whyFight = "in a fight: %s (event %s, game lockdown %s, player in combat %s); in a dungeon: %s",
	whySettings = "settings: marker %s, only in a fight %s, only in dungeons %s; turning the camera: %s",
	whyRing = "marker: %s (frame %s, texture %s, size %d, opacity %d%%)",
	shown = "should be shown",
	hidden = "hidden",
	lastError = "last error: %s",
	none = "none",
}
if GetLocale and GetLocale() == "ruRU" then
	L.ringOn = "маркер вокруг курсора: включён"
	L.ringOff = "маркер вокруг курсора: выключен"
	L.buttonShown = "кнопка у мини-карты: показана"
	L.buttonHidden = "кнопка у мини-карты: скрыта"
	L.help = "/cursorfinder — окно; /cursorfinder find — показать, где курсор; /cursorfinder on|off — маркер; /cursorfinder minimap — кнопка у мини-карты вкл/выкл; /cursorfinder why — почему маркер видно или нет"
	L.yes = "да"
	L.no = "нет"
	L.whyFight = "в бою: %s (событие %s, блокировка игры %s, бой игрока %s); в подземелье: %s"
	L.whySettings = "настройки: маркер %s, только в бою %s, только в подземельях %s; камера мышью: %s"
	L.whyRing = "маркер: %s (рамка %s, картинка %s, размер %d, прозрачность %d%%)"
	L.shown = "должно быть видно"
	L.hidden = "скрыто"
	L.lastError = "последняя ошибка: %s"
	L.none = "нет"
end
ns.L = L

-- ---------------------------------------------------------------------------------- settings
-- CursorFinderDB: the switches below by their keys, the ring's size and opacity, the minimap button's place.
ns.DEFAULTS = {
	ring = true,        -- the marker round the cursor
	shape = "predator", -- which marker (Cursor.SHAPES): the Predator's three dots unless chosen
	lockSound = false,  -- a click when the Predator locks on to an enemy
	tint = true,        -- in the colour of what is under it (else always gold)
	size = 56,          -- the marker's width, UI units
	alpha = 0.9,        -- the marker's opacity
	shake = true,       -- a shake of the mouse finds the cursor
	pull = true,        -- so does the start of a fight
	label = true,       -- name, level and health beside the cursor
	arrow = true,       -- an arrow over the nameplate of the unit under the cursor
	combatOnly = false, -- all of it only in a fight
	dungeonOnly = false, -- all of it only in dungeons, raids and scenarios
}

function ns.Get(key)
	local value = ns.db and ns.db[key]
	if value == nil then return ns.DEFAULTS[key] end
	return value
end

function ns.Set(key, value)
	if not ns.db then return end
	ns.db[key] = value
	if ns.Cursor then ns.Cursor:Refresh() end
end

-- the ring on or off, from the slash command or the minimap button's right-click
function ns.ToggleRing(on)
	if on == nil then on = not ns.Get("ring") end
	ns.Set("ring", on and true or false)
	if ns.Window then ns.Window:Paint() end
	ns.Print(ns.Get("ring") and L.ringOn or L.ringOff)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and name == ADDON then
		CursorFinderDB = type(CursorFinderDB) == "table" and CursorFinderDB or {}
		ns.db = CursorFinderDB
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		for _, fn in ipairs(onLogin) do ns.safecall(fn) end
	end
end)

-- ---------------------------------------------------------------------------------- the key (Bindings.xml)
BINDING_HEADER_CURSORFINDER = "Cursor Finder"
BINDING_NAME_CURSORFINDER_FIND = "Find the cursor"

-- ---------------------------------------------------------------------------------- /cursorfinder
SLASH_CURSORFINDER1 = "/cursorfinder"
SLASH_CURSORFINDER2 = "/cfind"
SlashCmdList.CURSORFINDER = function(message)
	local command = (message or ""):lower():match("^%s*(%S*)")
	if command == "" then
		if ns.Window then ns.Window:Toggle() end
	elseif command == "find" then
		if ns.Cursor then ns.Cursor:Find() end
	elseif command == "why" then
		if ns.Cursor then ns.Cursor:Why() end
	elseif command == "on" or command == "off" then
		ns.ToggleRing(command == "on")
	elseif command == "minimap" then
		local Launcher = ns.Launcher
		if Launcher then
			Launcher:SetShown(not Launcher:Shown())
			ns.Print(Launcher:Shown() and L.buttonShown or L.buttonHidden)
		end
	else
		ns.Print(L.help)
	end
end
