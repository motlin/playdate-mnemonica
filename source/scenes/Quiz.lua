-- The question screen of both quizzes, including the re-quiz of a mistake review.

import "App"
import "Assets"
import "AnswerDial"
import "Deck"
import "Layout"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

QuizScene = { hasQuizInProgress = true }

local function isNumberToCard() return gameState:getQuizMode() == GameState.MODES.QUIZ_NUMBER_TO_CARD end

-- A fresh dial starts on the first item with no leftover rotation.
function QuizScene.resetSelection()
    if isNumberToCard() then
        QuizScene.dial = AnswerDial.newCardDial(AnswerDial.FULL_WIDTH)
    else
        QuizScene.dial = AnswerDial.newNumberDial(AnswerDial.RIGHT_SIDE)
    end
end

function QuizScene.start(mode)
    gameState:startQuiz(mode)
    QuizScene.resetSelection()
    SceneManager.switch(QuizScene)
end

function QuizScene.enter()
    if isNumberToCard() then
        gameState.correctAnswer = Deck.mnemonicaStack[gameState:getCurrentPosition()]
    else
        gameState.correctAnswer = tostring(gameState:getCurrentPosition())
    end
end

local QUESTION_CARD_X <const> = 70
local FOOTER_HINTS <const> = { { button = "A", label = "Confirm" }, { button = "B", label = "Menu" } }

local function draw()
    gfx.clear()

    local session = gameState.currentSession
    local progress = session.currentQuestionIndex .. "/" .. session.totalQuestions

    if isNumberToCard() then
        Layout.drawTitleBar(
            "Position " .. gameState:getCurrentPosition() .. "?",
            progress,
            gameState:getFormattedTime()
        )
    else
        Layout.drawTitleBar("Which position?", progress, gameState:getFormattedTime())
        Assets.drawCard(
            Deck.mnemonicaStack[gameState:getCurrentPosition()],
            QUESTION_CARD_X,
            Layout.CONTENT_CENTER_Y - 7,
            2
        )
    end

    QuizScene.dial:draw()
    Layout.drawFooter(FOOTER_HINTS, true)
end

local function checkAnswer()
    if isNumberToCard() then
        gameState:submitAnswer(Deck.uspccOrder[QuizScene.dial:getSelection()])
    else
        gameState:submitAnswer(tostring(QuizScene.dial:getSelection()))
    end

    if gameState.userWasCorrect then
        Assets.playSound(sounds.correct)
    else
        Assets.playSound(sounds.incorrect)
    end

    SceneManager.switch(FeedbackScene)
end

function QuizScene.update()
    QuizScene.dial:update(gameState.crankSensitivity)

    draw()

    if pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)
        checkAnswer()
    elseif pd.buttonJustPressed(pd.kButtonB) then
        Assets.playSound(sounds.buttonPress)
        SceneManager.switch(MenuScene)
    end
end
