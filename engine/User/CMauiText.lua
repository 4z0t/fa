---@meta

---@class moho.text_methods : moho.control_methods
local CMauiText = {}

---
---@param text string
---@return number
function CMauiText:GetStringAdvance(text)
end

---
---@return string
function CMauiText:GetText()
end

---
---@param doCenter boolean
function CMauiText:SetCenteredHorizontally(doCenter)
end

---
---@param doCenter boolean
function CMauiText:SetCenteredVertically(doCenter)
end

---
---@param shadow boolean
function CMauiText:SetDropShadow(shadow)
end

--- Causes the control to only render as many characters as fit in its width
---@param clip boolean
function CMauiText:SetNewClipToWidth(clip)
end

---
---@param color Color
function CMauiText:SetNewColor(color)
end

---
---@param family string
---@param pointsize number
function CMauiText:SetNewFont(family, pointsize)
end

---
---@param text LocalizedString | number
function CMauiText:SetText(text)
end

return CMauiText
