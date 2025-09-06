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
    renderer.selectedScale = 1.8    -- Selected number is 80% larger
    renderer.minScale = 0.6         -- Minimum scale for distant numbers
    renderer.maxVisibleNumbers = 11 -- Number of numbers visible in the dial

    -- Animation state
    renderer.currentRotation = 0    -- Current rotation angle of the dial
    renderer.targetRotation = 0     -- Target rotation angle (for smooth animation)
    renderer.rotationSpeed = 0.15   -- Smoothing factor for rotation animation

    -- Font settings for numbers
    renderer.numberFont = gfx.getSystemFont(gfx.font.kFontFamilyHeading)
    renderer.smallNumberFont = gfx.getSystemFont()

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

    -- Calculate position on an elliptical path
    -- Use ellipse to create depth effect (numbers at bottom appear further away)
    local ellipseWidthRatio = 1.0   -- Horizontal radius multiplier
    local ellipseHeightRatio = 0.6  -- Vertical radius multiplier (squashed for perspective)

    local x = self.centerX + math.sin(radians) * self.radius * ellipseWidthRatio
    local y = self.centerY + math.cos(radians) * self.radius * ellipseHeightRatio

    -- Calculate scale based on vertical position (numbers at top are larger)
    -- Use cosine for smooth scaling (1 at top, -1 at bottom)
    local depthFactor = (math.cos(radians) + 1) / 2  -- Normalize to 0-1 range
    local scale = self.minScale + (self.selectedScale - self.minScale) * depthFactor

    -- Extra emphasis on the selected number
    if numberIndex == selectedNumber then
        scale = scale * 1.2  -- Make selected number even more prominent
        -- Slight position adjustment to pull selected number forward
        y = y - 10
    end

    -- Calculate opacity/visibility based on position
    -- Numbers at the back (bottom) should be dimmer
    -- Increased minimum opacity for better contrast on 1-bit display
    local opacity = 0.6 + (depthFactor * 0.4)  -- Range from 0.6 to 1.0

    -- Determine if number should be visible (limit number of visible numbers)
    local distanceFromSelected = math.abs(numberIndex - selectedNumber)

    -- Handle wrap-around distance
    if distanceFromSelected > 26 then
        distanceFromSelected = 52 - distanceFromSelected
    end

    local isVisible = distanceFromSelected <= math.floor(self.maxVisibleNumbers / 2)

    -- Calculate draw order (numbers at back should be drawn first)
    local drawOrder = -math.cos(radians)  -- -1 to 1, where -1 is back, 1 is front

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

    -- Apply minimal dithering for depth effect to maintain contrast
    if opacity < 0.8 then
        -- Use lighter dither patterns for better visibility
        local ditherLevel = math.floor((1 - opacity) * 3)  -- Reduced from 8 to 3
        gfx.setDitherPattern(ditherLevel / 8, gfx.image.kDitherTypeBayer4x4)
    end

    gfx.drawTextAligned(numberText, x, y - 7 * scale, kTextAlignment.center)

    -- Reset dither pattern
    if opacity < 0.8 then
        gfx.setDitherPattern(0)
    end

    -- Reset font
    gfx.setFont()
end

-- Draw the rotating dial with numbers
function NumberDialRenderer:draw(selectedNumber)
    -- Update rotation animation
    self:updateRotation(selectedNumber)

    -- Collect transform data for all visible numbers
    local numbersToDraw = {}

    for i = 1, 52 do
        local transform = self:getNumberTransform(i, selectedNumber)

        if transform.isVisible then
            table.insert(numbersToDraw, {
                number = i,
                transform = transform
            })
        end
    end

    -- Sort by draw order (back to front)
    table.sort(numbersToDraw, function(a, b)
        return a.transform.drawOrder < b.transform.drawOrder
    end)

    -- Draw numbers in correct order
    for _, numberData in ipairs(numbersToDraw) do
        local transform = numberData.transform
        self:drawNumber(numberData.number, transform.x, transform.y, transform.scale, transform.opacity)
    end

    -- Draw selection indicator (subtle arrows or brackets around selected number)
    self:drawSelectionIndicator(selectedNumber)

    -- Draw position indicator
    self:drawPositionIndicator(selectedNumber)
