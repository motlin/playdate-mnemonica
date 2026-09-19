import "CoreLibs/ui"
import "App"
import "Assets"
import "SceneManager"
import "SharedState"
import "UIHelpers"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

MenuScene = {
    selection = 1
}

local menuItems = {
    "Number to Card Quiz",
    "Card to Number Quiz",
    "Study Mode",
    "Simon Mode",
    "High Scores",
    "Settings"
}

-- Degrees the crank must favour a new item over the current one, to prevent flickering
local hysteresisThreshold = 15

local function updateSelectionWithCrank()
    local crankPosition = pd.getCrankPosition()  -- 0-359 degrees

    if math.abs(crankPosition - SharedState.lastCrankPosition) < 0.5 then
        return
    end

    local degreesPerItem = 360 / #menuItems
    local effectiveDegreesPerItem = degreesPerItem / gameState.crankSensitivity

    -- Add 0.5 to center each item in its range
    local targetSelection = math.floor((crankPosition / effectiveDegreesPerItem) + 0.5) + 1

    if targetSelection > #menuItems then targetSelection = targetSelection - #menuItems end
    if targetSelection < 1 then targetSelection = targetSelection + #menuItems end

    if targetSelection ~= MenuScene.selection then
        local currentCenter = ((MenuScene.selection - 1) * effectiveDegreesPerItem) % 360
        local targetCenter = ((targetSelection - 1) * effectiveDegreesPerItem) % 360

        local distanceToTarget = math.abs(crankPosition - targetCenter)
        if distanceToTarget > 180 then distanceToTarget = 360 - distanceToTarget end

        local distanceToCurrent = math.abs(crankPosition - currentCenter)
        if distanceToCurrent > 180 then distanceToCurrent = 360 - distanceToCurrent end

        -- Only switch when significantly closer to the new item, so each item is "sticky"
        if distanceToTarget < distanceToCurrent - hysteresisThreshold then
            MenuScene.selection = targetSelection
            Assets.playSound(sounds.menuMove)
        end
    end

    SharedState.lastCrankPosition = crankPosition
end

local function draw()
    gfx.clear()

    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Mnemonica Stack", 200, 10, kTextAlignment.center)
    gfx.drawTextAligned("Memorizer", 200, 25, kTextAlignment.center)

    gfx.setFont(gfx.getSystemFont())

    UIHelpers.drawMenuList(menuItems, 200, 55, 280, MenuScene.selection, 25)

    if pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
    end

    gfx.setFont()
    gfx.drawTextAligned("Crank or D-pad to select", 200, 195, kTextAlignment.center)
    gfx.drawTextAligned("(A) Start selected mode", 200, 210, kTextAlignment.center)
end

local function startSelectedMode()
    -- Remember the selection for next startup
    gameState.lastSelectedMenuMode = MenuScene.selection
    gameState:saveSettings()

    if MenuScene.selection == 1 then
        QuizScene.start(GameState.MODES.QUIZ_NUMBER_TO_CARD)
    elseif MenuScene.selection == 2 then
        QuizScene.start(GameState.MODES.QUIZ_CARD_TO_NUMBER)
    elseif MenuScene.selection == 3 then
        SceneManager.switch(StudyScene)
    elseif MenuScene.selection == 4 then
        SceneManager.switch(SimonScene)
    elseif MenuScene.selection == 5 then
        SceneManager.switch(HighScoresScene)
    else
        SceneManager.switch(SettingsScene)
    end
end

function MenuScene.enter()
    gameState.currentMode = GameState.MODES.MENU
end

function MenuScene.update()
    updateSelectionWithCrank()

    draw()

    if pd.buttonJustPressed(pd.kButtonUp) then
        Assets.playSound(sounds.menuMove)
        MenuScene.selection = MenuScene.selection - 1
        if MenuScene.selection < 1 then MenuScene.selection = #menuItems end
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        Assets.playSound(sounds.menuMove)
        MenuScene.selection = MenuScene.selection + 1
        if MenuScene.selection > #menuItems then MenuScene.selection = 1 end
    elseif pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)
        startSelectedMode()
    end
end
