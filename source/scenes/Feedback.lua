-- Shows whether the last answer was right, for both quizzes and the mistake re-quiz.

import "App"
import "Assets"
import "FactView"
import "Layout"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

FeedbackScene = { hasQuizInProgress = true }

local FOOTER_HINTS <const> = { { button = "A", label = "Continue" } }

local function draw()
    gfx.clear()

    local score = gameState:getScore() .. "/" .. gameState:getQuestionsAnswered()
    local position = gameState:getCurrentPosition()

    if gameState.userWasCorrect then
        Layout.drawTitleBar("Correct", score, gameState:getFormattedTime())
        FactView.drawFact(position, Layout.SCREEN_WIDTH / 2)
    else
        Layout.drawOutlinedTitleBar("Wrong", score, gameState:getFormattedTime())
        local answeredWithCard = gameState:getQuizMode() == GameState.MODES.QUIZ_NUMBER_TO_CARD
        FactView.drawMistake(position, gameState.userAnswer, answeredWithCard)
    end

    Layout.drawFooter(FOOTER_HINTS, false)
end

local function nextQuestion()
    gameState:nextQuestion()

    if gameState.quizState ~= GameState.QUIZ_STATES.COMPLETE then
        SceneManager.switch(QuizScene)
        return
    end

    Assets.playSound(sounds.sessionComplete)
    if gameState.currentMode == GameState.MODES.MISTAKE_REVIEW then
        SceneManager.switch(MistakeReviewCompleteScene)
    else
        SceneManager.switch(SummaryScene)
    end
end

function FeedbackScene.update()
    draw()

    if pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)
        nextQuestion()
    end
end
