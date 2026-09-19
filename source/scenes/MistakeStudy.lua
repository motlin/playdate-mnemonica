-- First phase of a mistake review: page through the mistakes before being re-quizzed on them.

import "App"
import "Layout"
import "FactView"
import "Assets"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

MistakeStudyScene = {}

local FOOTER_HINTS <const> = { { button = "A", label = "Next" }, { button = "B", label = "Previous" } }

local function draw()
    gfx.clear()

    local review = gameState.mistakeReviewMode
    local mistake = review:getCurrentStudyMistake()

    Layout.drawTitleBar("Study your mistakes", nil, review.studyIndex .. "/" .. #review.mistakes)
    local answeredWithCard = review.originalMode == GameState.MODES.QUIZ_NUMBER_TO_CARD
    FactView.drawMistake(mistake.position, mistake.userAnswer, answeredWithCard)
    Layout.drawFooter(FOOTER_HINTS, false)
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
