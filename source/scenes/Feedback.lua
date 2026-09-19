-- Shows whether the last answer was right, for both quizzes and the mistake re-quiz.

import "App"
import "Assets"
import "Deck"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

FeedbackScene = {}

local function drawHeading(text, y)
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned(text, 200, y, kTextAlignment.center)
    gfx.setFont()
end

local function draw()
    gfx.clear()

    gfx.drawTextAligned(gameState:getFormattedTime(), 380, 10, kTextAlignment.right)

    if gameState:getQuizMode() == GameState.MODES.QUIZ_NUMBER_TO_CARD then
        if gameState.userWasCorrect then
            drawHeading("Correct!", 20)
            Assets.drawCard(gameState.correctAnswer, 200, 90, 1)
        else
            drawHeading("Wrong!", 10)

            gfx.drawTextAligned("You picked:", 100, 40, kTextAlignment.center)
            Assets.drawCard(gameState.userAnswer, 100, 100, 1)

            gfx.drawTextAligned("Correct:", 300, 40, kTextAlignment.center)
            Assets.drawCard(gameState.correctAnswer, 300, 100, 1)
        end
    else
        Assets.drawCard(Deck.mnemonicaStack[gameState:getCurrentPosition()], 200, 50, 1)

        if gameState.userWasCorrect then
            drawHeading("Correct!", 100)
            gfx.drawTextAligned("Position " .. gameState.correctAnswer, 200, 120, kTextAlignment.center)
        else
            drawHeading("Wrong!", 100)
            gfx.drawTextAligned("You said: " .. gameState.userAnswer, 200, 120, kTextAlignment.center)
            gfx.drawTextAligned("Correct: Position " .. gameState.correctAnswer, 200, 140, kTextAlignment.center)
        end
    end

    local scoreText = "Score: " .. gameState:getScore() .. "/" .. gameState:getQuestionsAnswered()
    gfx.drawTextAligned(scoreText, 200, 160, kTextAlignment.center)

    gfx.drawTextAligned("(A) Continue", 200, 200, kTextAlignment.center)
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
