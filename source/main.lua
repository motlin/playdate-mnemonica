import "CoreLibs/graphics"
import "CoreLibs/ui"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local snd <const> = playdate.sound

-- Load card sprites as a single image
local cardSpriteSheet = gfx.image.new("images/cards")
assert(cardSpriteSheet, "Failed to load card sprite sheet")

-- Load sound effects
local sounds = {}
sounds.crankTick = snd.sampleplayer.new("sounds/crank_tick")
sounds.buttonPress = snd.sampleplayer.new("sounds/button_press")
sounds.correct = snd.sampleplayer.new("sounds/correct")
sounds.incorrect = snd.sampleplayer.new("sounds/incorrect")
sounds.sessionComplete = snd.sampleplayer.new("sounds/session_complete")

assert(sounds.crankTick, "Failed to load crank_tick.wav")
assert(sounds.buttonPress, "Failed to load button_press.wav")
assert(sounds.correct, "Failed to load correct.wav")
assert(sounds.incorrect, "Failed to load incorrect.wav")
assert(sounds.sessionComplete, "Failed to load session_complete.wav")

-- Store individual card images in a table
local cardImages = {}
local cardWidth, cardHeight = 50, 70

-- Extract individual card images from the sprite sheet
-- The sheet has 13 cards per row, 5 rows total
for row = 1, 5 do
    for col = 1, 13 do
        local x = (col - 1) * cardWidth
        local y = (row - 1) * cardHeight
        local cardImage = gfx.image.new(cardWidth, cardHeight)
        gfx.pushContext(cardImage)
        cardSpriteSheet:draw(-x, -y)
        gfx.popContext()
        local index = (row - 1) * 13 + col
        cardImages[index] = cardImage
    end
end

-- Card lookup mapping (card name to sprite index)
-- The sprite sheet layout:
-- Row 1: Blank, Jokers, Card backs (indices 1-13)
-- Row 2: A-K of Hearts (indices 14-26)
-- Row 3: A-K of Diamonds (indices 27-39)
-- Row 4: A-K of Spades (indices 40-52)
-- Row 5: A-K of Clubs (indices 53-65)
local cardToIndex = {}
local suits = {"H", "D", "S", "C"}  -- Order matches rows in sprite sheet
local suitRows = {2, 3, 4, 5}  -- Row numbers for each suit (1-indexed)
local ranks = {"A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"}

-- Build card name to sprite index mapping
for suitIdx, suit in ipairs(suits) do
    for rankIdx, rank in ipairs(ranks) do
        local cardName = rank .. suit
        -- Calculate index based on actual row position
        local row = suitRows[suitIdx]
        local index = (row - 1) * 13 + rankIdx
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
local userAnswer = ""  -- Store what the user selected
local userWasCorrect = false
local userPassed = false  -- Track if user passed on this question

-- Shuffled question order
local questionOrder = {}  -- Array of positions 1-52 in random order
local questionIndex = 1   -- Current index in questionOrder array

-- Crank handling
local lastCrankValue = 0
local crankAccumulator = 0

-- Fisher-Yates shuffle algorithm
local function shuffleArray(array)
    local arrayCount = #array
    for i = arrayCount, 2, -1 do
        local j = math.random(1, i)
        array[i], array[j] = array[j], array[i]
    end
end

-- Initialize shuffled question order
local function initializeQuestionOrder()
    questionOrder = {}
    for i = 1, 52 do
        questionOrder[i] = i
    end
    shuffleArray(questionOrder)
    questionIndex = 1
    currentPosition = questionOrder[questionIndex]
end

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

        -- Play crank tick sound
        sounds.crankTick:play()
    end
end

local function checkAnswer()
    local correctCard = mnemonicaStack[currentPosition]
    local selectedCardName = uspccOrder[selectedCard]

    userWasCorrect = (selectedCardName == correctCard)
    correctAnswer = correctCard
    userAnswer = selectedCardName  -- Store what the user selected
    userPassed = false
    showingCorrectAnswer = true

    if userWasCorrect then
        score = score + 1
        sounds.correct:play()
    else
        sounds.incorrect:play()
    end

    gameState = "feedback"
