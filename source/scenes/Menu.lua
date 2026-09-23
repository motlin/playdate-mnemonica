import "App"
import "Layout"
import "Assets"
import "SceneManager"
import "Picker"

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

local picker

-- The menu opens on whatever was selected last, including across launches.
local function newPicker()
    picker = Picker:new(#menuItems, { up = -1, down = 1, left = 0, right = 0 }, function()
        Assets.playSound(sounds.menuMove)
    end, 1)
    picker:select(MenuScene.selection)
end

local FOOTER_HINTS <const> = { { button = "A", label = "Start" } }

local function draw()
    gfx.clear()
    Layout.drawTitleBar("Mnemonica")
    Layout.drawList(menuItems, MenuScene.selection, 33, 30)
    Layout.drawFooter(FOOTER_HINTS, true)
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

function MenuScene.select(index)
    MenuScene.selection = index
    picker:select(index)
end

function MenuScene.enter()
    gameState.currentMode = GameState.MODES.MENU
    newPicker()
end

function MenuScene.update()
    picker:update(gameState.crankSensitivity)
    MenuScene.selection = picker:getSelection()

    draw()

    if pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)
        startSelectedMode()
    end
end
