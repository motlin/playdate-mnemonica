import "App"
import "Assets"
import "SceneManager"
import "Layout"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

local SOUND <const> = 1
local CRANK_SENSITIVITY <const> = 2
local RESET_STATISTICS <const> = 3
local RESET_HIGH_SCORES <const> = 4
local CREDITS <const> = 5
local BACK_TO_MENU <const> = 6
local ITEM_COUNT <const> = 6

SettingsScene = {
    selection = SOUND,
    CREDITS = CREDITS,
}

-- The reset row waiting for a second A press, if any. Resets cannot be undone.
local armedReset

local FOOTER_HINTS <const> = { { button = "A", label = "Select" }, { button = "B", label = "Menu" } }
local CONFIRM_HINTS <const> = { { button = "A", label = "Yes, reset" }, { button = "B", label = "Cancel" } }

local function resetLabel(item, label) return armedReset == item and "Really reset?" or label end

local function draw()
    gfx.clear()
    Layout.drawTitleBar("Settings")

    local sensitivity = string.format("%.1f", gameState.crankSensitivity)
    if SettingsScene.selection == CRANK_SENSITIVITY then sensitivity = "< " .. sensitivity .. " >" end

    Layout.drawList({
        "Sound  " .. (gameState.soundEnabled and "on" or "off"),
        "Crank sensitivity  " .. sensitivity,
        resetLabel(RESET_STATISTICS, "Reset statistics"),
        resetLabel(RESET_HIGH_SCORES, "Reset high scores"),
        "Credits",
        "Back to menu",
    }, SettingsScene.selection, 33, 30)

    Layout.drawFooter(armedReset and CONFIRM_HINTS or FOOTER_HINTS, false)
end

-- First A arms the reset, second A performs it.
local function confirmReset(item, reset)
    if armedReset == item then
        reset()
        armedReset = nil
    else
        armedReset = item
    end
end

local function adjustCrankSensitivity(change)
    if SettingsScene.selection ~= CRANK_SENSITIVITY then return end

    gameState.crankSensitivity = math.min(3.0, math.max(0.1, gameState.crankSensitivity + change))
    gameState:saveSettings()
    Assets.playSound(sounds.buttonPress)
end

-- Returning from a sub-screen passes the item to keep selected.
function SettingsScene.enter(selection)
    gameState.currentMode = GameState.MODES.SETTINGS
    armedReset = nil
    SettingsScene.selection = selection or SOUND
end

function SettingsScene.update()
    draw()

    -- B backs out of a pending reset instead of leaving the screen
    if armedReset and pd.buttonJustPressed(pd.kButtonB) then
        Assets.playSound(sounds.buttonPress)
        armedReset = nil
        return
    end

    if pd.buttonJustPressed(pd.kButtonUp) then
        Assets.playSound(sounds.menuMove)
        armedReset = nil
        SettingsScene.selection = SettingsScene.selection - 1
        if SettingsScene.selection < 1 then SettingsScene.selection = ITEM_COUNT end
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        Assets.playSound(sounds.menuMove)
        armedReset = nil
        SettingsScene.selection = SettingsScene.selection + 1
        if SettingsScene.selection > ITEM_COUNT then SettingsScene.selection = 1 end
    elseif pd.buttonJustPressed(pd.kButtonLeft) then
        adjustCrankSensitivity(-0.1)
    elseif pd.buttonJustPressed(pd.kButtonRight) then
        adjustCrankSensitivity(0.1)
    elseif pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)

        if SettingsScene.selection == SOUND then
            gameState.soundEnabled = not gameState.soundEnabled
            gameState:saveSettings()
        elseif SettingsScene.selection == RESET_STATISTICS then
            confirmReset(RESET_STATISTICS, function() gameState:resetCardStats() end)
        elseif SettingsScene.selection == RESET_HIGH_SCORES then
            confirmReset(RESET_HIGH_SCORES, function() gameState:resetHighScores() end)
        elseif SettingsScene.selection == CREDITS then
            SceneManager.switch(CreditsScene)
        elseif SettingsScene.selection == BACK_TO_MENU then
            SceneManager.switch(MenuScene)
        end
    elseif pd.buttonJustPressed(pd.kButtonB) then
        Assets.playSound(sounds.buttonPress)
        SceneManager.switch(MenuScene)
    end
end
