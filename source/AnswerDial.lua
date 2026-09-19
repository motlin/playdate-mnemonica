-- The control for answering with one of the 52 cards or one of the 52 positions:
-- a Picker for input plus the dial that draws the choices around the selection.

import "Assets"
import "Deck"
import "DialRenderer"
import "NumberDialRenderer"
import "Picker"

AnswerDial = {}
AnswerDial.__index = AnswerDial

local ITEM_COUNT <const> = 52

local function playTick()
    Assets.playSound(Assets.sounds.crankTick)
end

local function new(dpadSteps, renderer, drawRenderer)
    local dial = setmetatable({}, AnswerDial)
    dial.picker = Picker:new(ITEM_COUNT, dpadSteps, playTick)
    dial.renderer = renderer
    dial.drawRenderer = drawRenderer
    return dial
end

-- Cards in new-deck order; Left/Right jump a suit.
function AnswerDial.newCardDial()
    local renderer = DialRenderer:new(Assets.cardImages, Assets.CARD_WIDTH, Assets.CARD_HEIGHT)
    return new({ up = -1, down = 1, left = -13, right = 13 }, renderer, function(selection)
        renderer:draw(Deck.uspccOrder, selection, Assets.getCardImage, Assets.drawCard)
    end)
end

-- Positions 1-52; Left/Right jump ten.
function AnswerDial.newNumberDial()
    local renderer = NumberDialRenderer:new()
    return new({ up = -1, down = 1, left = -10, right = 10 }, renderer, function(selection)
        renderer:draw(selection)
    end)
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
    self.renderer:drawFrame()
    self.drawRenderer(self.picker:getSelection())
end
