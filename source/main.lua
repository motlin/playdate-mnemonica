import "CoreLibs/graphics"
import "CoreLibs/ui"

local pd <const> = playdate
local gfx <const> = playdate.graphics

-- Mnemonica stack order (1-52)
local mnemonicaStack = {
    "4♣", "2♥", "7♦", "3♣", "4♥", "6♦", "A♠", "5♥", "9♠", "2♠",
    "Q♥", "3♦", "Q♣", "8♥", "6♠", "5♠", "9♥", "K♣", "2♦", "J♥",
    "3♠", "8♠", "6♥", "10♣", "5♦", "K♦", "2♣", "3♥", "8♦", "5♣",
    "K♠", "J♦", "8♣", "10♠", "K♥", "J♣", "7♠", "10♥", "A♦", "4♠",
    "7♥", "4♦", "A♣", "9♣", "J♠", "Q♦", "7♣", "Q♠", "10♦", "6♣",
    "A♥", "9♦"
}

-- USPCC new deck order for crank selection (1-52)
local uspccOrder = {
    -- A♠ through K♠ (positions 1-13)
    "A♠", "2♠", "3♠", "4♠", "5♠", "6♠", "7♠", "8♠", "9♠", "10♠", "J♠", "Q♠", "K♠",
    -- A♦ through K♦ (positions 14-26)
    "A♦", "2♦", "3♦", "4♦", "5♦", "6♦", "7♦", "8♦", "9♦", "10♦", "J♦", "Q♦", "K♦",
    -- K♣ through A♣ (positions 27-39, reversed)
    "K♣", "Q♣", "J♣", "10♣", "9♣", "8♣", "7♣", "6♣", "5♣", "4♣", "3♣", "2♣", "A♣",
    -- K♥ through A♥ (positions 40-52, reversed)
    "K♥", "Q♥", "J♥", "10♥", "9♥", "8♥", "7♥", "6♥", "5♥", "4♥", "3♥", "2♥", "A♥"
}

-- Game state
local gameState = "quiz" -- "quiz", "feedback", "complete"
local currentPosition = 1
local selectedCard = 1 -- Index in uspccOrder (1-52)
local score = 0
local showingCorrectAnswer = false
local correctAnswer = ""
local userWasCorrect = false

-- Crank handling
local lastCrankValue = 0
local crankAccumulator = 0

local function updateSelectedCard()
    local crankValue = pd.getCrankPosition()
    local crankDelta = crankValue - lastCrankValue

    -- Handle wrap-around at 0/360 degrees
    if crankDelta > 180 then
        crankDelta = crankDelta - 360
    elseif crankDelta < -180 then
        crankDelta = crankDelta + 360
    end

    crankAccumulator = crankAccumulator + crankDelta
    lastCrankValue = crankValue

    -- One full rotation (360 degrees) = 13 cards (1/4 of the deck)
    local cardChange = math.floor(crankAccumulator / (360 / 13))
    if cardChange ~= 0 then
        selectedCard = selectedCard + cardChange
        crankAccumulator = crankAccumulator - (cardChange * (360 / 13))

        -- Wrap around
        while selectedCard < 1 do selectedCard = selectedCard + 52 end
        while selectedCard > 52 do selectedCard = selectedCard - 52 end
    end
end

local function checkAnswer()
    local correctCard = mnemonicaStack[currentPosition]
    local selectedCardName = uspccOrder[selectedCard]

    userWasCorrect = (selectedCardName == correctCard)
    correctAnswer = correctCard
    showingCorrectAnswer = true

    if userWasCorrect then
        score = score + 1
    end

    gameState = "feedback"
end

local function nextQuestion()
    showingCorrectAnswer = false
    currentPosition = currentPosition + 1

    if currentPosition > 52 then
        gameState = "complete"
    else
        gameState = "quiz"
    end
end

local function resetGame()
    currentPosition = 1
    selectedCard = 1
    score = 0
    showingCorrectAnswer = false
    gameState = "quiz"
    crankAccumulator = 0
    lastCrankValue = pd.getCrankPosition()
end

local function drawQuiz()
    gfx.clear()

    -- Draw question
    local questionText = "Position " .. currentPosition .. "?"
    gfx.drawTextAligned(questionText, 200, 50, kTextAlignment.center)

    -- Draw selected card
    local selectedCardName = uspccOrder[selectedCard]
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned(selectedCardName, 200, 120, kTextAlignment.center)
    gfx.setFont() -- Reset to default font

    -- Draw crank indicator if docked
    if pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
    end

    -- Draw progress
    local progressText = "Question " .. currentPosition .. " of 52"
    gfx.drawTextAligned(progressText, 200, 200, kTextAlignment.center)

    -- Draw instructions
    gfx.drawTextAligned("🎯 Use crank to select card", 200, 220, kTextAlignment.center)
    gfx.drawTextAligned("Ⓐ Confirm answer", 200, 230, kTextAlignment.center)
end

local function drawFeedback()
    gfx.clear()

    if userWasCorrect then
        gfx.drawTextAligned("✅ Correct!", 200, 80, kTextAlignment.center)
    else
        gfx.drawTextAligned("❌ Wrong!", 200, 60, kTextAlignment.center)
        gfx.drawTextAligned("Correct answer: " .. correctAnswer, 200, 100, kTextAlignment.center)
    end

    -- Draw score
    local scoreText = "Score: " .. score .. "/" .. (currentPosition)
    gfx.drawTextAligned(scoreText, 200, 140, kTextAlignment.center)

    -- Draw continue instruction
    gfx.drawTextAligned("Ⓐ Continue", 200, 180, kTextAlignment.center)
end

local function drawComplete()
    gfx.clear()

    gfx.drawTextAligned("🎉 Quiz Complete!", 200, 60, kTextAlignment.center)

    local finalScore = "Final Score: " .. score .. "/52"
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned(finalScore, 200, 100, kTextAlignment.center)
    gfx.setFont()

    local percentage = math.floor((score / 52) * 100)
    gfx.drawTextAligned(percentage .. "% correct", 200, 130, kTextAlignment.center)

    gfx.drawTextAligned("Ⓐ Play Again", 200, 180, kTextAlignment.center)
end

function playdate.update()
    if gameState == "quiz" then
        updateSelectedCard()
        drawQuiz()

        if pd.buttonJustPressed(pd.kButtonA) then
            checkAnswer()
        end

    elseif gameState == "feedback" then
        drawFeedback()

        if pd.buttonJustPressed(pd.kButtonA) then
            nextQuestion()
        end

    elseif gameState == "complete" then
        drawComplete()

        if pd.buttonJustPressed(pd.kButtonA) then
            resetGame()
        end
    end
end

-- Initialize crank position
lastCrankValue = pd.getCrankPosition()
