-- The control for answering with one of the 52 cards or one of the 52 positions:
-- a Picker for input plus a Carousel that draws the choices around the selection.

import "CoreLibs/graphics"
import "Assets"
import "Carousel"
import "Deck"
import "Layout"
import "Picker"

local gfx <const> = playdate.graphics

AnswerDial = {}
AnswerDial.__index = AnswerDial

local ITEM_COUNT <const> = 52
local RAIL_Y <const> = 206

-- The whole content band, for screens where the dial is the only thing in it.
AnswerDial.FULL_WIDTH = { centerX = 200, centerY = 114, halfWidth = 200, railY = RAIL_Y }
-- The right-hand side, leaving room for a double-size card on the left.
AnswerDial.RIGHT_SIDE = { centerX = 270, centerY = 114, halfWidth = 130, railY = RAIL_Y }

local function playTick()
    Assets.playSound(Assets.sounds.crankTick)
end

local function new(dpadSteps, groupSize, area, drawItem)
    local dial = setmetatable({}, AnswerDial)
    dial.picker = Picker:new(ITEM_COUNT, dpadSteps, playTick)
    dial.carousel = Carousel:new(ITEM_COUNT, groupSize, area, drawItem)
    return dial
end

-- Cards in new-deck order; Left/Right jump a suit, and the rail marks where each suit starts.
function AnswerDial.newCardDial(area)
    return new({ up = -1, down = 1, left = -13, right = 13 }, 13, area, function(index, x, y, scale)
        Assets.drawCard(Deck.uspccOrder[index], x, y, scale)
    end)
end

local TILE_WIDTH <const> = 50
local TILE_HEIGHT <const> = 40
local TILE_CORNER <const> = 4
local function drawNumberTile(number, x, y, scale)
    local width, height = TILE_WIDTH * scale, TILE_HEIGHT * scale
    gfx.setColor(gfx.kColorBlack)

    if scale == 2 then
        gfx.fillRoundRect(x - width / 2, y - height / 2, width, height, TILE_CORNER * scale)
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        Layout.drawLargeText(tostring(number), x, y)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    else
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(x - width / 2, y - height / 2, width, height, TILE_CORNER)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRoundRect(x - width / 2, y - height / 2, width, height, TILE_CORNER)
        gfx.setFont(Layout.boldFont)
        gfx.drawTextAligned(tostring(number), x, y - Layout.boldFont:getHeight() / 2, kTextAlignment.center)
        gfx.setFont()
    end
end

-- Positions 1-52; Left/Right jump ten, and the rail marks every tenth position.
function AnswerDial.newNumberDial(area)
    return new({ up = -1, down = 1, left = -10, right = 10 }, 10, area, drawNumberTile)
end

function AnswerDial:getSelection()
    return self.picker:getSelection()
end

function AnswerDial:select(index)
    self.picker:select(index)
end

function AnswerDial:update(sensitivity)
    self.picker:update(sensitivity)
end

function AnswerDial:draw()
    self.carousel:draw(self.picker:getSelection())
end
