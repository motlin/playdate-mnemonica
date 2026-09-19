-- Browse the whole stack without being tested.

import "CoreLibs/ui"
import "App"
import "Assets"
import "Deck"
import "Picker"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

StudyScene = {}

local picker

local function draw()
    local position = picker:getSelection()

    gfx.clear()

    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Study Mode", 200, 10, kTextAlignment.center)
    gfx.drawTextAligned("Position " .. position, 200, 50, kTextAlignment.center)
    gfx.setFont()

    local cardAtPosition = Deck.mnemonicaStack[position]
    Assets.drawCard(cardAtPosition, 200, 110, 1)
    gfx.drawTextAligned(cardAtPosition, 200, 160, kTextAlignment.center)

    if pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
    end

    gfx.drawTextAligned("Crank/D-pad: Browse | B: Menu", 200, 200, kTextAlignment.center)
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
