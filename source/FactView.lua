-- Draws the fact the game teaches, "position N is this card", the same way on every screen.

import "CoreLibs/graphics"
import "Assets"
import "Deck"
import "Layout"

local gfx <const> = playdate.graphics

FactView = {}

local LEFT_X <const> = 105
local RIGHT_X <const> = 285
local CARD_TOP <const> = Layout.CONTENT_TOP + 28
local CARD_CENTER_Y <const> = CARD_TOP + Assets.CARD_HEIGHT

-- "Position N" over its card at double size, centred on x.
function FactView.drawFact(position, x)
    gfx.setFont(Layout.boldFont)
    gfx.drawTextAligned("Position " .. position, x, Layout.CONTENT_TOP + 6, kTextAlignment.center)
    gfx.setFont()
    Assets.drawCard(Deck.mnemonicaStack[position], x, CARD_CENTER_Y, 2)
end

-- The wrong answer on the left, small, and the fact on the right, large.
-- `answeredWithCard` says whether `userAnswer` is a card name or a position.
function FactView.drawMistake(position, userAnswer, answeredWithCard)
    if answeredWithCard then
        gfx.drawTextAligned("You picked", LEFT_X, CARD_TOP + 2, kTextAlignment.center)
        Assets.drawCard(userAnswer, LEFT_X, CARD_CENTER_Y + 12, 1)
    else
        gfx.drawTextAligned("You said", LEFT_X, CARD_TOP + 22, kTextAlignment.center)
        Layout.drawLargeText(userAnswer, LEFT_X, CARD_CENTER_Y + 2)
    end

    FactView.drawFact(position, RIGHT_X)
end

-- The card at double size beside its position in large type, for browsing.
function FactView.drawStudyCard(position)
    Assets.drawCard(Deck.mnemonicaStack[position], 130, CARD_CENTER_Y - 14, 2)
    gfx.drawTextAligned("Position", 285, CARD_CENTER_Y - 54, kTextAlignment.center)
    Layout.drawLargeText(tostring(position), 285, CARD_CENTER_Y - 10)
end
