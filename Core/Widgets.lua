-- Cursor Finder — the looks: Blizzard's own, as the default interface has them (a classic style in the game's own
-- colours, so the addon sits at home beside any interface). Blizzard's templates where there is one — the window (BasicFrameTemplateWithInset), its buttons
-- (UIPanelButtonTemplate), check boxes (UICheckButtonTemplate) — the tooltip's border and background, the game's
-- fonts in their usual gold and white.
local ADDON, ns = ...

local W = {}
ns.W = W

-- the default interface's colours
W.GOLD = { 1, 0.82, 0 }            -- NORMAL_FONT_COLOR
W.EDGE = { 0.6, 0.6, 0.6 }         -- a tooltip's border at rest

-- the tooltip's backdrop: dark, a thin silver-grey border
local TOOLTIP = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	tile = true, tileSize = 16, edgeSize = 14,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- a frame dressed as a tooltip; it must have been made with BackdropTemplate
function W.Backdrop(frame, alpha)
	frame:SetBackdrop(TOOLTIP)
	frame:SetBackdropColor(0, 0, 0, alpha or 0.8)
	frame:SetBackdropBorderColor(W.EDGE[1], W.EDGE[2], W.EDGE[3], 1)
end

-- a font string in one of the game's own fonts
function W.Text(parent, font, colour, layer)
	local text = parent:CreateFontString(nil, layer or "OVERLAY", font or "GameFontNormal")
	if colour then text:SetTextColor(colour[1], colour[2], colour[3]) end
	text:SetJustifyH("LEFT")
	return text
end

-- a button as the game's panels have them
function W.Button(parent, label, width, height)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width or 120, height or 22)
	button:SetText(label or "")
	return button
end

-- a check box with its label; SetOn ticks it
function W.Check(parent, label)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	local text = check.Text or check.text
	if text then
		text:SetFontObject("GameFontHighlightSmall")
		text:SetText(label or "")
	end
	function check:SetOn(on) self:SetChecked(on and true or false) end
	return check
end

-- the spellbook's page arrow, "prev" or "next"
function W.Arrow(parent, direction)
	local name = direction == "prev" and "PrevPage" or "NextPage"
	local arrow = CreateFrame("Button", nil, parent)
	arrow:SetSize(24, 24)
	arrow:SetNormalTexture([[Interface\Buttons\UI-SpellbookIcon-]] .. name .. [[-Up]])
	arrow:SetPushedTexture([[Interface\Buttons\UI-SpellbookIcon-]] .. name .. [[-Down]])
	arrow:SetDisabledTexture([[Interface\Buttons\UI-SpellbookIcon-]] .. name .. [[-Disabled]])
	arrow:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]], "ADD")
	return arrow
end

-- a window as the game's own simple ones: a title bar with its text and close button, dragged by the title
function W.Window(name, title)
	local frame = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	if frame.TitleText then frame.TitleText:SetText(title or "") end
	frame:Hide()
	if name then tinsert(UISpecialFrames, name) end
	return frame
end
