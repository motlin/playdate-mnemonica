-- Browse the whole stack without being tested.

import "App"
import "Layout"
import "FactView"
import "Assets"
import "Picker"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

StudyScene = {}

local picker

local FOOTER_HINTS <const> = { { button = "B", label = "Menu" } }

local function draw()
    gfx.clear()
    Layout.drawTitleBar("Study", nil, picker:getSelection() .. "/52")
    FactView.drawStudyCard(picker:getSelection())
    Layout.drawFooter(FOOTER_HINTS, true)
end

function StudyScene.enter()
    gameState.currentMode = GameState.MODES.STUDY
    -- Left/Right step through the stack, Up/Down jump ten positions
    picker = Picker:new(52, { up = -10, down = 10, left = -1, right = 1 }, function()
        Assets.playSound(sounds.crankTick)
    end)
end

function StudyScene.update()
    picker:update(gameState.crankSensitivity)

    draw()

    if pd.buttonJustPressed(pd.kButtonB) then
        Assets.playSound(sounds.buttonPress)
        SceneManager.switch(MenuScene)
    end
end
