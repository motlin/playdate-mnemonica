import "CoreLibs/graphics"
import "CoreLibs/ui"

import "App"
import "SceneManager"
import "SharedState"
import "SystemMenu"
import "scenes/Menu"
import "scenes/Quiz"
import "scenes/Feedback"
import "scenes/Summary"
import "scenes/MistakeList"
import "scenes/MistakeStudy"
import "scenes/MistakeReviewComplete"
import "scenes/Study"
import "scenes/Simon"
import "scenes/HighScores"
import "scenes/Settings"
import "scenes/Credits"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState

function playdate.update()
    if gameState.isPaused then
        gfx.clear()
        gfx.drawTextAligned("PAUSED", 200, 100, kTextAlignment.center)
        gfx.drawTextAligned("Press Menu to resume", 200, 130, kTextAlignment.center)
        return
    end

    SceneManager.update()
end

math.randomseed(pd.getSecondsSinceEpoch())

-- 30 FPS is optimal for Playdate
pd.display.setRefreshRate(30)

gameState:loadHighScores()
gameState:loadSettings()
MenuScene.selection = gameState.lastSelectedMenuMode
SharedState.lastCrankPosition = pd.getCrankPosition()
SceneManager.switch(MenuScene)
SystemMenu.refresh()
