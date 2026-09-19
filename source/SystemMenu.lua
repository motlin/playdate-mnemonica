-- Items in the Playdate system menu. They depend on the current mode and settings, so call
-- SystemMenu.refresh() after changing either.

import "App"
import "Assets"
import "SceneManager"
import "SharedState"

local pd <const> = playdate
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

SystemMenu = {}

local menu = pd.getSystemMenu()

local function restartQuiz()
    local mode = gameState.currentMode
    if mode == GameState.MODES.MENU then
        mode = GameState.MODES.QUIZ_NUMBER_TO_CARD
    end

    if mode == GameState.MODES.QUIZ_NUMBER_TO_CARD or mode == GameState.MODES.QUIZ_CARD_TO_NUMBER then
        QuizScene.start(mode)
    else
        -- Outside a quiz the new session is never shown, but starting it still unpauses the game
        gameState:startQuiz(mode)
        SharedState.lastCrankPosition = pd.getCrankPosition()
    end
end

function SystemMenu.refresh()
    menu:removeAllMenuItems()

    -- Don't show pause/resume in menu mode, study mode, or settings mode
    if gameState.currentMode ~= GameState.MODES.MENU and
       gameState.currentMode ~= GameState.MODES.STUDY and
       gameState.currentMode ~= GameState.MODES.SETTINGS then
        if gameState.isPaused then
            menu:addMenuItem("Resume", function()
                Assets.playSound(sounds.buttonPress)
                gameState:resume()
                SystemMenu.refresh()
            end)
        else
            menu:addMenuItem("Pause", function()
                Assets.playSound(sounds.buttonPress)
                gameState:pause()
                SystemMenu.refresh()
            end)
        end

        menu:addMenuItem("Restart Quiz", function()
            Assets.playSound(sounds.buttonPress)
            restartQuiz()
            SystemMenu.refresh()
        end)

        menu:addMenuItem("Main Menu", function()
            Assets.playSound(sounds.buttonPress)
            SceneManager.switch(MenuScene)
            SystemMenu.refresh()
        end)
    end

    local soundLabel = gameState.soundEnabled and "Sound: On" or "Sound: Off"
    menu:addMenuItem(soundLabel, function()
        gameState.soundEnabled = not gameState.soundEnabled
        gameState:saveSettings()
        -- Confirm with a sound if sound was just enabled
        Assets.playSound(sounds.buttonPress)
        SystemMenu.refresh()
    end)

    menu:addMenuItem("Reset Statistics", function()
        Assets.playSound(sounds.buttonPress)
        gameState:resetCardStats()
        SystemMenu.refresh()
    end)
end
