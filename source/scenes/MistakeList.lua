-- Scrollable list of a finished quiz's mistakes, and the way into reviewing them.

import "App"
import "Layout"
import "Assets"
import "Deck"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

MistakeListScene = {}

local scrollOffset = 0
local maxVisibleLines = 8
local ROW_TOP <const> = 32
local ROW_HEIGHT <const> = 22
local FOOTER_HINTS <const> = { { button = "A", label = "Review these" }, { button = "B", label = "Back" } }

local function drawScrollArrow(y, pointsUp)
    local tip = pointsUp and y or y + 6
    local base = pointsUp and y + 6 or y
    gfx.fillTriangle(388, tip, 382, base, 394, base)
end

local function draw()
    gfx.clear()

    local mistakes = gameState:getMistakes()
    local lastVisible = math.min(#mistakes, scrollOffset + maxVisibleLines)
    Layout.drawTitleBar("Mistakes", nil, (scrollOffset + 1) .. "-" .. lastVisible .. " of " .. #mistakes)

    local answeredWithCard = gameState.currentMode == GameState.MODES.QUIZ_NUMBER_TO_CARD
    for line = 1, lastVisible - scrollOffset do
        local mistake = mistakes[line + scrollOffset]
        local y = ROW_TOP + (line - 1) * ROW_HEIGHT

        gfx.setFont(Layout.boldFont)
        gfx.drawText(mistake.position .. " is " .. Deck.mnemonicaStack[mistake.position], 24, y)
        gfx.setFont()

        local answer = answeredWithCard and mistake.userAnswer or ("position " .. mistake.userAnswer)
        gfx.drawTextAligned("you said " .. answer, 372, y, kTextAlignment.right)
    end

    gfx.setColor(gfx.kColorBlack)
    if scrollOffset > 0 then
        drawScrollArrow(ROW_TOP + 4, true)
    end
    if lastVisible < #mistakes then
        drawScrollArrow(ROW_TOP + maxVisibleLines * ROW_HEIGHT - 14, false)
    end

    Layout.drawFooter(FOOTER_HINTS, false)
end

function MistakeListScene.enter()
    scrollOffset = 0
end

function MistakeListScene.update()
    draw()

    if pd.buttonJustPressed(pd.kButtonUp) then
        Assets.playSound(sounds.buttonPress)
        scrollOffset = math.max(0, scrollOffset - 1)
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        Assets.playSound(sounds.buttonPress)
        local maxOffset = math.max(0, #gameState:getMistakes() - maxVisibleLines)
        scrollOffset = math.min(maxOffset, scrollOffset + 1)
    elseif pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)
        gameState:startMistakeReview()
        SceneManager.switch(MistakeStudyScene)
    elseif pd.buttonJustPressed(pd.kButtonB) then
        Assets.playSound(sounds.buttonPress)
        SceneManager.switch(SummaryScene, SummaryScene.REVIEW_MISTAKES_OPTION)
    end
end
