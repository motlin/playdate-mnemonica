-- DialRenderer module for rotating dial visualization
-- Creates an alarm clock-style rotating dial for card selection

local pd <const> = playdate
local gfx <const> = playdate.graphics

local DialRenderer = {}
DialRenderer.__index = DialRenderer

function DialRenderer:new(cardImages, cardWidth, cardHeight)
    local renderer = setmetatable({}, self)

    -- Store card rendering resources
    renderer.cardImages = cardImages
    renderer.cardWidth = cardWidth
    renderer.cardHeight = cardHeight

    -- Dial configuration
    renderer.centerX = 200  -- Center of the dial on screen
    renderer.centerY = 120  -- Vertical center for the dial
    renderer.radius = 80     -- Distance from center to card positions

    -- Visual configuration
    renderer.selectedScale = 1.2    -- Selected card is 20% larger
    renderer.minScale = 0.4         -- Minimum scale for distant cards
    renderer.maxVisibleCards = 9    -- Number of cards visible in the dial

    -- Animation state
    renderer.currentRotation = 0    -- Current rotation angle of the dial
    renderer.targetRotation = 0     -- Target rotation angle (for smooth animation)
    renderer.rotationSpeed = 0.15   -- Smoothing factor for rotation animation

    return renderer
end

-- Update the dial rotation based on selected card index
function DialRenderer:updateRotation(selectedCard, totalCards)
    -- Calculate the target rotation angle
    -- Each card occupies 360/52 degrees
    local degreesPerCard = 360 / totalCards

    -- Selected card should be at the top (0 degrees)
    -- So we rotate the dial backwards by the card's position
    self.targetRotation = -(selectedCard - 1) * degreesPerCard

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

-- Calculate position and scale for a card on the dial
function DialRenderer:getCardTransform(cardIndex, selectedCard, totalCards)
    local degreesPerCard = 360 / totalCards

    -- Calculate this card's angle on the dial
    local cardAngle = (cardIndex - 1) * degreesPerCard + self.currentRotation

    -- Normalize angle to 0-360
    while cardAngle < 0 do
        cardAngle = cardAngle + 360
    end
    while cardAngle >= 360 do
        cardAngle = cardAngle - 360
    end

    -- Convert to radians for trigonometry
    local radians = math.rad(cardAngle)

    -- Calculate position on an elliptical path
    -- Use ellipse to create depth effect (cards at bottom appear further away)
    local ellipseWidthRatio = 1.0   -- Horizontal radius multiplier
    local ellipseHeightRatio = 0.6  -- Vertical radius multiplier (squashed for perspective)

    local x = self.centerX + math.sin(radians) * self.radius * ellipseWidthRatio
    local y = self.centerY + math.cos(radians) * self.radius * ellipseHeightRatio

    -- Calculate scale based on vertical position (cards at top are larger)
    -- Use cosine for smooth scaling (1 at top, -1 at bottom)
    local depthFactor = (math.cos(radians) + 1) / 2  -- Normalize to 0-1 range
    local scale = self.minScale + (self.selectedScale - self.minScale) * depthFactor

    -- Extra emphasis on the selected card
    if cardIndex == selectedCard then
        scale = scale * 1.15  -- Make selected card even more prominent
        -- Slight position adjustment to pull selected card forward
        y = y - 10
    end

    -- Calculate opacity/visibility based on position
    -- Cards at the back (bottom) should be dimmer
    local opacity = 0.3 + (depthFactor * 0.7)  -- Range from 0.3 to 1.0

    -- Determine if card should be visible (limit number of visible cards)
    local distanceFromSelected = math.abs(cardIndex - selectedCard)

    -- Handle wrap-around distance
    if distanceFromSelected > totalCards / 2 then
        distanceFromSelected = totalCards - distanceFromSelected
    end

    local isVisible = distanceFromSelected <= math.floor(self.maxVisibleCards / 2)

    -- Calculate draw order (cards at back should be drawn first)
    local drawOrder = -math.cos(radians)  -- -1 to 1, where -1 is back, 1 is front

    return {
        x = x,
        y = y,
        scale = scale,
        opacity = opacity,
        isVisible = isVisible,
        drawOrder = drawOrder,
        angle = cardAngle
    }
end

