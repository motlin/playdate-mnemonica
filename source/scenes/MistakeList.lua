-- Scrollable list of a finished quiz's mistakes, and the way into reviewing them.

import "App"
import "Assets"
import "Deck"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

MistakeListScene = {}

local scrollOffset = 0
local maxVisibleLines = 9

local function draw()
    gfx.clear()

    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Mistakes Review", 200, 10, kTextAlignment.center)
    gfx.setFont()

    local mistakes = gameState:getMistakes()
    gfx.drawTextAligned("Total: " .. #mistakes .. " mistakes", 200, 30, kTextAlignment.center)

    local startY = 50
    local lineHeight = 18

    for line = 1, math.min(#mistakes, maxVisibleLines) do
        local mistake = mistakes[line + scrollOffset]
        local y = startY + ((line - 1) * lineHeight)

        gfx.drawText("Pos " .. mistake.position .. ":", 20, y)

        if gameState.currentMode == GameState.MODES.QUIZ_NUMBER_TO_CARD then
            gfx.drawText(mistake.correctAnswer, 80, y)
        else
            gfx.drawText(Deck.mnemonicaStack[mistake.position] .. " -> " .. mistake.position, 80, y)
        end

        gfx.drawTextAligned("(you: " .. mistake.userAnswer .. ")", 380, y, kTextAlignment.right)
    end

    if scrollOffset > 0 then
        gfx.drawTextAligned("^ more", 200, startY - 10, kTextAlignment.center)
    end
    if scrollOffset + maxVisibleLines < #mistakes then
        gfx.drawTextAligned("v more", 200, startY + (maxVisibleLines * lineHeight), kTextAlignment.center)
    end

    gfx.drawTextAligned("B: Back | A: Start Review Quiz", 200, 220, kTextAlignment.center)
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
