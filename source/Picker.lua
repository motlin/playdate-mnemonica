-- Picks one item from a wrapping list with the crank or the D-pad.

import "CrankSelector"

local pd <const> = playdate

Picker = {}
Picker.__index = Picker

-- `dpadSteps` maps up/down/left/right to how many items that direction moves.
-- `onMove` is called once per frame in which the selection changed.
-- `turnsPerCycle` is how many full crank turns it takes to go once through the list.
function Picker:new(itemCount, dpadSteps, onMove, turnsPerCycle)
    local picker = setmetatable({}, self)
    picker.selector = CrankSelector:new(itemCount, 360 * turnsPerCycle / itemCount)
    picker.dpadSteps = dpadSteps
    picker.onMove = onMove

    -- Discard crank travel from before this picker existed
    pd.getCrankChange()

    return picker
end

function Picker:getSelection() return self.selector.index end

function Picker:select(index) self.selector:select(index) end

function Picker:update(sensitivity)
    local before = self.selector.index

    self.selector:turn(pd.getCrankChange(), sensitivity)

    if pd.buttonJustPressed(pd.kButtonUp) then
        self.selector:step(self.dpadSteps.up)
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        self.selector:step(self.dpadSteps.down)
    elseif pd.buttonJustPressed(pd.kButtonLeft) then
        self.selector:step(self.dpadSteps.left)
    elseif pd.buttonJustPressed(pd.kButtonRight) then
        self.selector:step(self.dpadSteps.right)
    end

    if self.selector.index ~= before then self.onMove() end
end
