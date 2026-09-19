-- Crank and D-pad handling for scenes that pick one of 52 cards or positions.

import "App"
import "Assets"
import "SharedState"

local pd <const> = playdate
local gameState <const> = App.gameState

DialInput = {}

DialInput.ITEM_COUNT = 52

local degreesPerItem = 360 / DialInput.ITEM_COUNT

-- Returns the item the crank points at, or `selection` unchanged if the crank has not moved.
function DialInput.selectionFromCrank(selection)
    local crankPosition = pd.getCrankPosition()  -- 0-359 degrees

    if math.abs(crankPosition - SharedState.lastCrankPosition) < 0.5 then
        return selection
    end

    local crankVelocity = crankPosition - SharedState.lastCrankPosition
    -- Handle wrap-around at 0/360 boundary
    if crankVelocity > 180 then
        crankVelocity = crankVelocity - 360
    elseif crankVelocity < -180 then
        crankVelocity = crankVelocity + 360
    end

    local effectiveDegreesPerItem = degreesPerItem / gameState.crankSensitivity
    local floatItem = (crankPosition / effectiveDegreesPerItem) + 1

    -- Snap to the nearest item when the crank is moving slowly
    local snapThreshold = 0.35
    local velocityThreshold = 3  -- Degrees per frame to consider "slow"

    if math.abs(crankVelocity) < velocityThreshold then
        local nearestItem = math.floor(floatItem + 0.5)
        if math.abs(floatItem - nearestItem) < snapThreshold then
            floatItem = nearestItem
        end
    end

    local newSelection = math.floor(floatItem)
    if newSelection > DialInput.ITEM_COUNT then newSelection = 1 end
    if newSelection < 1 then newSelection = 1 end

    if newSelection ~= selection then
        Assets.playSound(Assets.sounds.crankTick)
    end

    SharedState.lastCrankPosition = crankPosition
    return newSelection
end

function DialInput.wrap(selection)
    return (selection - 1) % DialInput.ITEM_COUNT + 1
end

-- Up/Down step by one, Left/Right jump by `jumpSize`.
function DialInput.selectionFromDpad(selection, jumpSize)
    local step
    if pd.buttonJustPressed(pd.kButtonUp) then
        step = -1
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        step = 1
    elseif pd.buttonJustPressed(pd.kButtonLeft) then
        step = -jumpSize
    elseif pd.buttonJustPressed(pd.kButtonRight) then
        step = jumpSize
    else
        return selection
    end

    Assets.playSound(Assets.sounds.crankTick)
    return DialInput.wrap(selection + step)
end