end

local function passQuestion()
    local correctCard = mnemonicaStack[currentPosition]

    userWasCorrect = false
    correctAnswer = correctCard
    userAnswer = "PASSED"
    userPassed = true
    showingCorrectAnswer = true

    sounds.incorrect:play()
    gameState = "feedback"
end

local function nextQuestion()
    showingCorrectAnswer = false
    userPassed = false
    questionIndex = questionIndex + 1

    if questionIndex > 52 then
        gameState = "complete"
        sounds.sessionComplete:play()
    else
        currentPosition = questionOrder[questionIndex]
        gameState = "quiz"
    end
end

local function resetGame()
    initializeQuestionOrder()  -- Initialize shuffled order
    selectedCard = 1
    score = 0
    showingCorrectAnswer = false
    userPassed = false
    gameState = "quiz"
    crankAccumulator = 0
    lastCrankValue = pd.getCrankPosition()
end

local function drawQuiz()
    gfx.clear()

    -- Draw question at top
    local questionText = "Position " .. currentPosition .. "?"
    gfx.drawTextAligned(questionText, 200, 10, kTextAlignment.center)

    -- Draw selected card at 1x scale (50x70 pixels)
    local selectedCardName = uspccOrder[selectedCard]
    drawCard(selectedCardName, 200, 70, 1)  -- 1x scale, natural size

    -- Draw crank indicator if docked
    if pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
    end

    -- Draw progress
    local progressText = "Question " .. questionIndex .. " of 52"
    gfx.drawTextAligned(progressText, 200, 150, kTextAlignment.center)

    -- Draw instructions
    gfx.drawTextAligned("Use crank to select card", 200, 185, kTextAlignment.center)
    gfx.drawTextAligned("(A) Confirm answer", 200, 200, kTextAlignment.center)
    gfx.drawTextAligned("(B) Pass/Skip question", 200, 215, kTextAlignment.center)
end

local function drawFeedback()
    gfx.clear()

    if userWasCorrect then
        gfx.drawTextAligned("Correct!", 200, 20, kTextAlignment.center)
        -- Show the correct card at 1x scale
        drawCard(correctAnswer, 200, 70, 1)
    elseif userPassed then
        gfx.drawTextAligned("You passed!", 200, 10, kTextAlignment.center)

        -- Show correct answer
        gfx.drawTextAligned("Correct answer:", 200, 35, kTextAlignment.center)
        drawCard(correctAnswer, 200, 80, 1)
    else
        gfx.drawTextAligned("Wrong!", 200, 10, kTextAlignment.center)

        -- Show user's wrong answer on the left at 1x scale
        gfx.drawTextAligned("You picked:", 100, 35, kTextAlignment.center)
        drawCard(userAnswer, 100, 80, 1)

        -- Show correct answer on the right at 1x scale
        gfx.drawTextAligned("Correct:", 300, 35, kTextAlignment.center)
        drawCard(correctAnswer, 300, 80, 1)
    end

    -- Draw score
    local scoreText = "Score: " .. score .. "/" .. questionIndex
    gfx.drawTextAligned(scoreText, 200, 160, kTextAlignment.center)

    -- Draw continue instruction
    gfx.drawTextAligned("(A) Continue", 200, 200, kTextAlignment.center)
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
            sounds.buttonPress:play()
            checkAnswer()
        elseif pd.buttonJustPressed(pd.kButtonB) then
            sounds.buttonPress:play()
            passQuestion()
        end

    elseif gameState == "feedback" then
        drawFeedback()

        if pd.buttonJustPressed(pd.kButtonA) then
            sounds.buttonPress:play()
            nextQuestion()
        end

    elseif gameState == "complete" then
        drawComplete()

        if pd.buttonJustPressed(pd.kButtonA) then
            sounds.buttonPress:play()
            resetGame()
        end
    end
end

-- Initialize game
math.randomseed(pd.getSecondsSinceEpoch())  -- Seed random number generator
initializeQuestionOrder()  -- Initialize shuffled question order
lastCrankValue = pd.getCrankPosition()  -- Initialize crank position
