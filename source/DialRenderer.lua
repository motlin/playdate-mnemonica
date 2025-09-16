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
    renderer.centerY = 100  -- Vertical center for the dial (moved up for better layout)
    renderer.radius = 90     -- Distance from center to card positions (increased to prevent overlap)

    -- Visual configuration
    renderer.selectedScale = 1.0    -- Selected card at normal size (reduced to prevent overlap)
    renderer.minScale = 0.3         -- Minimum scale for distant cards (smaller to save space)
    renderer.maxVisibleCards = 7    -- Number of cards visible in the dial (reduced to prevent overlap)

    -- Animation state
    renderer.currentRotation = 0    -- Current rotation angle of the dial
    renderer.targetRotation = 0     -- Target rotation angle (for smooth animation)
    renderer.rotationSpeed = 0.2    -- Smoothing factor for rotation animation (optimized for responsive feel)

    -- Performance optimization: cache transform calculations with size limit
    renderer.transformCache = {}
    renderer.maxCacheSize = 5  -- Limit cache to prevent memory bloat
    renderer.lastCacheRotation = -999  -- Force initial cache refresh
    renderer.cacheThreshold = 1.0  -- Degrees of rotation change before refreshing cache

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
    local ellipseWidthRatio = 1.4   -- Horizontal radius multiplier (increased for better horizontal spacing)
    local ellipseHeightRatio = 0.5  -- Vertical radius multiplier (reduced for flatter ellipse)

    local x = self.centerX + math.sin(radians) * self.radius * ellipseWidthRatio
    local y = self.centerY + math.cos(radians) * self.radius * ellipseHeightRatio

    -- Calculate scale based on vertical position (cards at top are larger)
    -- Use cosine for smooth scaling (1 at top, -1 at bottom)
    local depthFactor = (math.cos(radians) + 1) / 2  -- Normalize to 0-1 range
    local scale = self.minScale + (self.selectedScale - self.minScale) * depthFactor

    -- Extra emphasis on the selected card
    if cardIndex == selectedCard then
        scale = scale * 1.1  -- Make selected card slightly more prominent (reduced from 1.15)
        -- Slight position adjustment to pull selected card forward
        y = y - 8  -- Reduced from 10 to keep cards aligned better
    end

    -- Calculate opacity/visibility based on position
    -- Cards at the back (bottom) should be dimmer
    -- Increased minimum opacity for better contrast on 1-bit display
    local opacity = 0.5 + (depthFactor * 0.5)  -- Range from 0.5 to 1.0

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

    -- Check if we need to refresh the transform cache
    local rotationChange = math.abs(self.currentRotation - self.lastCacheRotation)
    local shouldRefreshCache = rotationChange >= self.cacheThreshold or not self.transformCache[selectedCard]

    local cardsToDraw = {}

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
        self.transformCache[selectedCard] = {}
        self.lastCacheRotation = self.currentRotation

        for i = 1, totalCards do
            local transform = self:getCardTransform(i, selectedCard, totalCards)
            self.transformCache[selectedCard][i] = transform

            if transform.isVisible then
                table.insert(cardsToDraw, {
                    index = i,
                    cardName = uspccOrder[i],
                    transform = transform
                })
            end
        end
    else
        -- Use cached transforms
        for i = 1, totalCards do
            local transform = self.transformCache[selectedCard][i]
            if transform and transform.isVisible then
                table.insert(cardsToDraw, {
                    index = i,
                    cardName = uspccOrder[i],
                    transform = transform
                })
            end
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

        -- Apply dithering pattern for cards that aren't at the front (reduced for performance)
        if transform.opacity < 0.7 then  -- Raised threshold to reduce dithering frequency
            local ditherLevel = math.floor((1 - transform.opacity) * 2)  -- Reduced from 4 to 2
            gfx.setDitherPattern(ditherLevel / 8, gfx.image.kDitherTypeBayer4x4)
        end

        -- Draw the card
        if drawCardFunction then
            drawCardFunction(cardName, math.floor(transform.x), math.floor(transform.y), transform.scale)
        else
            -- Fallback drawing
            local cardImage = getCardImage(cardName)
            if cardImage then
                local scaledImage = cardImage:scaledImage(transform.scale)
                scaledImage:drawCentered(math.floor(transform.x), math.floor(transform.y))
            end
        end

        -- Reset dither pattern
        if transform.opacity < 0.7 then
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
    local bracketWidth = 50  -- Reduced from 60 to match smaller cards
    local bracketHeight = 65  -- Reduced from 80 to match smaller cards
    local bracketOffset = 8   -- Reduced from 10 for tighter brackets

    -- Use thicker lines for better visibility
    gfx.setLineWidth(2)

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

    -- Reset line width
    gfx.setLineWidth(1)
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
    -- Draw solid circular guide for better contrast
    gfx.setLineWidth(1)
    -- Use solid line instead of dithered pattern for better visibility
    local width = (self.radius + 20) * 2
    local height = (self.radius + 20) * 0.6 * 2
    gfx.drawEllipseInRect(
        self.centerX - width / 2,
        self.centerY - height / 2,
        width,
        height
    )
end

return DialRenderer
