-- Results of a finished quiz, with the choice of what to do next.

import "App"
import "Assets"
import "SceneManager"
import "Layout"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

SummaryScene = {
    selectedOption = 1,
    REVIEW_MISTAKES_OPTION = 2,
}

local PLAY_AGAIN <const> = "Play Again"
local REVIEW_MISTAKES <const> = "Review Mistakes"
local MAIN_MENU <const> = "Main Menu"

local function getOptions()
    if #gameState:getMistakes() > 0 then return { PLAY_AGAIN, REVIEW_MISTAKES, MAIN_MENU } end
    return { PLAY_AGAIN, MAIN_MENU }
end

local FOOTER_HINTS <const> = { { button = "A", label = "Select" } }

local function draw()
    gfx.clear()

    local isNewBest = gameState.lastResult.isNewBest
    local previousBest = gameState.lastResult.previousBest
    local mistakeCount = #gameState:getMistakes()

    Layout.drawTitleBar(isNewBest and "New best!" or "Quiz complete")

    Layout.drawLargeText(gameState:getScore() .. "/52", 200, 50)

    local details = gameState:getFormattedTime()
    if mistakeCount == 0 then
        details = details .. "  -  perfect score"
    elseif mistakeCount == 1 then
        details = details .. "  -  1 mistake"
    else
        details = details .. "  -  " .. mistakeCount .. " mistakes"
    end
    gfx.drawTextAligned(details, 200, 74, kTextAlignment.center)

    if previousBest then
        local label = isNewBest and "Beat " or "Best "
        local bestText = label .. previousBest.bestScore .. "/52 in " .. Layout.formatTime(previousBest.bestTime)
        gfx.drawTextAligned(bestText, 200, 96, kTextAlignment.center)
    end

    Layout.drawList(getOptions(), SummaryScene.selectedOption, 130, 28)
    Layout.drawFooter(FOOTER_HINTS, false)
end

-- Returning from the mistakes list passes the option to keep selected.
function SummaryScene.enter(selectedOption) SummaryScene.selectedOption = selectedOption or 1 end

function SummaryScene.update()
    draw()

    local options = getOptions()

    if pd.buttonJustPressed(pd.kButtonUp) then
        Assets.playSound(sounds.menuMove)
        SummaryScene.selectedOption = SummaryScene.selectedOption - 1
        if SummaryScene.selectedOption < 1 then SummaryScene.selectedOption = #options end
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        Assets.playSound(sounds.menuMove)
        SummaryScene.selectedOption = SummaryScene.selectedOption + 1
        if SummaryScene.selectedOption > #options then SummaryScene.selectedOption = 1 end
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
