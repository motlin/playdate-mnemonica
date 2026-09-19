-- Results of a finished quiz, with the choice of what to do next.

import "App"
import "Assets"
import "SceneManager"
import "UIHelpers"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

SummaryScene = {
    selectedOption = 1,
    REVIEW_MISTAKES_OPTION = 2
}

local PLAY_AGAIN <const> = "Play Again"
local REVIEW_MISTAKES <const> = "Review Mistakes"
local MAIN_MENU <const> = "Main Menu"

local function getOptions()
    if #gameState:getMistakes() > 0 then
        return { PLAY_AGAIN, REVIEW_MISTAKES, MAIN_MENU }
    end
    -- TODO: a perfect score should offer Main Menu too
    return { PLAY_AGAIN }
end

local function drawHeading(text, y)
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned(text, 200, y, kTextAlignment.center)
    gfx.setFont()
end

local function draw()
    gfx.clear()

    local isNewBest = gameState.lastResult.isNewBest
    local previousBest = gameState.lastResult.previousBest

    drawHeading(isNewBest and "NEW HIGH SCORE!" or "Quiz Complete!", 10)
    drawHeading("Score: " .. gameState:getScore() .. "/52", 35)

    gfx.drawTextAligned(gameState:getScorePercentage() .. "% correct", 200, 55, kTextAlignment.center)
    gfx.drawTextAligned("Time: " .. gameState:getFormattedTime(), 200, 70, kTextAlignment.center)

    local showPreviousBest = previousBest and not isNewBest
    if showPreviousBest then
        gfx.drawTextAligned("-- Previous Best --", 200, 90, kTextAlignment.center)
        local bestMinutes = math.floor(previousBest.bestTime / 60)
        local bestSeconds = math.floor(previousBest.bestTime % 60)
        local bestScoreText = string.format("Best: %d/52 (%d:%02d)", previousBest.bestScore, bestMinutes, bestSeconds)
        gfx.drawTextAligned(bestScoreText, 200, 105, kTextAlignment.center)
    end

    local mistakes = gameState:getMistakes()
    local mistakesSectionY = showPreviousBest and 120 or 95
    local previewCount = math.min(3, #mistakes)
    if #mistakes > 0 then
        gfx.drawTextAligned("-- Mistakes: " .. #mistakes .. " --", 200, mistakesSectionY, kTextAlignment.center)

        for i = 1, previewCount do
            local mistake = mistakes[i]
            local mistakeText = "Pos " .. mistake.position .. ": " .. mistake.correctAnswer
                .. " (you: " .. mistake.userAnswer .. ")"
            gfx.drawText(mistakeText, 40, mistakesSectionY + (i * 15))
        end

        if #mistakes > 3 then
            gfx.drawTextAligned("... and " .. (#mistakes - 3) .. " more", 200, mistakesSectionY + (4 * 15), kTextAlignment.center)
        end
    else
        gfx.drawTextAligned("-- Perfect Score! --", 200, mistakesSectionY, kTextAlignment.center)
    end

    local menuY = mistakesSectionY + previewCount * 15 + 25
    for i, option in ipairs(getOptions()) do
        local y = menuY + ((i - 1) * 20)
        UIHelpers.drawMenuItem(option, 200, y, 200, i == SummaryScene.selectedOption)
    end

    gfx.drawTextAligned("Up/Down: Select | A: Confirm", 200, 220, kTextAlignment.center)
end

-- Returning from the mistakes list passes the option to keep selected.
function SummaryScene.enter(selectedOption)
    SummaryScene.selectedOption = selectedOption or 1
end

function SummaryScene.update()
    draw()

    local options = getOptions()

    if pd.buttonJustPressed(pd.kButtonUp) then
        Assets.playSound(sounds.menuMove)
        SummaryScene.selectedOption = SummaryScene.selectedOption - 1
        if SummaryScene.selectedOption < 1 then
            SummaryScene.selectedOption = #options
        end
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        Assets.playSound(sounds.menuMove)
        SummaryScene.selectedOption = SummaryScene.selectedOption + 1
        if SummaryScene.selectedOption > #options then
            SummaryScene.selectedOption = 1
        end
    elseif pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)

        local option = options[SummaryScene.selectedOption]
        if option == PLAY_AGAIN then
            QuizScene.start(gameState.currentMode)
        elseif option == REVIEW_MISTAKES then
            SceneManager.switch(MistakeListScene)
        else
            SceneManager.switch(MenuScene)
        end
    end
end
