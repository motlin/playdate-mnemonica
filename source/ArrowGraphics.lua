-- ArrowGraphics.lua
-- Provides arrow graphics for UI elements

local gfx <const> = playdate.graphics

local ArrowGraphics = {}

function ArrowGraphics:init()
    self.arrows = {}

    -- Create arrow images programmatically
    self:createArrows()

    return self
end

function ArrowGraphics:createArrows()
    -- Right arrow (→)
    local rightArrow = gfx.image.new(12, 7)
    gfx.pushContext(rightArrow)
    gfx.setColor(gfx.kColorBlack)
    -- Arrow shaft
    gfx.drawLine(0, 3, 8, 3)
    -- Arrow head
    gfx.drawLine(8, 3, 6, 1)
    gfx.drawLine(8, 3, 6, 5)
    gfx.popContext()
    self.arrows.right = rightArrow

    -- Left arrow (←)
    local leftArrow = gfx.image.new(12, 7)
    gfx.pushContext(leftArrow)
    gfx.setColor(gfx.kColorBlack)
    -- Arrow shaft
    gfx.drawLine(3, 3, 11, 3)
    -- Arrow head
    gfx.drawLine(3, 3, 5, 1)
    gfx.drawLine(3, 3, 5, 5)
    gfx.popContext()
    self.arrows.left = leftArrow

    -- Up arrow (↑)
    local upArrow = gfx.image.new(7, 12)
    gfx.pushContext(upArrow)
    gfx.setColor(gfx.kColorBlack)
    -- Arrow shaft
    gfx.drawLine(3, 3, 3, 11)
    -- Arrow head
    gfx.drawLine(3, 3, 1, 5)
    gfx.drawLine(3, 3, 5, 5)
    gfx.popContext()
    self.arrows.up = upArrow

    -- Down arrow (↓)
    local downArrow = gfx.image.new(7, 12)
    gfx.pushContext(downArrow)
    gfx.setColor(gfx.kColorBlack)
    -- Arrow shaft
    gfx.drawLine(3, 0, 3, 8)
    -- Arrow head
    gfx.drawLine(3, 8, 1, 6)
    gfx.drawLine(3, 8, 5, 6)
    gfx.popContext()
    self.arrows.down = downArrow

    -- Double arrow (→) for menu items
    local doubleArrow = gfx.image.new(16, 7)
    gfx.pushContext(doubleArrow)
    gfx.setColor(gfx.kColorBlack)
    -- First arrow
    gfx.drawLine(0, 3, 6, 3)
    gfx.drawLine(4, 1, 6, 3)
    gfx.drawLine(4, 5, 6, 3)
    -- Second arrow
    gfx.drawLine(8, 3, 14, 3)
    gfx.drawLine(12, 1, 14, 3)
    gfx.drawLine(12, 5, 14, 3)
    gfx.popContext()
    self.arrows.double = doubleArrow
end

-- Draw an arrow at the specified position
function ArrowGraphics:drawArrow(type, x, y)
    local arrow = self.arrows[type]
    if arrow then
        arrow:draw(x, y)
    end
end

-- Draw an arrow inline with text (returns width consumed)
function ArrowGraphics:drawInlineArrow(type, x, y)
    local arrow = self.arrows[type]
    if arrow then
        -- Adjust y position to center with text baseline
        arrow:draw(x, y - 2)
        return arrow:getSize()
    end
    return 0
end

return ArrowGraphics
