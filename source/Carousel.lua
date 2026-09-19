-- Draws a wrapping list as a horizontal strip that slides to the selection, with a rail
-- underneath showing where the selection sits in the whole list.

import "CoreLibs/graphics"
import "CarouselLayout"

local gfx <const> = playdate.graphics

Carousel = {}
Carousel.__index = Carousel

local SCROLL_FRACTION <const> = 0.45
local RAIL_MAX_TICK_SPACING <const> = 4
local RAIL_SIDE_MARGIN <const> = 10
local RAIL_TICK_HEIGHT <const> = 3
local RAIL_GROUP_TICK_HEIGHT <const> = 7
local RAIL_MARKER_SIZE <const> = 4

-- `area` is { centerX, centerY, halfWidth, railY }. `drawItem(index, x, y, scale)` draws one
-- item centred at x, y. `groupSize` puts a taller rail tick at the start of every group.
function Carousel:new(itemCount, groupSize, area, drawItem)
    local carousel = setmetatable({}, self)
    carousel.itemCount = itemCount
    carousel.groupSize = groupSize
    carousel.area = area
    carousel.drawItem = drawItem
    carousel.scrollPosition = 1
    -- The rail shrinks its tick spacing to fit inside a narrow area
    local railRoom = area.halfWidth * 2 - RAIL_SIDE_MARGIN * 2
    carousel.tickSpacing = math.min(RAIL_MAX_TICK_SPACING, railRoom // (itemCount - 1))
    return carousel
end

function Carousel:drawRail()
    local area = self.area
    local railWidth = (self.itemCount - 1) * self.tickSpacing
    local railLeft = area.centerX - railWidth // 2

    gfx.setColor(gfx.kColorBlack)
    for item = 1, self.itemCount do
        local x = railLeft + (item - 1) * self.tickSpacing
        local isGroupStart = (item - 1) % self.groupSize == 0
        local height = isGroupStart and RAIL_GROUP_TICK_HEIGHT or RAIL_TICK_HEIGHT
        gfx.drawLine(x, area.railY, x, area.railY - height)
    end

    local markerItem = (self.scrollPosition - 1) % self.itemCount
    local markerX = math.floor(railLeft + markerItem * self.tickSpacing + 0.5)
    local markerTop = area.railY + 2
    gfx.fillTriangle(
        markerX, markerTop,
        markerX - RAIL_MARKER_SIZE, markerTop + RAIL_MARKER_SIZE + 1,
        markerX + RAIL_MARKER_SIZE, markerTop + RAIL_MARKER_SIZE + 1
    )
end

function Carousel:draw(selection)
    local area = self.area
    self.scrollPosition = CarouselLayout.approach(self.scrollPosition, selection, SCROLL_FRACTION, self.itemCount)

    gfx.setClipRect(area.centerX - area.halfWidth, 0, area.halfWidth * 2, 240)
    local items = CarouselLayout.visibleItems(self.scrollPosition, self.itemCount, area.centerX, area.halfWidth + 50)
    for _, item in ipairs(items) do
        self.drawItem(item.index, item.x, area.centerY, item.scale)
    end
    gfx.clearClipRect()

    self:drawRail()
end
