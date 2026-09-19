-- The question screen of both quizzes, including the re-quiz of a mistake review.

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

QuizScene = {}

local function isNumberToCard()
    return gameState:getQuizMode() == GameState.MODES.QUIZ_NUMBER_TO_CARD
end

-- Only the dial the quiz uses goes back to the start; the other keeps its selection.
function QuizScene.resetSelection()
    if isNumberToCard() then
        SharedState.selectedCard = 1
    else
        SharedState.selectedNumber = 1
    end
end

function QuizScene.start(mode)
    gameState:startQuiz(mode)
    QuizScene.resetSelection()
    SharedState.lastCrankPosition = pd.getCrankPosition()
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

    SharedState.dialRenderer:drawFrame()
    SharedState.dialRenderer:draw(Deck.uspccOrder, SharedState.selectedCard, Assets.getCardImage, Assets.drawCard)

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

    SharedState.numberDialRenderer:drawFrame()
    SharedState.numberDialRenderer:draw(SharedState.selectedNumber)

    drawStatus()
end

local function checkAnswer()
    if isNumberToCard() then
        gameState:submitAnswer(Deck.uspccOrder[SharedState.selectedCard], false)
    else
        gameState:submitAnswer(tostring(SharedState.selectedNumber), false)
    end

    if gameState.userWasCorrect then
        Assets.playSound(sounds.correct)
    else
        Assets.playSound(sounds.incorrect)
    end

    SceneManager.switch(FeedbackScene)
end

function QuizScene.update()
    -- D-pad moves show on the next frame; crank moves show on this one
    if isNumberToCard() then
        SharedState.selectedCard = DialInput.selectionFromCrank(SharedState.selectedCard)
        drawNumberToCard()
        SharedState.selectedCard = DialInput.selectionFromDpad(SharedState.selectedCard, 13)
    else
        SharedState.selectedNumber = DialInput.selectionFromCrank(SharedState.selectedNumber)
        drawCardToNumber()
        SharedState.selectedNumber = DialInput.selectionFromDpad(SharedState.selectedNumber, 10)
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
