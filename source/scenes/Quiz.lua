-- The question screen of both quizzes, including the re-quiz of a mistake review.

import "CoreLibs/ui"
import "App"
import "Assets"
import "AnswerDial"
import "Deck"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

QuizScene = {}

local function isNumberToCard()
    return gameState:getQuizMode() == GameState.MODES.QUIZ_NUMBER_TO_CARD
end

-- A fresh dial starts on the first item with no leftover rotation.
function QuizScene.resetSelection()
    QuizScene.dial = isNumberToCard() and AnswerDial.newCardDial() or AnswerDial.newNumberDial()
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

local function drawStatus()
    if pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
    end

    gfx.drawTextAligned(gameState:getProgressString(), 200, 200, kTextAlignment.center)

    if gameState.usingSpacedRepetition then
        gfx.drawTextAligned("[Smart Mode]" , 200, 185, kTextAlignment.center)
    end

    gfx.drawTextAligned("Crank/D-pad: Select | A: Confirm | B: Menu", 200, 220, kTextAlignment.center)
end

local function drawNumberToCard()
    gfx.clear()

    local questionText = "Position " .. gameState:getCurrentPosition() .. "?"
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned(questionText, 200, 10, kTextAlignment.center)
    gfx.setFont()

    gfx.drawTextAligned(gameState:getFormattedTime(), 380, 10, kTextAlignment.right)

    QuizScene.dial:draw()

    drawStatus()
end

local function drawCardToNumber()
    gfx.clear()

    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("What position is this card?", 200, 10, kTextAlignment.center)
    gfx.setFont()

    -- The question card sits to the left of the dial
    Assets.drawCard(Deck.mnemonicaStack[gameState:getCurrentPosition()], 80, 100, 1)

    gfx.drawTextAligned(gameState:getFormattedTime(), 380, 10, kTextAlignment.right)

    QuizScene.dial:draw()

    drawStatus()
end

local function checkAnswer()
    if isNumberToCard() then
        gameState:submitAnswer(Deck.uspccOrder[QuizScene.dial:getSelection()], false)
    else
        gameState:submitAnswer(tostring(QuizScene.dial:getSelection()), false)
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

    if isNumberToCard() then
        drawNumberToCard()
    else
        drawCardToNumber()
    end

    if pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)
        checkAnswer()
    elseif pd.buttonJustPressed(pd.kButtonB) then
        Assets.playSound(sounds.buttonPress)
        SceneManager.switch(MenuScene)
        SystemMenu.refresh()
        gameState.mistakeReviewMode = nil
        gameState.originalSession = nil
    end
end
