import "CoreLibs/graphics"
import "CoreLibs/ui"

local pd <const> = playdate
local gfx <const> = playdate.graphics

-- Load card sprites as a single image
local cardSpriteSheet = gfx.image.new("images/cards")
assert(cardSpriteSheet, "Failed to load card sprite sheet")

-- Store individual card images in a table
local cardImages = {}
local cardWidth, cardHeight = 32, 32

-- Extract individual card images from the sprite sheet
for row = 1, 4 do
    for col = 1, 14 do
        local x = (col - 1) * cardWidth
        local y = (row - 1) * cardHeight
        local cardImage = gfx.image.new(cardWidth, cardHeight)
        gfx.pushContext(cardImage)
        cardSpriteSheet:draw(-x, -y)
        gfx.popContext()
        local index = (row - 1) * 14 + col
        cardImages[index] = cardImage
    end
end

-- Card lookup mapping (card name to sprite index)
-- The sprite sheet has 4 rows x 14 columns
-- Row 1: A-K of Spades (indices 1-13) + back
-- Row 2: A-K of Diamonds (indices 15-27) + back
-- Row 3: A-K of Clubs (indices 29-41) + back
-- Row 4: A-K of Hearts (indices 43-55) + back
local cardToIndex = {}
local suits = {"S", "D", "C", "H"}
local ranks = {"A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"}

-- Build card name to sprite index mapping
for suitIdx, suit in ipairs(suits) do
    for rankIdx, rank in ipairs(ranks) do
        local cardName = rank .. suit
        -- Each row has 14 slots but only 13 cards (14th is card back)
        local index = (suitIdx - 1) * 14 + rankIdx
        cardToIndex[cardName] = index
    end
end

-- Mnemonica stack order (1-52) - using S/D/C/H for suits
local mnemonicaStack = {
    "4C", "2H", "7D", "3C", "4H", "6D", "AS", "5H", "9S", "2S",
    "QH", "3D", "QC", "8H", "6S", "5S", "9H", "KC", "2D", "JH",
    "3S", "8S", "6H", "10C", "5D", "KD", "2C", "3H", "8D", "5C",
    "KS", "JD", "8C", "10S", "KH", "JC", "7S", "10H", "AD", "4S",
    "7H", "4D", "AC", "9C", "JS", "QD", "7C", "QS", "10D", "6C",
    "AH", "9D"
}

-- USPCC new deck order for crank selection (1-52) - using S/D/C/H for suits
local uspccOrder = {
    -- A through K of Spades (positions 1-13)
    "AS", "2S", "3S", "4S", "5S", "6S", "7S", "8S", "9S", "10S", "JS", "QS", "KS",
    -- A through K of Diamonds (positions 14-26)
    "AD", "2D", "3D", "4D", "5D", "6D", "7D", "8D", "9D", "10D", "JD", "QD", "KD",
    -- K through A of Clubs (positions 27-39, reversed)
    "KC", "QC", "JC", "10C", "9C", "8C", "7C", "6C", "5C", "4C", "3C", "2C", "AC",
    -- K through A of Hearts (positions 40-52, reversed)
    "KH", "QH", "JH", "10H", "9H", "8H", "7H", "6H", "5H", "4H", "3H", "2H", "AH"
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

-- Helper function to get card image from card name
local function getCardImage(cardName)
    local index = cardToIndex[cardName]
    if index then
        return cardImages[index]
    end
    return nil
end

-- Helper function to draw a card centered at position
local function drawCard(cardName, x, y, scale)
    local cardImage = getCardImage(cardName)
    if cardImage then
        if scale and scale ~= 1 then
            local scaledImage = cardImage:scaledImage(scale)
            scaledImage:drawCentered(x, y)
        else
            cardImage:drawCentered(x, y)
        end
    else
        -- Fallback to text if image not found
        gfx.drawTextAligned(cardName, x, y, kTextAlignment.center)
    end
end

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
    gfx.drawTextAligned(questionText, 200, 30, kTextAlignment.center)

    -- Draw selected card (scaled up for visibility)
    local selectedCardName = uspccOrder[selectedCard]
    drawCard(selectedCardName, 200, 100, 2)  -- 2x scale for better visibility

    -- Draw crank indicator if docked
    if pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
    end

    -- Draw progress
    local progressText = "Question " .. currentPosition .. " of 52"
    gfx.drawTextAligned(progressText, 200, 180, kTextAlignment.center)

    -- Draw instructions
    gfx.drawTextAligned("Use crank to select card", 200, 210, kTextAlignment.center)
    gfx.drawTextAligned("(A) Confirm answer", 200, 225, kTextAlignment.center)
end

local function drawFeedback()
    gfx.clear()

    if userWasCorrect then
        gfx.drawTextAligned("Correct!", 200, 40, kTextAlignment.center)
    else
        gfx.drawTextAligned("Wrong!", 200, 40, kTextAlignment.center)
        gfx.drawTextAligned("Correct answer:", 200, 70, kTextAlignment.center)
        -- Draw the correct card
        drawCard(correctAnswer, 200, 120, 2)  -- 2x scale
    end

    -- Draw score
    local scoreText = "Score: " .. score .. "/" .. (currentPosition)
    gfx.drawTextAligned(scoreText, 200, 180, kTextAlignment.center)

    -- Draw continue instruction
    gfx.drawTextAligned("(A) Continue", 200, 210, kTextAlignment.center)
end

local function drawComplete()
    gfx.clear()

    gfx.drawTextAligned("Quiz Complete!", 200, 60, kTextAlignment.center)

    local finalScore = "Final Score: " .. score .. "/52"
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned(finalScore, 200, 100, kTextAlignment.center)
    gfx.setFont()

    local percentage = math.floor((score / 52) * 100)
    gfx.drawTextAligned(percentage .. "% correct", 200, 130, kTextAlignment.center)

    gfx.drawTextAligned("(A) Play Again", 200, 180, kTextAlignment.center)
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
