-- Simon mode: watch a growing sequence of stack positions, then repeat it from memory.

import "AnswerDial"
import "App"
import "Assets"
import "Deck"
import "Layout"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local simon <const> = gameState.simonMode
local sounds <const> = Assets.sounds

SimonScene = {}

-- Frames each card of the sequence stays on screen
local framesPerCard = 90

local function randomInput()
    return math.random() < 0.5 and "card" or "number"
end

local function startRound()
    simon.currentRound = simon.currentRound + 1
    table.insert(simon.sequence, math.random(1, 52))

    simon.phase = "SHOWING"
    simon.sequenceIndex = 1
    simon.displayTimer = 0
    simon.playerIndex = 1
    simon.selectedInput = "card"
end

local function startGame()
    simon.sequence = {}
    simon.currentRound = 0
    simon.isCorrect = true
    startRound()
end

local QUESTION_CARD_X <const> = 70
local CARD_Y <const> = Layout.CONTENT_CENTER_Y - 7

local function roundLabel()
    return "Round " .. simon.currentRound
end

local function drawShowing()
    gfx.clear()

    -- The frame on which the last card times out is drawn after the sequence has run out
    if simon.sequenceIndex > #simon.sequence then
        Layout.drawTitleBar("Simon", roundLabel())
        return
    end

    local position = simon.sequence[simon.sequenceIndex]
    Layout.drawTitleBar("Remember", roundLabel(), simon.sequenceIndex .. "/" .. simon.currentRound)

    Assets.drawCard(Deck.mnemonicaStack[position], 130, CARD_Y, 2)
    gfx.drawTextAligned("Position", 280, CARD_Y - 40, kTextAlignment.center)
    Layout.drawLargeNumber(position, 280, CARD_Y + 5)

    Layout.drawFooter({ { button = "A", label = "Next" }, { button = "B", label = "Menu" } }, false)
end

local function drawWaiting()
    gfx.clear()
    Layout.drawTitleBar("Simon", roundLabel())

    gfx.setFont(Layout.boldFont)
    gfx.drawTextAligned("Now repeat the sequence", 200, Layout.CONTENT_CENTER_Y - 10, kTextAlignment.center)
    gfx.setFont()

    Layout.drawFooter({ { button = "A", label = "Begin" }, { button = "B", label = "Menu" } }, false)
end

local function drawInput()
    gfx.clear()

    local progress = simon.playerIndex .. "/" .. simon.currentRound
    local currentPosition = simon.sequence[simon.playerIndex]

    if simon.selectedInput == "card" then
        Layout.drawTitleBar("Position " .. currentPosition .. "?", roundLabel(), progress)
        SimonScene.cardDial:draw()
    else
        Layout.drawTitleBar("Which position?", roundLabel(), progress)
        Assets.drawCard(Deck.mnemonicaStack[currentPosition], QUESTION_CARD_X, CARD_Y, 2)
        SimonScene.numberDial:draw()
    end

    Layout.drawFooter({ { button = "A", label = "Confirm" }, { button = "B", label = "Menu" } }, true)
end

local function drawFeedback()
    gfx.clear()

    if simon.isCorrect then
        Layout.drawTitleBar("Correct", roundLabel())
        gfx.setFont(Layout.boldFont)
        if simon.playerIndex >= simon.currentRound then
            gfx.drawTextAligned("Round " .. simon.currentRound .. " complete", 200, Layout.CONTENT_CENTER_Y - 10, kTextAlignment.center)
        else
            gfx.drawTextAligned(simon.playerIndex - 1 .. " of " .. simon.currentRound .. " so far", 200, Layout.CONTENT_CENTER_Y - 10, kTextAlignment.center)
        end
        gfx.setFont()
        Layout.drawFooter({ { button = "A", label = "Continue" }, { button = "B", label = "Menu" } }, false)
        return
    end

    Layout.drawOutlinedTitleBar("Game over", roundLabel())

    local completedRounds = simon.currentRound - 1
    gfx.drawTextAligned("Rounds completed", 105, Layout.CONTENT_TOP + 30, kTextAlignment.center)
    Layout.drawLargeNumber(completedRounds, 105, Layout.CONTENT_CENTER_Y - 10)
    local bestText = simon.isNewBest and "New best!" or ("Best: " .. simon.maxRound)
    gfx.drawTextAligned(bestText, 105, Layout.CONTENT_CENTER_Y + 30, kTextAlignment.center)

    local position = simon.sequence[simon.playerIndex]
    Layout.drawPositionWithCard(position, Deck.mnemonicaStack[position], 285, Assets.drawCard)

    Layout.drawFooter({ { button = "A", label = "Play again" }, { button = "B", label = "Menu" } }, false)
end

local function checkAnswer()
    local position = simon.sequence[simon.playerIndex]

    if simon.selectedInput == "card" then
        simon.isCorrect = Deck.uspccOrder[SimonScene.cardDial:getSelection()] == Deck.mnemonicaStack[position]
    else
        simon.isCorrect = SimonScene.numberDial:getSelection() == position
    end

    if simon.isCorrect then
        Assets.playSound(sounds.correct)

        if simon.playerIndex < simon.currentRound then
            simon.playerIndex = simon.playerIndex + 1
            simon.selectedInput = randomInput()
        end
    else
        Assets.playSound(sounds.incorrect)

        -- The record counts rounds finished, not the round that ended the game
        local completedRounds = simon.currentRound - 1
        simon.isNewBest = completedRounds > simon.maxRound
        if simon.isNewBest then
            simon.maxRound = completedRounds
            gameState:saveSettings()
        end
    end

    simon.phase = "FEEDBACK"
end

local function showNextCard()
    simon.displayTimer = 0
    simon.sequenceIndex = simon.sequenceIndex + 1

    if simon.sequenceIndex > simon.currentRound then
        simon.phase = "WAITING"
    end
end

local function updateShowing()
    simon.displayTimer = simon.displayTimer + 1
    if simon.displayTimer > framesPerCard then
        showNextCard()
    end

    drawShowing()

    if pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)
        showNextCard()
    end
end

local function updateWaiting()
    drawWaiting()

    if pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)
        simon.phase = "INPUT"
        simon.playerIndex = 1
        simon.selectedInput = randomInput()
    end
end

local function updateInput()
    if simon.selectedInput == "card" then
        SimonScene.cardDial:update(gameState.crankSensitivity)
    else
        SimonScene.numberDial:update(gameState.crankSensitivity)
    end

    drawInput()

    if pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)
        checkAnswer()
    end
end

local function updateFeedback()
    drawFeedback()

    if pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)

        if not simon.isCorrect then
            startGame()
        elseif simon.playerIndex >= simon.currentRound then
            startRound()
        else
            simon.phase = "INPUT"
        end
    end
end

-- Each draws its phase and handles the A button
local phaseUpdates = {
    SHOWING = updateShowing,
    WAITING = updateWaiting,
    INPUT = updateInput,
    FEEDBACK = updateFeedback
}

function SimonScene.enter()
    gameState.currentMode = GameState.MODES.SIMON
    SimonScene.cardDial = AnswerDial.newCardDial(AnswerDial.FULL_WIDTH)
    SimonScene.numberDial = AnswerDial.newNumberDial(AnswerDial.RIGHT_SIDE)
    startGame()
end

function SimonScene.update()
    phaseUpdates[simon.phase]()

    if not pd.buttonJustPressed(pd.kButtonA) and pd.buttonJustPressed(pd.kButtonB) then
        Assets.playSound(sounds.buttonPress)
        SceneManager.switch(MenuScene)
    end
end
