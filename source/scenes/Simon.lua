-- Simon mode: watch a growing sequence of stack positions, then repeat it from memory.

import "AnswerDial"
import "App"
import "Assets"
import "Deck"
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

local function drawTitle(title)
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned(title, 200, 10, kTextAlignment.center)
    gfx.setFont()
end

local function drawShowing()
    gfx.clear()
    drawTitle("Simon Mode - Round " .. simon.currentRound)

    -- The frame on which the last card times out is drawn after the sequence has run out
    if simon.sequenceIndex > #simon.sequence then
        gfx.drawTextAligned("Preparing next phase...", 200, 120, kTextAlignment.center)
        return
    end

    local position = simon.sequence[simon.sequenceIndex]
    local card = Deck.mnemonicaStack[position]

    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Position " .. position, 200, 50, kTextAlignment.center)
    gfx.setFont()

    Assets.drawCard(card, 200, 110, 1)
    gfx.drawTextAligned(card, 200, 160, kTextAlignment.center)

    gfx.drawTextAligned("Card " .. simon.sequenceIndex .. " of " .. simon.currentRound, 200, 200, kTextAlignment.center)
    gfx.drawTextAligned("Press A to skip, B to exit", 200, 220, kTextAlignment.center)
end

local function drawWaiting()
    gfx.clear()
    drawTitle("Simon Mode - Round " .. simon.currentRound)

    gfx.drawTextAligned("Get ready to repeat the sequence!", 200, 100, kTextAlignment.center)
    gfx.drawTextAligned("Press A to begin", 200, 130, kTextAlignment.center)
end

local function drawInput()
    gfx.clear()
    drawTitle("Simon Mode - Round " .. simon.currentRound)

    gfx.drawTextAligned("Enter card " .. simon.playerIndex .. " of " .. simon.currentRound, 200, 35, kTextAlignment.center)

    local currentPosition = simon.sequence[simon.playerIndex]

    if simon.selectedInput == "card" then
        gfx.drawTextAligned("What card is at position " .. currentPosition .. "?", 200, 55, kTextAlignment.center)

        SimonScene.cardDial:draw()

        gfx.drawTextAligned("Crank to select card | A: Confirm", 200, 210, kTextAlignment.center)
    else
        local cardName = Deck.mnemonicaStack[currentPosition]
        gfx.drawTextAligned("What position is " .. cardName .. "?", 200, 55, kTextAlignment.center)

        SimonScene.numberDial:draw()

        gfx.drawTextAligned("Crank to select position | A: Confirm", 200, 210, kTextAlignment.center)
    end
    gfx.drawTextAligned("B: Cancel", 200, 225, kTextAlignment.center)
end

local function drawFeedback()
    gfx.clear()
    drawTitle("Simon Mode")

    if simon.isCorrect then
        gfx.drawTextAligned("Correct!", 200, 60, kTextAlignment.center)

        if simon.playerIndex >= simon.currentRound then
            gfx.drawTextAligned("Round " .. simon.currentRound .. " Complete!", 200, 90, kTextAlignment.center)
            gfx.drawTextAligned("Press A to continue to Round " .. (simon.currentRound + 1), 200, 120, kTextAlignment.center)
        else
            gfx.drawTextAligned("Press A to continue", 200, 90, kTextAlignment.center)
        end
    else
        gfx.drawTextAligned("Incorrect!", 200, 60, kTextAlignment.center)
        gfx.drawTextAligned("Game Over", 200, 90, kTextAlignment.center)

        local position = simon.sequence[simon.playerIndex]
        local card = Deck.mnemonicaStack[position]
        gfx.drawTextAligned("Position " .. position .. " is " .. card, 200, 120, kTextAlignment.center)

        local completedRounds = simon.currentRound - 1
        local partialCards = simon.playerIndex - 1
        gfx.drawTextAligned("Completed: " .. completedRounds .. " rounds + " .. partialCards .. " cards", 200, 150, kTextAlignment.center)

        -- The record is saved here, so "New best" shows for a single frame
        if simon.currentRound > simon.maxRound then
            simon.maxRound = simon.currentRound
            gameState:saveSettings()
            gfx.drawTextAligned("New best: Round " .. simon.maxRound .. "!", 200, 170, kTextAlignment.center)
        else
            gfx.drawTextAligned("Best: Round " .. simon.maxRound, 200, 170, kTextAlignment.center)
        end

        gfx.drawTextAligned("Press A to play again | B: Main Menu", 200, 200, kTextAlignment.center)
    end
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
    SimonScene.cardDial = AnswerDial.newCardDial()
    SimonScene.numberDial = AnswerDial.newNumberDial()
    startGame()
end

function SimonScene.update()
    phaseUpdates[simon.phase]()

    if not pd.buttonJustPressed(pd.kButtonA) and pd.buttonJustPressed(pd.kButtonB) then
        Assets.playSound(sounds.buttonPress)
        SceneManager.switch(MenuScene)
    end
end
