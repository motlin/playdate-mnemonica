import "App"
import "Assets"
import "SceneManager"
import "UIHelpers"

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
    CREDITS = CREDITS
}

local function draw()
    gfx.clear()

    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Settings", 200, 20, kTextAlignment.center)
    gfx.setFont()

    local settingsItems = {
        "Sound: " .. (gameState.soundEnabled and "On" or "Off"),
        "Crank Sensitivity: " .. string.format("%.1f", gameState.crankSensitivity),
        "Reset Statistics",
        "Reset High Scores",
        "Credits",
        "Back to Menu"
    }

    UIHelpers.drawMenuList(settingsItems, 200, 60, 300, SettingsScene.selection, 25)

    gfx.drawTextAligned("Up/Down: Select | A: Confirm", 200, 205, kTextAlignment.center)
    gfx.drawTextAligned("Left/Right: Adjust values | B: Back", 200, 220, kTextAlignment.center)
end

local function adjustCrankSensitivity(change)
    if SettingsScene.selection ~= CRANK_SENSITIVITY then
        return
    end

    gameState.crankSensitivity = math.min(3.0, math.max(0.1, gameState.crankSensitivity + change))
    gameState:saveSettings()
    Assets.playSound(sounds.buttonPress)
end

-- Returning from a sub-screen passes the item to keep selected.
function SettingsScene.enter(selection)
    gameState.currentMode = GameState.MODES.SETTINGS
    SettingsScene.selection = selection or SOUND
end

function SettingsScene.update()
    draw()

    if pd.buttonJustPressed(pd.kButtonUp) then
        Assets.playSound(sounds.menuMove)
        SettingsScene.selection = SettingsScene.selection - 1
        if SettingsScene.selection < 1 then SettingsScene.selection = ITEM_COUNT end
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        Assets.playSound(sounds.menuMove)
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
            gameState:resetCardStats()
        elseif SettingsScene.selection == RESET_HIGH_SCORES then
            gameState:resetHighScores()
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
