-- NumberDialRenderer module for rotating number dial visualization
-- Creates an alarm clock-style rotating dial for number selection (1-52)

local pd <const> = playdate
local gfx <const> = playdate.graphics

local NumberDialRenderer = {}
NumberDialRenderer.__index = NumberDialRenderer

function NumberDialRenderer:new()
    local renderer = setmetatable({}, self)

    -- Dial configuration
    renderer.centerX = 200  -- Center of the dial on screen
    renderer.centerY = 120  -- Vertical center for the dial
    renderer.radius = 80     -- Distance from center to number positions

    -- Visual configuration
    renderer.selectedScale = 2.0    -- Selected number is 100% larger
    renderer.minScale = 0.4         -- Minimum scale for distant numbers
    renderer.maxVisibleNumbers = 5  -- Number of numbers visible in the dial (reduced for clarity)

    -- Animation state
    renderer.currentRotation = 0    -- Current rotation angle of the dial
    renderer.targetRotation = 0     -- Target rotation angle (for smooth animation)
    renderer.rotationSpeed = 0.2    -- Smoothing factor for rotation animation (optimized for responsive feel)

    -- Font settings for numbers
    renderer.numberFont = gfx.getSystemFont(gfx.font.kFontFamilyHeading)
    renderer.smallNumberFont = gfx.getSystemFont()

    -- Performance optimization: cache transform calculations with size limit
    renderer.transformCache = {}
    renderer.maxCacheSize = 5  -- Limit cache to prevent memory bloat
    renderer.lastCacheRotation = -999  -- Force initial cache refresh
    renderer.cacheThreshold = 1.0  -- Degrees of rotation change before refreshing cache

    return renderer
end

-- Update the dial rotation based on selected number index
function NumberDialRenderer:updateRotation(selectedNumber)
    -- Calculate the target rotation angle
    -- Each number occupies 360/52 degrees
    local degreesPerNumber = 360 / 52

    -- Selected number should be at the top (0 degrees)
    -- So we rotate the dial backwards by the number's position
    self.targetRotation = -(selectedNumber - 1) * degreesPerNumber

    -- Smooth rotation animation
    local diff = self.targetRotation - self.currentRotation

    -- Handle wrap-around for smooth animation
    if diff > 180 then
        diff = diff - 360
    elseif diff < -180 then
        diff = diff + 360
    end

    -- Apply smoothing
    self.currentRotation = self.currentRotation + (diff * self.rotationSpeed)

    -- Normalize rotation to 0-360 range
    while self.currentRotation < 0 do
        self.currentRotation = self.currentRotation + 360
    end
    while self.currentRotation >= 360 do
        self.currentRotation = self.currentRotation - 360
    end
end

-- Calculate position and scale for a number on the dial
function NumberDialRenderer:getNumberTransform(numberIndex, selectedNumber)
    local degreesPerNumber = 360 / 52

    -- Calculate this number's angle on the dial
    local numberAngle = (numberIndex - 1) * degreesPerNumber + self.currentRotation

    -- Normalize angle to 0-360
    while numberAngle < 0 do
        numberAngle = numberAngle + 360
    end
    while numberAngle >= 360 do
        numberAngle = numberAngle - 360
    end

    -- Convert to radians for trigonometry
    local radians = math.rad(numberAngle)

    -- Calculate position on a circular path (simplified for clarity)
    -- Numbers arranged in a vertical wheel like a slot machine
    local x = self.centerX

    -- Position numbers vertically based on their angle
    -- The selected number should be at centerY
    local verticalSpacing = 40  -- Space between numbers
    local angleFromTop = numberAngle
    if angleFromTop > 180 then
        angleFromTop = angleFromTop - 360
    end

    -- Map angle to vertical position (-180 to 180 degrees -> multiple positions)
    local verticalOffset = (angleFromTop / degreesPerNumber) * verticalSpacing
    local y = self.centerY + verticalOffset

    -- Calculate scale based on distance from center
    local distanceFromCenter = math.abs(verticalOffset)
    local maxDistance = verticalSpacing * 2.5
    local scaleFactor = 1.0 - (distanceFromCenter / maxDistance)
    scaleFactor = math.max(0, math.min(1, scaleFactor))  -- Clamp to 0-1

    local scale = self.minScale + (self.selectedScale - self.minScale) * scaleFactor

    -- Extra emphasis on the selected number
    if numberIndex == selectedNumber then
        scale = self.selectedScale
        x = self.centerX  -- Keep centered
    end

    -- Calculate opacity based on distance from selected
    local opacity = scaleFactor

    -- Determine if number should be visible (limit to numbers close to selected)
    local distanceFromSelected = math.abs(numberIndex - selectedNumber)

    -- Handle wrap-around distance
    if distanceFromSelected > 26 then
        distanceFromSelected = 52 - distanceFromSelected
    end

    -- Only show numbers within 2 positions of selected
    local isVisible = distanceFromSelected <= 2

    -- Calculate draw order (numbers further from center should be drawn first)
    local drawOrder = -distanceFromCenter

    return {
        x = x,
        y = y,
        scale = scale,
        opacity = opacity,
        isVisible = isVisible,
        drawOrder = drawOrder,
        angle = numberAngle
    }
