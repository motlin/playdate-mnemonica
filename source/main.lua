import "CoreLibs/graphics"
import "CoreLibs/ui"
import "GameState"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local snd <const> = playdate.sound

-- Initialize GameState manager
import "GameState"
local gameState = GameState:new()

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

-- UI state (not managed by GameState)
local selectedCard = 1 -- Index in uspccOrder (1-52) for crank selection
local showingCorrectAnswer = false
local menuSelection = 1 -- Currently selected menu item (1-3)

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

        -- Play crank tick sound
        if gameState.soundEnabled then sounds.crankTick:play() end
    end
end

local function checkAnswer()
    local correctCard = mnemonicaStack[gameState.currentPosition]
    local selectedCardName = uspccOrder[selectedCard]

    gameState.correctAnswer = correctCard
    gameState:submitAnswer(selectedCardName, false)
    showingCorrectAnswer = true

    if gameState.userWasCorrect then
        if gameState.soundEnabled then sounds.correct:play() end
    else
        if gameState.soundEnabled then sounds.incorrect:play() end
    end
end

local function passQuestion()
    local correctCard = mnemonicaStack[gameState.currentPosition]

    gameState.correctAnswer = correctCard
    gameState:submitAnswer("PASSED", true)
    showingCorrectAnswer = true

    if gameState.soundEnabled then sounds.incorrect:play() end
end

local function nextQuestion()
    showingCorrectAnswer = false
    gameState:nextQuestion()

    if gameState.quizState == GameState.QUIZ_STATES.COMPLETE then
        if gameState.soundEnabled then sounds.sessionComplete:play() end
    else
        -- Set correct answer for next question
        gameState.correctAnswer = mnemonicaStack[gameState.currentPosition]
    end
end

local function resetGame()
    gameState:startQuiz(GameState.MODES.QUIZ_NUMBER_TO_CARD)
    gameState.correctAnswer = mnemonicaStack[gameState.currentPosition]
    selectedCard = 1
    showingCorrectAnswer = false
    crankAccumulator = 0
    lastCrankValue = pd.getCrankPosition()
end

local function startSelectedMode()
    local modes = {
        GameState.MODES.QUIZ_NUMBER_TO_CARD,
        GameState.MODES.QUIZ_CARD_TO_NUMBER,
        GameState.MODES.STUDY
    }

    local selectedMode = modes[menuSelection]

    -- Save the selected menu mode for next startup
    gameState.lastSelectedMenuMode = menuSelection
    gameState:saveSettings()

    -- Only Number→Card mode is currently implemented
    if selectedMode == GameState.MODES.QUIZ_NUMBER_TO_CARD then
        gameState:startQuiz(selectedMode)
        gameState.correctAnswer = mnemonicaStack[gameState.currentPosition]
        selectedCard = 1
        showingCorrectAnswer = false
        crankAccumulator = 0
        lastCrankValue = pd.getCrankPosition()
    else
        -- These modes will be implemented later
        -- For now, just start the implemented mode
        gameState:startQuiz(GameState.MODES.QUIZ_NUMBER_TO_CARD)
        gameState.correctAnswer = mnemonicaStack[gameState.currentPosition]
        selectedCard = 1
        showingCorrectAnswer = false
        crankAccumulator = 0
        lastCrankValue = pd.getCrankPosition()
    end
end

local function drawQuiz()
    gfx.clear()

    -- Draw question at top
    local questionText = "Position " .. gameState.currentPosition .. "?"
    gfx.drawTextAligned(questionText, 200, 10, kTextAlignment.center)

    -- Draw timer in top-right corner
    gameState:updateTimer()
    local timeText = gameState:getFormattedTime()
    gfx.drawTextAligned(timeText, 380, 10, kTextAlignment.right)

    -- Draw selected card at 1x scale (50x70 pixels)
    local selectedCardName = uspccOrder[selectedCard]
    drawCard(selectedCardName, 200, 70, 1)  -- 1x scale, natural size

    -- Draw crank indicator if docked
    if pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
    end

    -- Draw progress
    local progressText = gameState:getProgressString()
    gfx.drawTextAligned(progressText, 200, 150, kTextAlignment.center)

    -- Draw instructions
    gfx.drawTextAligned("Use crank to select card", 200, 185, kTextAlignment.center)
    gfx.drawTextAligned("(A) Confirm answer", 200, 200, kTextAlignment.center)
    gfx.drawTextAligned("(B) Pass/Skip question", 200, 215, kTextAlignment.center)
