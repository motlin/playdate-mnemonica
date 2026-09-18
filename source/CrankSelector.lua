-- Turns crank movement into a selection from a wrapping list of items.
-- Movement is relative: degrees accumulate until they add up to one item, so sensitivity only
-- changes how far the crank travels per item and every item stays reachable. Leftover travel
-- is kept, which means reversing direction right after a move needs a full item of travel
-- before the selection changes again.

CrankSelector = {}
CrankSelector.__index = CrankSelector

-- Absorbs floating point drift so a full rotation lands exactly where it started.
local EPSILON <const> = 1e-9

function CrankSelector:new(itemCount, degreesPerItem)
    local selector = setmetatable({}, self)
    selector.itemCount = itemCount
    selector.degreesPerItem = degreesPerItem
    selector.index = 1
    selector.pendingDegrees = 0
    return selector
end

-- Feed one frame of crank change. Returns how many items the selection moved (signed).
function CrankSelector:turn(degrees, sensitivity)
    local degreesPerStep = self.degreesPerItem / sensitivity
    self.pendingDegrees = self.pendingDegrees + degrees

    local magnitude = math.floor((math.abs(self.pendingDegrees) + EPSILON) / degreesPerStep)
    if magnitude == 0 then
        return 0
    end

    local steps = self.pendingDegrees > 0 and magnitude or -magnitude
    self.pendingDegrees = self.pendingDegrees - steps * degreesPerStep
    self:moveBy(steps)
    return steps
end

-- Move by whole items, as the D-pad does. Discards partial crank travel.
function CrankSelector:step(count)
    self.pendingDegrees = 0
    self:moveBy(count)
end

function CrankSelector:select(index)
    assert(index >= 1 and index <= self.itemCount, "index out of range: " .. tostring(index))
    self.pendingDegrees = 0
    self.index = index
end

function CrankSelector:moveBy(count)
    self.index = (self.index - 1 + count) % self.itemCount + 1
end
