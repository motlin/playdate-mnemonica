import "CoreLibs/graphics"
import "CoreLibs/ui"

import "App"
import "SceneManager"
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
local gameState <const> = App.gameState

function playdate.update()
    SceneManager.update()
end

-- The system menu, a locked device, and quitting all stop the quiz clock and save progress
function playdate.gameWillPause() gameState:suspend() end
function playdate.gameWillResume() gameState:unsuspend() end
function playdate.deviceWillLock() gameState:suspend() end
function playdate.deviceDidUnlock() gameState:unsuspend() end
function playdate.deviceWillSleep() gameState:suspend() end
function playdate.gameWillTerminate() gameState:suspend() end

math.randomseed(pd.getSecondsSinceEpoch())

-- 30 FPS is optimal for Playdate
pd.display.setRefreshRate(30)

gameState:loadHighScores()
gameState:loadSettings()
MenuScene.selection = gameState.lastSelectedMenuMode
SceneManager.onSwitch = SystemMenu.refresh
SceneManager.switch(MenuScene)
