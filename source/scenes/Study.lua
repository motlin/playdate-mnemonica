-- Browse the whole stack without being tested.

import "CoreLibs/ui"
import "App"
import "Assets"
import "Deck"
import "DialInput"
import "SceneManager"
import "SharedState"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

StudyScene = {}

local position = 1

local function draw()
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
    position = 1
    SharedState.lastCrankPosition = pd.getCrankPosition()
end

function StudyScene.update()
    position = DialInput.selectionFromCrank(position)

    draw()

    -- Up/Down jump ten positions, Left/Right step by one
    local step
    if pd.buttonJustPressed(pd.kButtonUp) then
        step = -10
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        step = 10
    elseif pd.buttonJustPressed(pd.kButtonLeft) then
        step = -1
    elseif pd.buttonJustPressed(pd.kButtonRight) then
        step = 1
    end
    if step then
        Assets.playSound(sounds.buttonPress)
        position = DialInput.wrap(position + step)
    end

    if pd.buttonJustPressed(pd.kButtonB) then
        Assets.playSound(sounds.buttonPress)
        SceneManager.switch(MenuScene)
    end
end
