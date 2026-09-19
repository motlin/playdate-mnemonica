-- Shows whether the last answer was right, for both quizzes and the mistake re-quiz.

import "App"
import "Assets"
import "Deck"
import "Layout"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

FeedbackScene = {}

local LEFT_X <const> = 105
local RIGHT_X <const> = 285
local FOOTER_HINTS <const> = { { button = "A", label = "Continue" } }

local function draw()
    gfx.clear()

    local score = gameState:getScore() .. "/" .. gameState:getQuestionsAnswered()
    local position = gameState:getCurrentPosition()
    local card = Deck.mnemonicaStack[position]

    if gameState.userWasCorrect then
        Layout.drawTitleBar("Correct", score, gameState:getFormattedTime())
        Layout.drawPositionWithCard(position, card, Layout.SCREEN_WIDTH / 2, Assets.drawCard)
    else
        Layout.drawOutlinedTitleBar("Wrong", score, gameState:getFormattedTime())

        if gameState:getQuizMode() == GameState.MODES.QUIZ_NUMBER_TO_CARD then
            gfx.drawTextAligned("You picked", LEFT_X, Layout.CONTENT_TOP + 30, kTextAlignment.center)
            Assets.drawCard(gameState.userAnswer, LEFT_X, Layout.CONTENT_CENTER_Y + 8, 1)
        else
            gfx.drawTextAligned("You said", LEFT_X, Layout.CONTENT_TOP + 50, kTextAlignment.center)
            Layout.drawLargeNumber(tonumber(gameState.userAnswer), LEFT_X, Layout.CONTENT_CENTER_Y + 8)
        end

        Layout.drawPositionWithCard(position, card, RIGHT_X, Assets.drawCard)
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