end

-- Draw visual indicator for the selected number
function NumberDialRenderer:drawSelectionIndicator(selectedNumber)
    -- Get position of selected number (should be at top)
    local transform = self:getNumberTransform(selectedNumber, selectedNumber)

    -- Draw pointing arrows on both sides
    local arrowOffset = 35
    local arrowSize = 8

    -- Left arrow pointing right
    gfx.setLineWidth(2)
    gfx.drawLine(
        transform.x - arrowOffset,
        transform.y,
        transform.x - arrowOffset + arrowSize,
        transform.y - arrowSize
    )
    gfx.drawLine(
        transform.x - arrowOffset,
        transform.y,
        transform.x - arrowOffset + arrowSize,
        transform.y + arrowSize
    )

    -- Right arrow pointing left
    gfx.drawLine(
        transform.x + arrowOffset,
        transform.y,
        transform.x + arrowOffset - arrowSize,
        transform.y - arrowSize
    )
    gfx.drawLine(
        transform.x + arrowOffset,
        transform.y,
        transform.x + arrowOffset - arrowSize,
        transform.y + arrowSize
    )
    gfx.setLineWidth(1)
end

-- Draw position indicator showing which number is selected
function NumberDialRenderer:drawPositionIndicator(selectedNumber)
    -- Draw dots or tick marks around the dial perimeter
    local indicatorRadius = self.radius + 30
    local dotSize = 2

    -- Draw small dots for a subset of number positions to avoid clutter
    -- Show dots for every 4th number, plus numbers adjacent to selected
    for i = 1, 52 do
        local shouldShowDot = false

        -- Show dot for selected number
        if i == selectedNumber then
            shouldShowDot = true
        -- Show dots for numbers adjacent to selected
        elseif math.abs(i - selectedNumber) <= 2 or
               math.abs(i - selectedNumber) >= 50 then  -- Handle wrap-around
            shouldShowDot = true
        -- Show dots for every 13th number (quarters of 52)
        elseif i % 13 == 1 then
            shouldShowDot = true
        end

        if shouldShowDot then
            local degreesPerNumber = 360 / 52
            local angle = (i - 1) * degreesPerNumber + self.currentRotation
            local radians = math.rad(angle)

            local x = self.centerX + math.sin(radians) * indicatorRadius
            local y = self.centerY + math.cos(radians) * indicatorRadius * 0.6

            if i == selectedNumber then
                -- Larger dot for selected position
                gfx.fillCircleAtPoint(x, y, dotSize * 2)
            else
                -- Smaller dots for other positions
                gfx.fillCircleAtPoint(x, y, dotSize)
            end
        end
    end
end

-- Draw dial frame/background
function NumberDialRenderer:drawFrame()
    -- Draw solid circular guide for better contrast
    gfx.setLineWidth(1)
    -- Use solid line instead of dithered pattern for better visibility
    gfx.drawEllipseAtPoint(
        self.centerX,
        self.centerY,
        self.radius + 20,
        (self.radius + 20) * 0.6
    )

    -- Draw number range indicators at cardinal points
    gfx.setFont()

    -- Draw number range indicators with white background for better readability
    -- Top indicator
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(self.centerX - 20, 15, 40, 15)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(self.centerX - 20, 15, 40, 15)
    gfx.drawTextAligned("1-13", self.centerX, 18, kTextAlignment.center)

    -- Right indicator
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(self.centerX + 80, self.centerY - 7, 45, 15)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(self.centerX + 80, self.centerY - 7, 45, 15)
    gfx.drawTextAligned("14-26", self.centerX + 102, self.centerY - 4, kTextAlignment.center)

    -- Bottom indicator
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(self.centerX - 20, 195, 45, 15)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(self.centerX - 20, 195, 45, 15)
    gfx.drawTextAligned("27-39", self.centerX, 198, kTextAlignment.center)

    -- Left indicator
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(self.centerX - 125, self.centerY - 7, 45, 15)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(self.centerX - 125, self.centerY - 7, 45, 15)
    gfx.drawTextAligned("40-52", self.centerX - 102, self.centerY - 4, kTextAlignment.center)
end

return NumberDialRenderer
