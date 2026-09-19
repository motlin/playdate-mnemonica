-- Simon mode: watch a growing sequence of stack positions, then repeat it from memory.
-- The rules live in SimonGame; this scene shows them and turns button presses into moves.

import "AnswerDial"
import "App"
import "Assets"
import "Deck"
import "FactView"
import "Layout"
import "SceneManager"
import "SimonGame"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds
local PHASES <const> = SimonGame.PHASES
local INPUT_KINDS <const> = SimonGame.INPUT_KINDS

SimonScene = {}

-- Frames each card of the sequence stays on screen
local FRAMES_PER_CARD <const> = 90
local QUESTION_CARD_X <const> = 70
local CARD_Y <const> = Layout.CONTENT_CENTER_Y - 7

local SHOWING_HINTS <const> = { { button = "A", label = "Next" }, { button = "B", label = "Menu" } }
local WAITING_HINTS <const> = { { button = "A", label = "Begin" }, { button = "B", label = "Menu" } }
local INPUT_HINTS <const> = { { button = "A", label = "Confirm" }, { button = "B", label = "Menu" } }
local CORRECT_HINTS <const> = { { button = "A", label = "Continue" }, { button = "B", label = "Menu" } }
local GAME_OVER_HINTS <const> = { { button = "A", label = "Play again" }, { button = "B", label = "Menu" } }

local game
local displayTimer
local dialQuestionNumber

local function playShownCard()
    Assets.playCardTones(Deck.mnemonicaStack[game:shownPosition()])
end

local function startGame()
    game = SimonGame:new({
        bestRounds = gameState.simonMode.maxRound,
        randomPosition = function() return math.random(1, 52) end,
        randomInputKind = function()
            return math.random() < 0.5 and INPUT_KINDS.CARD or INPUT_KINDS.POSITION
        end,
    })
    SimonScene.game = game
    displayTimer = 0
    dialQuestionNumber = nil
    playShownCard()
end

-- Every question gets a new dial. A dial kept from the previous question would still be
-- sitting on that answer, which in the next round is the first answer again.
local function dialForCurrentQuestion()
    if dialQuestionNumber ~= game.questionNumber then
        dialQuestionNumber = game.questionNumber
        if game.inputKind == INPUT_KINDS.CARD then
            SimonScene.dial = AnswerDial.newCardDial(AnswerDial.FULL_WIDTH)
        else
            SimonScene.dial = AnswerDial.newNumberDial(AnswerDial.RIGHT_SIDE)
        end
    end
    return SimonScene.dial
end

local function roundLabel()
    return "Round " .. game.round
end

local function drawShowing()
    gfx.clear()
    Layout.drawTitleBar("Remember", roundLabel(), game.showIndex .. "/" .. game.round)
    FactView.drawStudyCard(game:shownPosition())
    Layout.drawFooter(SHOWING_HINTS, false)
end

local function drawWaiting()
    gfx.clear()
    Layout.drawTitleBar("Simon", roundLabel())

    gfx.setFont(Layout.boldFont)
    gfx.drawTextAligned("Now repeat the sequence", 200, Layout.CONTENT_CENTER_Y - 10, kTextAlignment.center)
    gfx.setFont()

    Layout.drawFooter(WAITING_HINTS, false)
end

local function drawInput()
    gfx.clear()

    local progress = game.answerIndex .. "/" .. game.round
    if game.inputKind == INPUT_KINDS.CARD then
        Layout.drawTitleBar("Position " .. game:askedPosition() .. "?", roundLabel(), progress)
    else
        Layout.drawTitleBar("Which position?", roundLabel(), progress)
        Assets.drawCard(Deck.mnemonicaStack[game:askedPosition()], QUESTION_CARD_X, CARD_Y, 2)
    end

    dialForCurrentQuestion():draw()
    Layout.drawFooter(INPUT_HINTS, true)
end

local function drawFeedback()
    gfx.clear()

    if game.lastAnswerCorrect then
        Layout.drawTitleBar("Correct", roundLabel())
        local message
        if game:isRoundComplete() then
            message = "Round " .. game.round .. " complete"
        else
            message = game.answerIndex .. " of " .. game.round .. " so far"
        end
        gfx.setFont(Layout.boldFont)
        gfx.drawTextAligned(message, 200, Layout.CONTENT_CENTER_Y - 10, kTextAlignment.center)
        gfx.setFont()
        Layout.drawFooter(CORRECT_HINTS, false)
        return
    end

    Layout.drawOutlinedTitleBar("Game over", roundLabel())

    gfx.drawTextAligned("Rounds completed", 105, Layout.CONTENT_TOP + 30, kTextAlignment.center)
    Layout.drawLargeText(tostring(game:completedRounds()), 105, Layout.CONTENT_CENTER_Y - 10)
    local bestText = game.isNewBest and "New best!" or ("Best: " .. game.bestRounds)
    gfx.drawTextAligned(bestText, 105, Layout.CONTENT_CENTER_Y + 30, kTextAlignment.center)

    FactView.drawFact(game:askedPosition(), 285)
    Layout.drawFooter(GAME_OVER_HINTS, false)
end

local function showNextCard()
    displayTimer = 0
    game:showNext()
    if game.phase == PHASES.SHOWING then
        playShownCard()
    end
end

local function submitAnswer()
    local selection = SimonScene.dial:getSelection()
    if game.inputKind == INPUT_KINDS.CARD then
        game:submit(Deck.uspccOrder[selection])
    else
        game:submit(selection)
    end

    if game.lastAnswerCorrect then
        -- A right answer plays the card back, as Simon plays the colour you pressed
        Assets.playCardTones(Deck.mnemonicaStack[game:askedPosition()])
    else
        Assets.playSound(sounds.incorrect)
        if game.isNewBest then
            gameState.simonMode.maxRound = game.bestRounds
            gameState:saveSettings()
        end
    end
end

local function updateShowing()
    displayTimer = displayTimer + 1
    if displayTimer > FRAMES_PER_CARD then
        showNextCard()
        return
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
        game:beginInput()
    end
end

local function updateInput()
    dialForCurrentQuestion():update(gameState.crankSensitivity)
    drawInput()

    if pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)
        submitAnswer()
    end
end

local function updateFeedback()
    drawFeedback()

    if pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)
        if game.isOver then
            startGame()
        else
            displayTimer = 0
            game:continue()
            if game.phase == PHASES.SHOWING then
                playShownCard()
            end
        end
    end
end

-- Each draws its phase and handles the A button
local phaseUpdates = {
    [PHASES.SHOWING] = updateShowing,
    [PHASES.WAITING] = updateWaiting,
    [PHASES.INPUT] = updateInput,
    [PHASES.FEEDBACK] = updateFeedback
}

function SimonScene.enter()
    gameState.currentMode = GameState.MODES.SIMON
    startGame()
end

function SimonScene.update()
    phaseUpdates[game.phase]()

    if not pd.buttonJustPressed(pd.kButtonA) and pd.buttonJustPressed(pd.kButtonB) then
        Assets.playSound(sounds.buttonPress)
        SceneManager.switch(MenuScene)
    end
end