end

local function drawFeedback()
    gfx.clear()

    -- Draw timer in top-right corner (keep it visible during feedback)
    gameState:updateTimer()
    local timeText = gameState:getFormattedTime()
    gfx.drawTextAligned(timeText, 380, 10, kTextAlignment.right)

    if gameState.userWasCorrect then
        gfx.drawTextAligned("Correct!", 200, 20, kTextAlignment.center)
        -- Show the correct card at 1x scale
        drawCard(gameState.correctAnswer, 200, 70, 1)
    elseif gameState.userPassed then
        gfx.drawTextAligned("You passed!", 200, 10, kTextAlignment.center)

        -- Show correct answer
        gfx.drawTextAligned("Correct answer:", 200, 35, kTextAlignment.center)
        drawCard(gameState.correctAnswer, 200, 80, 1)
    else
        gfx.drawTextAligned("Wrong!", 200, 10, kTextAlignment.center)

        -- Show user's wrong answer on the left at 1x scale
        gfx.drawTextAligned("You picked:", 100, 35, kTextAlignment.center)
        drawCard(gameState.userAnswer, 100, 80, 1)

        -- Show correct answer on the right at 1x scale
        gfx.drawTextAligned("Correct:", 300, 35, kTextAlignment.center)
        drawCard(gameState.correctAnswer, 300, 80, 1)
    end

    -- Draw score
    local scoreText = "Score: " .. gameState.score .. "/" .. gameState.questionsAnswered
    gfx.drawTextAligned(scoreText, 200, 160, kTextAlignment.center)

    -- Draw continue instruction
    gfx.drawTextAligned("(A) Continue", 200, 200, kTextAlignment.center)
end

local function drawComplete()
    gfx.clear()

    -- Check if this is a new high score
    local isNewBest = gameState:isNewHighScore()

    if isNewBest then
        gfx.drawTextAligned("NEW HIGH SCORE!", 200, 30, kTextAlignment.center)
    else
        gfx.drawTextAligned("Quiz Complete!", 200, 30, kTextAlignment.center)
    end

    local finalScore = "Final Score: " .. gameState.score .. "/52"
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned(finalScore, 200, 60, kTextAlignment.center)
    gfx.setFont()

    local percentage = gameState:getScorePercentage()
    gfx.drawTextAligned(percentage .. "% correct", 200, 85, kTextAlignment.center)

    -- Display final time
    local finalTime = "Time: " .. gameState:getFormattedTime()
    gfx.drawTextAligned(finalTime, 200, 105, kTextAlignment.center)

    -- Display high scores
    gfx.drawTextAligned("── High Scores ──", 200, 135, kTextAlignment.center)

    local modeScores = gameState:getCurrentModeHighScores()
    local bestScoreText = "Best Score: " .. modeScores.bestScore .. "/52"
    if modeScores.bestTime < math.huge then
        local minutes = math.floor(modeScores.bestTime / 60)
        local seconds = math.floor(modeScores.bestTime % 60)
        local bestTimeText = string.format("%d:%02d", minutes, seconds)
        bestScoreText = bestScoreText .. " (" .. bestTimeText .. ")"
    end

    -- Highlight if current score equals or beats the high score
    if isNewBest then
        gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    end
    gfx.drawTextAligned(bestScoreText, 200, 155, kTextAlignment.center)
    gfx.setFont()

    gfx.drawTextAligned("(A) Play Again", 200, 190, kTextAlignment.center)
    gfx.drawTextAligned("(B) Main Menu", 200, 205, kTextAlignment.center)
end

