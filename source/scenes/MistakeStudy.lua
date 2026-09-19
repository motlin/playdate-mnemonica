-- First phase of a mistake review: page through the mistakes before being re-quizzed on them.

import "App"
import "Assets"
import "Deck"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

MistakeStudyScene = {}

local function drawHeading(text, y)
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned(text, 200, y, kTextAlignment.center)
    gfx.setFont()
end

local function draw()
    gfx.clear()

    local review = gameState.mistakeReviewMode
    local mistake = review:getCurrentStudyMistake()

    drawHeading("Mistake Review - Study Phase", 10)
    gfx.drawTextAligned(review:getProgress().text, 200, 30, kTextAlignment.center)

    if review.originalMode == GameState.MODES.QUIZ_NUMBER_TO_CARD then
        drawHeading("Position " .. mistake.position, 60)
        Assets.drawCard(mistake.correctAnswer, 200, 110, 1)
        gfx.drawTextAligned("You answered: " .. mistake.userAnswer, 200, 170, kTextAlignment.center)
    else
        Assets.drawCard(Deck.mnemonicaStack[mistake.position], 200, 60, 1)
        drawHeading("Position " .. mistake.position, 130)
        gfx.drawTextAligned("You answered: Position " .. mistake.userAnswer, 200, 170, kTextAlignment.center)
    end

    gfx.drawTextAligned("Study this card, then press A to continue", 200, 200, kTextAlignment.center)
    gfx.drawTextAligned("B: Previous | A: Next", 200, 220, kTextAlignment.center)
end

function MistakeStudyScene.update()
    draw()

    if pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)

        gameState:advanceMistakeStudy()

        if gameState.mistakeReviewMode.currentPhase == MistakeReviewMode.PHASES.QUIZ then
            QuizScene.resetSelection()
            SceneManager.switch(QuizScene)
        end
    elseif pd.buttonJustPressed(pd.kButtonB) then
        Assets.playSound(sounds.buttonPress)
        gameState.mistakeReviewMode:previousStudyCard()
    end
end