end

-- Draw a number with appropriate scaling and style
function NumberDialRenderer:drawNumber(number, x, y, scale, opacity)
    -- Choose font based on scale
    if scale > 1.2 then
        gfx.setFont(self.numberFont)
    else
        gfx.setFont(self.smallNumberFont)
    end

    -- Create a circular background for better visibility
    local bgRadius = 15 * scale

    -- Draw white background circle
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(x, y, bgRadius)

    -- Draw thicker black border for better visibility
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(3)  -- Increased from 2 to 3 for better contrast
    gfx.drawCircleAtPoint(x, y, bgRadius)
    gfx.setLineWidth(1)

    -- Draw the number text
    local numberText = tostring(number)

    -- Apply minimal dithering for depth effect to maintain contrast (reduced for performance)
    if opacity < 0.7 then  -- Raised threshold to reduce dithering frequency
        -- Use lighter dither patterns for better visibility
        local ditherLevel = math.floor((1 - opacity) * 2)  -- Further reduced from 3 to 2
        gfx.setDitherPattern(ditherLevel / 8, gfx.image.kDitherTypeBayer4x4)
    end

    gfx.drawTextAligned(numberText, x, y - 7 * scale, kTextAlignment.center)

    -- Reset dither pattern
    if opacity < 0.7 then
        gfx.setDitherPattern(0)
    end

    -- Reset font
    gfx.setFont()
end

-- Draw the rotating dial with numbers
function NumberDialRenderer:draw(selectedNumber)
    -- Update rotation animation
    self:updateRotation(selectedNumber)

    -- Check if we need to refresh the transform cache
    local rotationChange = math.abs(self.currentRotation - self.lastCacheRotation)
    local shouldRefreshCache = rotationChange >= self.cacheThreshold or not self.transformCache[selectedNumber]

    local numbersToDraw = {}

    if shouldRefreshCache then
        -- Check cache size limit before adding new entry
        local cacheCount = 0
        for _ in pairs(self.transformCache) do
            cacheCount = cacheCount + 1
        end

        if cacheCount >= self.maxCacheSize then
            -- Clear oldest cache entries (simple eviction strategy)
            local keysToRemove = {}
            local removeCount = 0
            for key, _ in pairs(self.transformCache) do
                if removeCount < (cacheCount - self.maxCacheSize + 1) then
                    table.insert(keysToRemove, key)
                    removeCount = removeCount + 1
                end
            end
            for _, key in ipairs(keysToRemove) do
                self.transformCache[key] = nil
            end
        end

        -- Recalculate transforms and update cache
        self.transformCache[selectedNumber] = {}
        self.lastCacheRotation = self.currentRotation

        for i = 1, 52 do
            local transform = self:getNumberTransform(i, selectedNumber)
            self.transformCache[selectedNumber][i] = transform

            if transform.isVisible then
                table.insert(numbersToDraw, {
                    number = i,
                    transform = transform
                })
            end
        end
    else
        -- Use cached transforms
        for i = 1, 52 do
            local transform = self.transformCache[selectedNumber][i]
            if transform and transform.isVisible then
                table.insert(numbersToDraw, {
                    number = i,
                    transform = transform
                })
            end
        end
    end

    -- Sort by draw order (back to front)
    table.sort(numbersToDraw, function(a, b)
        return a.transform.drawOrder < b.transform.drawOrder
    end)

    -- Draw numbers in correct order
    for _, numberData in ipairs(numbersToDraw) do
        local transform = numberData.transform
        self:drawNumber(numberData.number, math.floor(transform.x), math.floor(transform.y), transform.scale, transform.opacity)
    end

    -- Draw selection indicator (subtle arrows or brackets around selected number)
    self:drawSelectionIndicator(selectedNumber)

    -- Draw position indicator
    self:drawPositionIndicator(selectedNumber)
end

-- Draw visual indicator for the selected number
function NumberDialRenderer:drawSelectionIndicator(selectedNumber)
    -- Draw simple selection box around the selected number
    local boxWidth = 60
    local boxHeight = 35

    gfx.setLineWidth(2)
    gfx.drawRect(
        self.centerX - boxWidth / 2,
        self.centerY - boxHeight / 2,
        boxWidth,
        boxHeight
    )
    gfx.setLineWidth(1)
end

-- Draw position indicator showing which number is selected
function NumberDialRenderer:drawPositionIndicator(selectedNumber)
    -- Skip drawing position dots to reduce clutter
    -- The selection box is enough to indicate the selected number
end

-- Draw dial frame/background
function NumberDialRenderer:drawFrame()
    -- Keep frame minimal - just draw vertical lines to suggest a slot machine
    gfx.setLineWidth(1)

    -- Draw vertical guide lines on sides
    local lineX1 = self.centerX - 40
    local lineX2 = self.centerX + 40

    gfx.drawLine(lineX1, 40, lineX1, 200)
    gfx.drawLine(lineX2, 40, lineX2, 200)
end

return NumberDialRenderer