local function drawMenu()
    gfx.clear()

    -- Draw title
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Mnemonica Stack", 200, 30, kTextAlignment.center)
    gfx.drawTextAligned("Memorizer", 200, 50, kTextAlignment.center)
    gfx.setFont()

    -- Menu options
    local menuItems = {
        "Number → Card Quiz",
        "Card → Number Quiz",
        "Study Mode"
    }

    -- Draw menu items with selection indicator
    for i, item in ipairs(menuItems) do
        local y = 100 + (i - 1) * 30

        if i == menuSelection then
            -- Draw selection box
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRoundRect(60, y - 5, 280, 25, 4)
            gfx.setColor(gfx.kColorWhite)
            gfx.drawTextAligned(item, 200, y, kTextAlignment.center)
            gfx.setColor(gfx.kColorBlack)
        else
            gfx.drawTextAligned(item, 200, y, kTextAlignment.center)
        end
    end

    -- Draw instructions
    gfx.drawTextAligned("Use D-pad to select", 200, 200, kTextAlignment.center)
    gfx.drawTextAligned("(A) Start selected mode", 200, 215, kTextAlignment.center)
end

function playdate.update()
    -- Handle pause state
    if gameState.isPaused then
        gfx.clear()
        gfx.drawTextAligned("PAUSED", 200, 100, kTextAlignment.center)
        gfx.drawTextAligned("Press Menu to resume", 200, 130, kTextAlignment.center)
        return
    end

    if gameState.currentMode == GameState.MODES.MENU then
        drawMenu()

        -- Handle menu navigation
        if pd.buttonJustPressed(pd.kButtonUp) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            menuSelection = menuSelection - 1
            if menuSelection < 1 then menuSelection = 3 end
        elseif pd.buttonJustPressed(pd.kButtonDown) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            menuSelection = menuSelection + 1
            if menuSelection > 3 then menuSelection = 1 end
        elseif pd.buttonJustPressed(pd.kButtonA) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            startSelectedMode()
        end

    elseif gameState.quizState == GameState.QUIZ_STATES.QUESTION then
        updateSelectedCard()
        drawQuiz()

        if pd.buttonJustPressed(pd.kButtonA) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            checkAnswer()
        elseif pd.buttonJustPressed(pd.kButtonB) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            passQuestion()
        end

    elseif gameState.quizState == GameState.QUIZ_STATES.FEEDBACK then
        drawFeedback()

        if pd.buttonJustPressed(pd.kButtonA) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            nextQuestion()
        end

    elseif gameState.quizState == GameState.QUIZ_STATES.COMPLETE then
        drawComplete()

        if pd.buttonJustPressed(pd.kButtonA) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            resetGame()
        elseif pd.buttonJustPressed(pd.kButtonB) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            -- Return to main menu
            gameState.currentMode = GameState.MODES.MENU
        end
    end
end

-- Menu callback for pause/resume
local menu = pd.getSystemMenu()

local function updateMenuItems()
    menu:removeAllMenuItems()

    -- Don't show pause/resume in menu mode
    if gameState.currentMode ~= GameState.MODES.MENU then
        if gameState.isPaused then
            menu:addMenuItem("Resume", function()
                gameState:resume()
                updateMenuItems()
            end)
        else
            menu:addMenuItem("Pause", function()
                gameState:pause()
                updateMenuItems()
            end)
        end

        menu:addMenuItem("Restart Quiz", function()
            resetGame()
            updateMenuItems()
        end)

        menu:addMenuItem("Main Menu", function()
            gameState.currentMode = GameState.MODES.MENU
            updateMenuItems()
        end)
    end
end

-- Initialize game
math.randomseed(pd.getSecondsSinceEpoch())  -- Seed random number generator
gameState:loadHighScores()  -- Load saved high scores from persistent storage
gameState:loadSettings()  -- Load settings including last selected menu mode
menuSelection = gameState.lastSelectedMenuMode  -- Restore last selected menu item
gameState.currentMode = GameState.MODES.MENU  -- Start at main menu
lastCrankValue = pd.getCrankPosition()  -- Initialize crank position
updateMenuItems()  -- Set up menu
