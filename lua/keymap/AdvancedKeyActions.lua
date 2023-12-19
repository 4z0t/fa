--******************************************************************************************************
--** Copyright (c) 2023 4z0t
--**
--** Permission is hereby granted, free of charge, to any person obtaining a copy
--** of this software and associated documentation files (the "Software"), to deal
--** in the Software without restriction, including without limitation the rights
--** to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--** copies of the Software, and to permit persons to whom the Software is
--** furnished to do so, subject to the following conditions:
--**
--** The above copyright notice and this permission notice shall be included in all
--** copies or substantial portions of the Software.
--**
--** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--** IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--** FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--** AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--** LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--** OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--** SOFTWARE.
--******************************************************************************************************

-- upvalue scope for performance
local TableGetn = table.getn
local TableInsert = table.insert

local type = type
local iscallable = iscallable

local EntityCategoryFilterDown = EntityCategoryFilterDown


---@type table<string, CategoryMatcher>
local categoryActions = {}
function ProcessAction(name)
    if not categoryActions[name] then
        WARN("Attempt to use action " .. name .. " which wasn't registered")
        return
    end
    categoryActions[name]:Process(GetSelectedUnits())
end

---@class CategoryMatcher
---@field description string
---@field _actions CategoryAction[]
CategoryMatcher = Class()
{
    __init = function(self, description)
        self.description = description
    end,

    __call = function(self, actions)
        self._actions = actions
        self:Register()
        return self
    end,

    ---@param self CategoryMatcher
    Register = function(self)
        local name = self.description:gsub("[^A-Za-z0-9]+", "_")
        categoryActions[name] = self
        import("/lua/keymap/keymapper.lua").SetUserKeyAction(name,
            {
                action = "UI_Lua import('/lua/keymap/AdvancedKeyActions.lua').ProcessAction('" .. name .. "')",
                category = "AKA"
            })
        if import("/lua/keymap/keydescriptions.lua").keyDescriptions[name] then
            WARN(("Overwriting key action description of '%s'"):format(name))
        end
        import("/lua/keymap/keydescriptions.lua").keyDescriptions[name] = self.description
    end,

    ---@param self CategoryMatcher
    ---@param selection UserUnit[]?
    Process = function(self, selection)
        for _, action in ipairs(self._actions) do
            if action:Process(selection) then
                break
            end
        end
    end,
}

---@alias Action string | fun(selection:UserUnit[])

---@class CategoryAction
---@field _actions Action[]
---@field _category? EntityCategory
---@field _matcher false|fun(selection:UserUnit[]?, category:EntityCategory?):boolean
CategoryAction = Class()
{
    ---@param self CategoryAction
    ---@param category? EntityCategory
    __init = function(self, category)
        self._actions = {}
        self._category = category
        self._matcher = false
    end,

    ---Add action into list
    ---@param self CategoryAction
    ---@param action Action
    Action = function(self, action)
        TableInsert(self._actions, action)
        return self
    end,

    ---Match category and selected units
    ---@param self CategoryAction
    ---@param selection UserUnit[]?
    Matches = function(self, selection)
        local category = self._category
        if self._matcher then
            return self._matcher(selection, category)
        end
        return (not category and not selection)
            or
            (category and selection and
                TableGetn(EntityCategoryFilterDown(category, selection)) == TableGetn(selection))
    end,

    ---Set custom category matcher
    ---@param self CategoryAction
    ---@param matcher fun(selection:UserUnit[]?, category:EntityCategory?):boolean
    Match = function(self, matcher)
        self._matcher = matcher
        return self
    end,

    ---Process the action
    ---@param self CategoryAction
    ---@param selection UserUnit[]?
    ---@return boolean
    Process = function(self, selection)
        if self:Matches(selection) then
            self:Execute(selection)
            return true
        end
        return false
    end,

    ---@param self CategoryAction
    ---@param selection UserUnit[]?
    Execute = function(self, selection)
        for _, action in self._actions do
            if type(action) == "string" then
                ConExecute(action)
            elseif iscallable(action) then
                action(selection)
            else
                error("unknown action type")
            end
        end
    end
}

CategoryMatcher("Enter OC mode / Transport / Toggle repeat build")
{
    CategoryAction(), -- do nothing if no selection
    CategoryAction(categories.TRANSPORTATION)
        :Action "StartCommandMode order RULEUCC_Transport",
    CategoryAction(categories.COMMAND + categories.SUBCOMMANDER)
        :Action(import('/lua/ui/game/orders.lua').EnterOverchargeMode),
    CategoryAction(categories.FACTORY + categories.EXTERNALFACTORY)
        :Action(import("/lua/keymap/misckeyactions.lua").ToggleRepeatBuild)
}

CategoryMatcher("Select nearest idle t1 engineer / Enter reclaim mode")
{
    CategoryAction()
        :Action "UI_SelectByCategory +inview +nearest +idle ENGINEER TECH1",
    CategoryAction(categories.ENGINEER)
        :Action "StartCommandMode order RULEUCC_Reclaim",
}

CategoryMatcher("Build sensors / Select nearest air scout")
{
    CategoryAction()
        :Action "UI_SelectByCategory +nearest AIR INTELLIGENCE",
    CategoryAction(categories.ENGINEER + categories.FACTORY + categories.EXTERNALFACTORY)
        :Action "UI_Lua import('/lua/keymap/hotbuild.lua').buildAction('Sensors')",
}

CategoryMatcher("Select nearest idle transport / Transport")
{
    CategoryAction()
        :Action "UI_SelectByCategory +nearest +idle AIR TRANSPORTATION",
    CategoryAction(categories.TRANSPORTATION)
        :Action "StartCommandMode order RULEUCC_Transport",
}

CategoryMatcher("Toggle unit ability (submerge, stealth, shield, land, jamming)")
{
    CategoryAction(),
    CategoryAction(categories.SUBMERSIBLE)
        :Action(function(selection)
            local submergedUnits, surfacedUnits = import("/lua/keymap/misckeyactions.lua").SeparateDiveStatus(selection)
            if not table.empty(surfacedUnits) then
                IssueUnitCommand(surfacedUnits, "UNITCOMMAND_Dive")
            elseif not table.empty(submergedUnits) then
                IssueUnitCommand(submergedUnits, "UNITCOMMAND_Dive")
            end
        end),
    CategoryAction(categories.SHIELD + categories.PERSONALSHIELD)
        :Action(function(selection)
            local anyShieldsOn = false
            for _, unit in selection do
                if not GetScriptBit({ unit }, 0) then
                    anyShieldsOn = true
                    break
                end
            end
            ToggleScriptBit(selection, 0, not anyShieldsOn)
        end),
    CategoryAction(categories.FAVORSWATER)
        :Action(function(selection)
            local anyInLandingMode = false
            for _, unit in selection do
                if GetScriptBit({ unit }, 1) then
                    anyInLandingMode = true
                    break
                end
            end
            ToggleScriptBit(selection, 1, anyInLandingMode)
        end),

}
