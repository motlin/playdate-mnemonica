-- Items in the Playdate system menu, which holds at most three custom items.
-- Scenes that are part of a quiz in progress set `hasQuizInProgress` to get the quiz items.

import "App"
import "Assets"
import "SceneManager"

local pd <const> = playdate
local gameState <const> = App.gameState

SystemMenu = {}

local menu = pd.getSystemMenu()

function SystemMenu.refresh(scene)
    menu:removeAllMenuItems()

    if scene.hasQuizInProgress then
        menu:addMenuItem("Restart quiz", function()
            QuizScene.start(gameState:getQuizMode())
        end)

        menu:addMenuItem("Main menu", function()
            SceneManager.switch(MenuScene)
        end)
    end

    menu:addCheckmarkMenuItem("Sound", gameState.soundEnabled, function(isEnabled)
        gameState.soundEnabled = isEnabled
        gameState:saveSettings()
        Assets.playSound(Assets.sounds.buttonPress)
    end)
end