-- Draw the rotating dial with cards
function DialRenderer:draw(uspccOrder, selectedCard, getCardImage, drawCardFunction)
    local totalCards = #uspccOrder

    -- Update rotation animation
    self:updateRotation(selectedCard, totalCards)

    -- Collect transform data for all visible cards
    local cardsToDraw = {}

    for i = 1, totalCards do
        local transform = self:getCardTransform(i, selectedCard, totalCards)

        if transform.isVisible then
            table.insert(cardsToDraw, {
                index = i,
                cardName = uspccOrder[i],
                transform = transform
            })
        end
    end

    -- Sort by draw order (back to front)
    table.sort(cardsToDraw, function(a, b)
        return a.transform.drawOrder < b.transform.drawOrder
    end)

    -- Draw cards in correct order
    for _, cardData in ipairs(cardsToDraw) do
        local transform = cardData.transform
        local cardName = cardData.cardName

        -- Apply dithering pattern for cards that aren't at the front
        if transform.opacity < 0.9 then
            -- Use Playdate's built-in dither patterns for depth effect
            local ditherLevel = math.floor((1 - transform.opacity) * 8)
            gfx.setDitherPattern(ditherLevel / 8, gfx.image.kDitherTypeBayer8x8)
        end

        -- Draw the card
        if drawCardFunction then
            drawCardFunction(cardName, transform.x, transform.y, transform.scale)
        else
            -- Fallback drawing
            local cardImage = getCardImage(cardName)
            if cardImage then
                local scaledImage = cardImage:scaledImage(transform.scale)
                scaledImage:drawCentered(math.floor(transform.x), math.floor(transform.y))
            end
        end

        -- Reset dither pattern
        if transform.opacity < 0.9 then
            gfx.setDitherPattern(0)
        end
    end

    -- Draw selection indicator (subtle arrows or brackets around selected card)
    self:drawSelectionIndicator(selectedCard, totalCards)

    -- Draw card position indicator
    self:drawPositionIndicator(selectedCard, totalCards)
end

-- Draw visual indicator for the selected card
function DialRenderer:drawSelectionIndicator(selectedCard, totalCards)
    -- Get position of selected card (should be at top)
    local transform = self:getCardTransform(selectedCard, selectedCard, totalCards)

    -- Draw brackets or arrows around selected card
    local bracketWidth = 60
    local bracketHeight = 80
    local bracketOffset = 10

    -- Left bracket
    gfx.drawLine(
        transform.x - bracketWidth/2 - bracketOffset,
        transform.y - bracketHeight/2,
        transform.x - bracketWidth/2 - bracketOffset,
        transform.y + bracketHeight/2
    )
    gfx.drawLine(
        transform.x - bracketWidth/2 - bracketOffset,
        transform.y - bracketHeight/2,
        transform.x - bracketWidth/2 - bracketOffset + 10,
        transform.y - bracketHeight/2
    )
    gfx.drawLine(
        transform.x - bracketWidth/2 - bracketOffset,
        transform.y + bracketHeight/2,
        transform.x - bracketWidth/2 - bracketOffset + 10,
        transform.y + bracketHeight/2
    )

    -- Right bracket
    gfx.drawLine(
        transform.x + bracketWidth/2 + bracketOffset,
        transform.y - bracketHeight/2,
        transform.x + bracketWidth/2 + bracketOffset,
        transform.y + bracketHeight/2
    )
    gfx.drawLine(
        transform.x + bracketWidth/2 + bracketOffset,
        transform.y - bracketHeight/2,
        transform.x + bracketWidth/2 + bracketOffset - 10,
        transform.y - bracketHeight/2
    )
    gfx.drawLine(
        transform.x + bracketWidth/2 + bracketOffset,
        transform.y + bracketHeight/2,
        transform.x + bracketWidth/2 + bracketOffset - 10,
        transform.y + bracketHeight/2
    )
end

-- Draw position indicator showing which card is selected
function DialRenderer:drawPositionIndicator(selectedCard, totalCards)
    -- Draw dots or tick marks around the dial perimeter
    local indicatorRadius = self.radius + 30
    local dotSize = 2

    -- Draw small dots for each card position
    for i = 1, totalCards do
        local degreesPerCard = 360 / totalCards
        local angle = (i - 1) * degreesPerCard + self.currentRotation
        local radians = math.rad(angle)

        local x = self.centerX + math.sin(radians) * indicatorRadius
        local y = self.centerY + math.cos(radians) * indicatorRadius * 0.6

        if i == selectedCard then
            -- Larger dot for selected position
            gfx.fillCircleAtPoint(x, y, dotSize * 2)
        elseif math.abs(i - selectedCard) <= 2 or
               math.abs(i - selectedCard) >= totalCards - 2 then
            -- Smaller dots for nearby positions
            gfx.fillCircleAtPoint(x, y, dotSize)
        end
    end
end

-- Draw dial frame/background
function DialRenderer:drawFrame()
    -- Draw subtle circular guide
    gfx.setLineWidth(1)
    gfx.setPattern({0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55})
    gfx.drawEllipseAtPoint(
        self.centerX,
        self.centerY,
        self.radius + 20,
        (self.radius + 20) * 0.6
    )
    gfx.setPattern({})
    gfx.setLineWidth(1)
end

return DialRenderer
