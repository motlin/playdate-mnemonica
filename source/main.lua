import "CoreLibs/graphics"
import "CoreLibs/ui"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local snd <const> = playdate.sound

-- Import modules
import "GameState"
import "DialRenderer"
import "NumberDialRenderer"
import "MistakeReviewMode"
import "UIHelpers"

-- Initialize GameState manager
local gameState = GameState:new()

-- Initialize renderers (will be initialized after resources are loaded)
local dialRenderer = nil
local numberDialRenderer = nil

-- Load card sprites as a single image
local cardSpriteSheet = gfx.image.new("images/cards")
assert(cardSpriteSheet, "Failed to load card sprite sheet")

-- Load custom fonts
local marbleMadnessFont = gfx.font.new("fonts/MarbleMadness")
assert(marbleMadnessFont, "Failed to load Marble Madness font")

-- Load sound effects
local sounds = {}
sounds.crankTick = snd.sampleplayer.new("sounds/crank_tick")
sounds.buttonPress = snd.sampleplayer.new("sounds/button_press")
sounds.menuMove = snd.sampleplayer.new("sounds/menu_move")
sounds.correct = snd.sampleplayer.new("sounds/correct")
sounds.incorrect = snd.sampleplayer.new("sounds/incorrect")
sounds.sessionComplete = snd.sampleplayer.new("sounds/session_complete")

assert(sounds.crankTick, "Failed to load crank_tick.wav")
assert(sounds.buttonPress, "Failed to load button_press.wav")
assert(sounds.menuMove, "Failed to load menu_move.wav")
assert(sounds.correct, "Failed to load correct.wav")
assert(sounds.incorrect, "Failed to load incorrect.wav")
assert(sounds.sessionComplete, "Failed to load session_complete.wav")

-- Set volume levels for sounds (0.0 to 1.0)
sounds.buttonPress:setVolume(0.3)

-- Store individual card images in a table
local cardImages = {}
local cardWidth, cardHeight = 50, 70

-- Cache for scaled card images to avoid expensive scaling operations
-- Limited cache size to prevent memory bloat
local scaledCardCache = {}
local maxCacheSize = 20  -- Limit cached scaled images to prevent memory issues

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

-- Function to get a cached scaled card image with LRU eviction
local function getCachedScaledCard(cardIndex, scale)
    if not cardIndex or not cardImages[cardIndex] then
        return nil
    end

    -- Round scale to nearest 0.2 to further limit cache size
    local roundedScale = math.floor(scale * 5 + 0.5) / 5
    local cacheKey = cardIndex .. "_" .. roundedScale

    -- Check if already cached
    if scaledCardCache[cacheKey] then
        return scaledCardCache[cacheKey]
    end

    -- Check cache size limit
    local cacheCount = 0
    for _ in pairs(scaledCardCache) do
        cacheCount = cacheCount + 1
    end

    -- If cache is full, remove oldest entry (simple eviction)
    if cacheCount >= maxCacheSize then
        -- Remove first entry found (not true LRU, but simple)
        for key, _ in pairs(scaledCardCache) do
            scaledCardCache[key] = nil
            break
        end
    end

    -- Create and cache new scaled image
    scaledCardCache[cacheKey] = cardImages[cardIndex]:scaledImage(roundedScale)
    return scaledCardCache[cacheKey]
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

-- Initialize DialRenderer after card images are loaded
dialRenderer = DialRenderer:new(cardImages, cardWidth, cardHeight)

-- Initialize NumberDialRenderer
numberDialRenderer = NumberDialRenderer:new()

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
local selectedNumber = 1 -- Selected position number (1-52) for Card to Number quiz
local showingCorrectAnswer = false
local menuSelection = 1 -- Currently selected menu item (1-4)
local settingsSelection = 1 -- Currently selected settings item
local showingCredits = false -- Track if we're showing the credits screen
local studyModePosition = 1 -- Current position in study mode (1-52)

-- UI state for completion screen
local completionScreenState = {
    showingMistakes = false,
    mistakeScrollOffset = 0,
    selectedOption = 1  -- 1=Play Again, 2=Review Mistakes, 3=Main Menu
}

-- Crank handling
local lastCrankPosition = 0
local degreesPerCard = 360 / 52  -- Each card gets approximately 6.92 degrees
local crankVelocity = 0  -- Track crank movement speed for smooth feel


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
    local index = cardToIndex[cardName]
    if index and cardImages[index] then
        if scale and scale ~= 1 then
            local scaledImage = getCachedScaledCard(index, scale)
            if scaledImage then
                scaledImage:drawCentered(x, y)
            else
                cardImages[index]:drawCentered(x, y)
            end
        else
            cardImages[index]:drawCentered(x, y)
        end
    else
        -- Fallback to text if image not found
        gfx.drawTextAligned(cardName, x, y, kTextAlignment.center)
    end
end

local function updateSelectedCard()
    local crankPosition = pd.getCrankPosition()  -- 0-359 degrees

    -- Only process if crank position has changed significantly (reduces unnecessary calculations)
    if math.abs(crankPosition - lastCrankPosition) < 0.5 then
        return  -- No significant change, skip processing
    end

    -- Calculate crank velocity for smooth feel
    local delta = crankPosition - lastCrankPosition
    -- Handle wrap-around at 0/360 boundary
    if delta > 180 then
        delta = delta - 360
    elseif delta < -180 then
        delta = delta + 360
    end
    crankVelocity = delta

    -- Apply crank sensitivity to effective degrees per card
    local effectiveDegreesPerCard = degreesPerCard / gameState.crankSensitivity

    -- Map crank position to a floating point card position
    local floatCard = (crankPosition / effectiveDegreesPerCard) + 1

    -- Add subtle snap behavior when crank is moving slowly
    local snapThreshold = 0.35  -- How close to snap to the nearest card
    local velocityThreshold = 3  -- Degrees per frame to consider "slow"

    if math.abs(crankVelocity) < velocityThreshold then
        -- When moving slowly, snap to nearest card position
        local nearestCard = math.floor(floatCard + 0.5)
        local distanceToNearest = math.abs(floatCard - nearestCard)

        if distanceToNearest < snapThreshold then
            floatCard = nearestCard
        end
    end

    -- Convert to integer card position
    local newCard = math.floor(floatCard)

    -- Handle edge case at position 360 degrees (wraps to card 1)
    if newCard > 52 then newCard = 1 end
    if newCard < 1 then newCard = 1 end

    -- Check if card changed to play sound effect
    if newCard ~= selectedCard then
        selectedCard = newCard
        -- Play crank tick sound when card changes
        if gameState.soundEnabled then sounds.crankTick:play() end
    end

    lastCrankPosition = crankPosition
end

local function updateSelectedNumber()
    local crankPosition = pd.getCrankPosition()  -- 0-359 degrees

    -- Only process if crank position has changed significantly (reduces unnecessary calculations)
    if math.abs(crankPosition - lastCrankPosition) < 0.5 then
        return  -- No significant change, skip processing
    end

    local degreesPerNumber = 360 / 52  -- Each number gets approximately 6.92 degrees

    -- Calculate crank velocity for smooth feel
    local delta = crankPosition - lastCrankPosition
    -- Handle wrap-around at 0/360 boundary
    if delta > 180 then
        delta = delta - 360
    elseif delta < -180 then
        delta = delta + 360
    end
    crankVelocity = delta

    -- Apply crank sensitivity to effective degrees per number
    local effectiveDegreesPerNumber = degreesPerNumber / gameState.crankSensitivity

    -- Map crank position to a floating point number position
    local floatNumber = (crankPosition / effectiveDegreesPerNumber) + 1

    -- Add subtle snap behavior when crank is moving slowly
    local snapThreshold = 0.35  -- How close to snap to the nearest number
    local velocityThreshold = 3  -- Degrees per frame to consider "slow"

    if math.abs(crankVelocity) < velocityThreshold then
        -- When moving slowly, snap to nearest number position
        local nearestNumber = math.floor(floatNumber + 0.5)
        local distanceToNearest = math.abs(floatNumber - nearestNumber)

        if distanceToNearest < snapThreshold then
            floatNumber = nearestNumber
        end
    end

    -- Convert to integer number position
    local newNumber = math.floor(floatNumber)

    -- Handle edge case at position 360 degrees (wraps to number 1)
    if newNumber > 52 then newNumber = 1 end
    if newNumber < 1 then newNumber = 1 end

    -- Check if number changed to play sound effect
    if newNumber ~= selectedNumber then
        selectedNumber = newNumber
        -- Play crank tick sound when number changes
        if gameState.soundEnabled then sounds.crankTick:play() end
    end

    lastCrankPosition = crankPosition
end

local function checkAnswer()
    if gameState:getQuizMode() == GameState.MODES.QUIZ_NUMBER_TO_CARD then
        -- Number to Card mode: Check if selected card matches the position
        local correctCard = mnemonicaStack[gameState.currentPosition]
        local selectedCardName = uspccOrder[selectedCard]

        gameState.correctAnswer = correctCard
        gameState:submitAnswer(selectedCardName, false)
        showingCorrectAnswer = true
    elseif gameState:getQuizMode() == GameState.MODES.QUIZ_CARD_TO_NUMBER then
        -- Card to Number mode: Check if selected number matches the card's position
        local correctPosition = gameState.currentPosition

        gameState.correctAnswer = tostring(correctPosition)
        gameState:submitAnswer(tostring(selectedNumber), false)
        showingCorrectAnswer = true
    end

    if gameState.userWasCorrect then
        if gameState.soundEnabled then sounds.correct:play() end
    else
        if gameState.soundEnabled then sounds.incorrect:play() end
    end
end

local function nextQuestion()
    showingCorrectAnswer = false
    gameState:nextQuestion()

    if gameState.quizState == GameState.QUIZ_STATES.COMPLETE then
        if gameState.soundEnabled then sounds.sessionComplete:play() end
    else
        -- Set correct answer for next question
        if gameState:getQuizMode() == GameState.MODES.QUIZ_NUMBER_TO_CARD then
            gameState.correctAnswer = mnemonicaStack[gameState.currentPosition]
        elseif gameState:getQuizMode() == GameState.MODES.QUIZ_CARD_TO_NUMBER then
            gameState.correctAnswer = tostring(gameState.currentPosition)
        end
    end
end

local function resetGame()
    -- Keep the current mode when resetting
    local mode = gameState.currentMode
    if mode == GameState.MODES.MENU then
        mode = GameState.MODES.QUIZ_NUMBER_TO_CARD  -- Default to Number to Card
    end

    gameState:startQuiz(mode)

    if mode == GameState.MODES.QUIZ_NUMBER_TO_CARD then
        gameState.correctAnswer = mnemonicaStack[gameState.currentPosition]
        selectedCard = 1
    elseif mode == GameState.MODES.QUIZ_CARD_TO_NUMBER then
        gameState.correctAnswer = tostring(gameState.currentPosition)
        selectedNumber = 1
    end

    showingCorrectAnswer = false
    lastCrankPosition = pd.getCrankPosition()

    -- Reset completion screen state
    completionScreenState.showingMistakes = false
    completionScreenState.mistakeScrollOffset = 0
    completionScreenState.selectedOption = 1
end

local function startMistakeReview()
    -- Start the mistake review mode (study phase first)
    if gameState:startMistakeReview() then
        -- Reset UI state for study phase
        showingCorrectAnswer = false
        lastCrankPosition = pd.getCrankPosition()

        -- Reset completion screen state
        completionScreenState.showingMistakes = false
        completionScreenState.mistakeScrollOffset = 0
        completionScreenState.selectedOption = 1
    end
end

-- Simon Mode Functions - Forward declarations needed before startSelectedMode
local startSimonRound
local drawSimonShowing
local drawSimonWaiting
local drawSimonInput
local drawSimonFeedback
local checkSimonAnswer
local updateSimonMode

startSimonRound = function()
    gameState.simonMode.currentRound = gameState.simonMode.currentRound + 1

    -- Add a new random position to the sequence
    local newPosition = math.random(1, 52)
    table.insert(gameState.simonMode.sequence, newPosition)

    -- Reset for showing sequence
    gameState.simonMode.phase = "SHOWING"
    gameState.simonMode.sequenceIndex = 1
    gameState.simonMode.displayTimer = 0
    gameState.simonMode.playerIndex = 1
    gameState.simonMode.selectedInput = "card"
end

local function startSelectedMode()
    local modes = {
        GameState.MODES.QUIZ_NUMBER_TO_CARD,
        GameState.MODES.QUIZ_CARD_TO_NUMBER,
        GameState.MODES.STUDY,
        GameState.MODES.SIMON,
        GameState.MODES.HIGH_SCORES,
        GameState.MODES.SETTINGS
    }

    local selectedMode = modes[menuSelection]

    -- Save the selected menu mode for next startup
    gameState.lastSelectedMenuMode = menuSelection
    gameState:saveSettings()

    -- Start the selected quiz mode
    if selectedMode == GameState.MODES.QUIZ_NUMBER_TO_CARD then
        gameState:startQuiz(selectedMode)
        gameState.correctAnswer = mnemonicaStack[gameState.currentPosition]
        selectedCard = 1
        showingCorrectAnswer = false
        lastCrankPosition = pd.getCrankPosition()
    elseif selectedMode == GameState.MODES.QUIZ_CARD_TO_NUMBER then
        gameState:startQuiz(selectedMode)
        gameState.correctAnswer = tostring(gameState.currentPosition)
        selectedNumber = 1
        showingCorrectAnswer = false
        lastCrankPosition = pd.getCrankPosition()
    elseif selectedMode == GameState.MODES.STUDY then
        -- Study mode
        gameState.currentMode = GameState.MODES.STUDY
        studyModePosition = 1
        lastCrankPosition = pd.getCrankPosition()
    elseif selectedMode == GameState.MODES.SIMON then
        -- Simon mode
        gameState.currentMode = GameState.MODES.SIMON
        -- Initialize Simon mode
        gameState.simonMode.sequence = {}
        gameState.simonMode.playerIndex = 1
        gameState.simonMode.currentRound = 0
        gameState.simonMode.phase = "SHOWING"
        gameState.simonMode.sequenceIndex = 1
        gameState.simonMode.displayTimer = 0
        gameState.simonMode.isCorrect = true
        gameState.simonMode.selectedInput = "card"
        selectedCard = 1
        selectedNumber = 1
        -- Start first round
        startSimonRound()
    elseif selectedMode == GameState.MODES.HIGH_SCORES then
        -- High scores screen
        gameState.currentMode = GameState.MODES.HIGH_SCORES
    else
        -- Settings mode
        gameState.currentMode = GameState.MODES.SETTINGS
        settingsSelection = 1
        showingCredits = false
    end
end

local function drawQuizNumberToCard()
    gfx.clear()

    -- Draw question at top with bold text
    local questionText = "Position " .. gameState.currentPosition .. "?"
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned(questionText, 200, 10, kTextAlignment.center)
    gfx.setFont()

    -- Draw timer in top-right corner
    gameState:updateTimer()
    local timeText = gameState:getFormattedTime()
    gfx.drawTextAligned(timeText, 380, 10, kTextAlignment.right)

    -- Draw the rotating dial with cards
    if dialRenderer then
        dialRenderer:drawFrame()  -- Draw dial background/frame
        dialRenderer:draw(uspccOrder, selectedCard, getCardImage, drawCard)
    else
        -- Fallback to simple card display if dial renderer not available
        local selectedCardName = uspccOrder[selectedCard]
        drawCard(selectedCardName, 200, 70, 1)
    end

    -- Draw crank indicator if docked
    if pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
    end

    -- Draw progress at bottom
    local progressText = gameState:getProgressString()
    gfx.drawTextAligned(progressText, 200, 200, kTextAlignment.center)

    -- Draw spaced repetition indicator if active
    if gameState.usingSpacedRepetition then
        gfx.drawTextAligned("[Smart Mode]" , 200, 185, kTextAlignment.center)
    end

    -- Draw instructions
    gfx.drawTextAligned("Crank/D-pad: Select | A: Confirm | B: Menu", 200, 220, kTextAlignment.center)
end

local function drawQuizCardToNumber()
    gfx.clear()

    -- Draw question text at top with bold text
    local questionCard = mnemonicaStack[gameState.currentPosition]
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("What position is this card?", 200, 10, kTextAlignment.center)
    gfx.setFont()

    -- Draw the question card on the LEFT side
    drawCard(questionCard, 80, 100, 1)

    -- Draw timer in top-right corner
    gameState:updateTimer()
    local timeText = gameState:getFormattedTime()
    gfx.drawTextAligned(timeText, 380, 10, kTextAlignment.right)

    -- Draw the rotating number dial
    if numberDialRenderer then
        numberDialRenderer:drawFrame()  -- Draw dial background/frame
        numberDialRenderer:draw(selectedNumber)
    else
        -- Fallback to simple number display
        gfx.drawTextAligned("Position: " .. selectedNumber, 200, 120, kTextAlignment.center)
    end

    -- Draw crank indicator if docked
    if pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
    end

    -- Draw progress at bottom
    local progressText = gameState:getProgressString()
    gfx.drawTextAligned(progressText, 200, 200, kTextAlignment.center)

    -- Draw spaced repetition indicator if active
    if gameState.usingSpacedRepetition then
        gfx.drawTextAligned("[Smart Mode]" , 200, 185, kTextAlignment.center)
    end

    -- Draw instructions
    gfx.drawTextAligned("Crank/D-pad: Select | A: Confirm | B: Menu", 200, 220, kTextAlignment.center)
end

local function drawQuiz()
    if gameState.currentMode == GameState.MODES.QUIZ_NUMBER_TO_CARD then
        drawQuizNumberToCard()
    elseif gameState.currentMode == GameState.MODES.QUIZ_CARD_TO_NUMBER then
        drawQuizCardToNumber()
    end
end

local function drawFeedback()
    gfx.clear()

    -- Draw timer in top-right corner (keep it visible during feedback)
    gameState:updateTimer()
    local timeText = gameState:getFormattedTime()
    gfx.drawTextAligned(timeText, 380, 10, kTextAlignment.right)

    if gameState:getQuizMode() == GameState.MODES.QUIZ_NUMBER_TO_CARD then
        -- Number to Card mode feedback
        if gameState.userWasCorrect then
            gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
            gfx.drawTextAligned("Correct!", 200, 20, kTextAlignment.center)
            gfx.setFont()
            -- Show the correct card at 1x scale
            drawCard(gameState.correctAnswer, 200, 90, 1)
        elseif gameState.userPassed then
            gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
            gfx.drawTextAligned("You passed!", 200, 10, kTextAlignment.center)
            gfx.setFont()

            -- Show correct answer
            gfx.drawTextAligned("Correct answer:", 200, 40, kTextAlignment.center)
            drawCard(gameState.correctAnswer, 200, 100, 1)
        else
            gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
            gfx.drawTextAligned("Wrong!", 200, 10, kTextAlignment.center)
            gfx.setFont()

            -- Show user's wrong answer on the left at 1x scale
            gfx.drawTextAligned("You picked:", 100, 40, kTextAlignment.center)
            drawCard(gameState.userAnswer, 100, 100, 1)

            -- Show correct answer on the right at 1x scale
            gfx.drawTextAligned("Correct:", 300, 40, kTextAlignment.center)
            drawCard(gameState.correctAnswer, 300, 100, 1)
        end
    elseif gameState:getQuizMode() == GameState.MODES.QUIZ_CARD_TO_NUMBER then
        -- Card to Number mode feedback
        local questionCard = mnemonicaStack[gameState.currentPosition]

        -- Show the card being questioned
        drawCard(questionCard, 200, 50, 1)

        if gameState.userWasCorrect then
            gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
            gfx.drawTextAligned("Correct!", 200, 100, kTextAlignment.center)
            gfx.setFont()
            gfx.drawTextAligned("Position " .. gameState.correctAnswer, 200, 120, kTextAlignment.center)
        elseif gameState.userPassed then
            gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
            gfx.drawTextAligned("You passed!", 200, 100, kTextAlignment.center)
            gfx.setFont()
            gfx.drawTextAligned("Correct position: " .. gameState.correctAnswer, 200, 120, kTextAlignment.center)
        else
            gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
            gfx.drawTextAligned("Wrong!", 200, 100, kTextAlignment.center)
            gfx.setFont()
            gfx.drawTextAligned("You said: " .. gameState.userAnswer, 200, 120, kTextAlignment.center)
            gfx.drawTextAligned("Correct: Position " .. gameState.correctAnswer, 200, 140, kTextAlignment.center)
        end
    end

    -- Draw score
    local scoreText = "Score: " .. gameState.score .. "/" .. gameState.questionsAnswered
    gfx.drawTextAligned(scoreText, 200, 160, kTextAlignment.center)

    -- Draw continue instruction
    gfx.drawTextAligned("(A) Continue", 200, 200, kTextAlignment.center)
end

local function drawCompletionSummary()
    -- Check if this is a new high score
    local isNewBest = gameState:isNewHighScore()

    -- Title
    local titleY = 10
    if isNewBest then
        gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
        gfx.drawTextAligned("NEW HIGH SCORE!", 200, titleY, kTextAlignment.center)
        gfx.setFont()
    else
        gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
        gfx.drawTextAligned("Quiz Complete!", 200, titleY, kTextAlignment.center)
        gfx.setFont()
    end

    -- Score and time
    local finalScore = "Score: " .. gameState.score .. "/52"
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned(finalScore, 200, 35, kTextAlignment.center)
    gfx.setFont()

    local percentage = gameState:getScorePercentage()
    gfx.drawTextAligned(percentage .. "% correct", 200, 55, kTextAlignment.center)

    local finalTime = "Time: " .. gameState:getFormattedTime()
    gfx.drawTextAligned(finalTime, 200, 70, kTextAlignment.center)

    -- Show high score comparison
    local currentModeScores = gameState:getCurrentModeHighScores()
    if not isNewBest and currentModeScores.bestScore > 0 then
        gfx.drawTextAligned("-- Previous Best --", 200, 90, kTextAlignment.center)
        local bestScoreText = "Best: " .. currentModeScores.bestScore .. "/52"
        if currentModeScores.bestTime < math.huge then
            local bestMinutes = math.floor(currentModeScores.bestTime / 60)
            local bestSeconds = math.floor(currentModeScores.bestTime % 60)
            bestScoreText = bestScoreText .. string.format(" (%d:%02d)", bestMinutes, bestSeconds)
        end
        gfx.drawTextAligned(bestScoreText, 200, 105, kTextAlignment.center)
    end

    -- Mistakes summary (adjust Y position)
    local mistakesSectionY = isNewBest and 95 or (currentModeScores.bestScore > 0 and 120 or 95)
    local numMistakes = #gameState.mistakes
    if numMistakes > 0 then
        gfx.drawTextAligned("-- Mistakes: " .. numMistakes .. " --", 200, mistakesSectionY, kTextAlignment.center)

        -- Show first few mistakes as preview
        local previewCount = math.min(3, numMistakes)
        for i = 1, previewCount do
            local mistake = gameState.mistakes[i]
            local mistakeText = "Pos " .. mistake.position .. ": " .. mistake.correctAnswer
            if mistake.userAnswer == "PASSED" then
                mistakeText = mistakeText .. " (passed)"
            else
                mistakeText = mistakeText .. " (you: " .. mistake.userAnswer .. ")"
            end
            gfx.drawText(mistakeText, 40, mistakesSectionY + (i * 15))
        end

        if numMistakes > 3 then
            gfx.drawTextAligned("... and " .. (numMistakes - 3) .. " more", 200, mistakesSectionY + (4 * 15), kTextAlignment.center)
        end
    else
        gfx.drawTextAligned("-- Perfect Score! --", 200, mistakesSectionY, kTextAlignment.center)
    end

    -- Menu options (adjust Y position based on content above)
    local menuY = mistakesSectionY + (numMistakes > 0 and math.min(numMistakes, 3) * 15 + 25 or 25)
    local menuOptions = {
        "Play Again",
        numMistakes > 0 and "Review Mistakes" or nil,
        "Main Menu"
    }

    -- Filter out nil options and adjust selection
    local displayOptions = {}
    for _, option in ipairs(menuOptions) do
        if option then
            table.insert(displayOptions, option)
        end
    end

    -- Ensure selected option is valid
    if completionScreenState.selectedOption > #displayOptions then
        completionScreenState.selectedOption = 1
    end

    for i, option in ipairs(displayOptions) do
        local y = menuY + ((i - 1) * 20)
        UIHelpers.drawMenuItem(option, 200, y, 200, i == completionScreenState.selectedOption)
    end

    -- Instructions
    gfx.drawTextAligned("Up/Down: Select | A: Confirm", 200, 220, kTextAlignment.center)
end

local function drawMistakesList()
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Mistakes Review", 200, 10, kTextAlignment.center)
    gfx.setFont()

    local numMistakes = #gameState.mistakes
    gfx.drawTextAligned("Total: " .. numMistakes .. " mistakes", 200, 30, kTextAlignment.center)

    -- Draw mistakes list with scrolling support
    local startY = 50
    local lineHeight = 18
    local maxVisibleLines = 9  -- How many mistakes fit on screen

    for i = 1, math.min(numMistakes, maxVisibleLines) do
        local mistakeIndex = i + completionScreenState.mistakeScrollOffset
        if mistakeIndex <= numMistakes then
            local mistake = gameState.mistakes[mistakeIndex]
            local y = startY + ((i - 1) * lineHeight)

            -- Position and correct answer
            local posText = "Pos " .. mistake.position .. ":"
            gfx.drawText(posText, 20, y)

            -- Draw the correct card (if Number to Card mode)
            if gameState.currentMode == GameState.MODES.QUIZ_NUMBER_TO_CARD then
                gfx.drawText(mistake.correctAnswer, 80, y)
            else
                -- Card to Number mode
                local cardName = mnemonicaStack[mistake.position]
                gfx.drawText(cardName .. " -> " .. mistake.position, 80, y)
            end

            -- Show what user answered
            if mistake.userAnswer == "PASSED" then
                gfx.drawTextAligned("(passed)", 380, y, kTextAlignment.right)
            else
                gfx.drawTextAligned("(you: " .. mistake.userAnswer .. ")", 380, y, kTextAlignment.right)
            end
        end
    end

    -- Scroll indicators
    if completionScreenState.mistakeScrollOffset > 0 then
        gfx.drawTextAligned("^ more", 200, startY - 10, kTextAlignment.center)
    end
    if completionScreenState.mistakeScrollOffset + maxVisibleLines < numMistakes then
        gfx.drawTextAligned("v more", 200, startY + (maxVisibleLines * lineHeight), kTextAlignment.center)
    end

    -- Instructions
    gfx.drawTextAligned("B: Back | A: Start Review Quiz", 200, 220, kTextAlignment.center)
end

local function drawComplete()
    gfx.clear()

    if completionScreenState.showingMistakes then
        -- Draw mistakes list view
        drawMistakesList()
    else
        -- Draw main completion summary
        drawCompletionSummary()
    end
end

local function updateStudyModePosition()
    local crankPosition = pd.getCrankPosition()  -- 0-359 degrees

    -- Only process if crank position has changed significantly (reduces unnecessary calculations)
    if math.abs(crankPosition - lastCrankPosition) < 0.5 then
        return  -- No significant change, skip processing
    end

    local degreesPerPosition = 360 / 52  -- Each position gets approximately 6.92 degrees

    -- Calculate crank velocity for smooth feel
    local delta = crankPosition - lastCrankPosition
    -- Handle wrap-around at 0/360 boundary
    if delta > 180 then
        delta = delta - 360
    elseif delta < -180 then
        delta = delta + 360
    end
    crankVelocity = delta

    -- Apply crank sensitivity to effective degrees per position
    local effectiveDegreesPerPosition = degreesPerPosition / gameState.crankSensitivity

    -- Map crank position to a floating point position
    local floatPosition = (crankPosition / effectiveDegreesPerPosition) + 1

    -- Add subtle snap behavior when crank is moving slowly
    local snapThreshold = 0.35  -- How close to snap to the nearest position
    local velocityThreshold = 3  -- Degrees per frame to consider "slow"

    if math.abs(crankVelocity) < velocityThreshold then
        -- When moving slowly, snap to nearest position
        local nearestPosition = math.floor(floatPosition + 0.5)
        local distanceToNearest = math.abs(floatPosition - nearestPosition)

        if distanceToNearest < snapThreshold then
            floatPosition = nearestPosition
        end
    end

    -- Convert to integer position
    local newPosition = math.floor(floatPosition)

    -- Handle edge case at position 360 degrees (wraps to position 1)
    if newPosition > 52 then newPosition = 1 end
    if newPosition < 1 then newPosition = 1 end

    -- Check if position changed to play sound effect
    if newPosition ~= studyModePosition then
        studyModePosition = newPosition
        -- Play crank tick sound when position changes
        if gameState.soundEnabled then sounds.crankTick:play() end
    end

    lastCrankPosition = crankPosition
end

local function drawStudyMode()
    gfx.clear()

    -- Draw title
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Study Mode", 200, 10, kTextAlignment.center)
    gfx.setFont()

    -- Get the card at this position
    local cardAtPosition = mnemonicaStack[studyModePosition]

    -- Draw position number prominently
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Position " .. studyModePosition, 200, 50, kTextAlignment.center)
    gfx.setFont()

    -- Draw the card at 1x scale
    drawCard(cardAtPosition, 200, 110, 1)

    -- Draw card name below the image for clarity
    gfx.drawTextAligned(cardAtPosition, 200, 160, kTextAlignment.center)

    -- Draw crank indicator if docked
    if pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
    end

    gfx.drawTextAligned("Crank/D-pad: Browse | B: Menu", 200, 200, kTextAlignment.center)
end

local function drawMistakeReviewComplete()
    gfx.clear()

    -- Draw title
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Mistake Review Complete!", 200, 20, kTextAlignment.center)
    gfx.setFont()

    -- Get review summary
    local summary = gameState.mistakeReviewMode:getSummary()

    -- Show study phase summary
    gfx.drawTextAligned("-- Study Phase --", 200, 50, kTextAlignment.center)
    gfx.drawTextAligned("Mistakes studied: " .. summary.mistakesReviewed, 200, 70, kTextAlignment.center)
    local studyMinutes = math.floor(summary.studyTimeTotal / 60)
    local studySeconds = math.floor(summary.studyTimeTotal % 60)
    gfx.drawTextAligned(string.format("Study time: %d:%02d", studyMinutes, studySeconds), 200, 85, kTextAlignment.center)

    -- Show quiz phase results
    gfx.drawTextAligned("-- Quiz Results --", 200, 110, kTextAlignment.center)
    if summary.quizScore and summary.quizTotal then
        local scoreText = string.format("Score: %d/%d (%d%%)",
            summary.quizScore, summary.quizTotal, summary.quizAccuracy or 0)
        gfx.drawTextAligned(scoreText, 200, 130, kTextAlignment.center)

        -- Show improvement
        if summary.improvedMistakes and #summary.improvedMistakes > 0 then
            local improvementRate = math.floor((#summary.improvedMistakes / summary.mistakesReviewed) * 100)
            gfx.drawTextAligned("Improved: " .. #summary.improvedMistakes .. " cards (" .. improvementRate .. "%)",
                200, 150, kTextAlignment.center)
        end

        -- Show remaining mistakes
        local remainingMistakes = summary.mistakesReviewed - (summary.quizScore or 0)
        if remainingMistakes > 0 then
            gfx.drawTextAligned("Still need practice: " .. remainingMistakes .. " cards", 200, 170, kTextAlignment.center)
        else
            gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
            gfx.drawTextAligned("Perfect! All mistakes corrected!", 200, 170, kTextAlignment.center)
            gfx.setFont()
        end
    end

    -- Instructions
    gfx.drawTextAligned("Press A to return to quiz summary", 200, 210, kTextAlignment.center)
end

local function drawMistakeReviewStudy()
    gfx.clear()

    -- Get current mistake being studied
    local mistake = gameState.mistakeReviewMode:getCurrentStudyMistake()
    if not mistake then
        return
    end

    -- Draw title
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Mistake Review - Study Phase", 200, 10, kTextAlignment.center)
    gfx.setFont()

    -- Draw progress
    local progress = gameState.mistakeReviewMode:getProgress()
    gfx.drawTextAligned(progress.text, 200, 30, kTextAlignment.center)

    -- Draw the mistake information
    if gameState.mistakeReviewMode.originalMode == GameState.MODES.QUIZ_NUMBER_TO_CARD then
        -- Number to Card mode: Show position and correct card
        gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
        gfx.drawTextAligned("Position " .. mistake.position, 200, 60, kTextAlignment.center)
        gfx.setFont()

        -- Draw the correct card
        drawCard(mistake.correctAnswer, 200, 110, 1)

        -- Show what the user answered incorrectly
        if mistake.userAnswer == "PASSED" then
            gfx.drawTextAligned("You passed on this one", 200, 170, kTextAlignment.center)
        else
            gfx.drawTextAligned("You answered: " .. mistake.userAnswer, 200, 170, kTextAlignment.center)
        end
    else
        -- Card to Number mode: Show card and correct position
        local cardName = mnemonicaStack[mistake.position]

        -- Draw the card
        drawCard(cardName, 200, 60, 1)

        gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
        gfx.drawTextAligned("Position " .. mistake.position, 200, 130, kTextAlignment.center)
        gfx.setFont()

        -- Show what the user answered incorrectly
        if mistake.userAnswer == "PASSED" then
            gfx.drawTextAligned("You passed on this one", 200, 170, kTextAlignment.center)
        else
            gfx.drawTextAligned("You answered: Position " .. mistake.userAnswer, 200, 170, kTextAlignment.center)
        end
    end

    -- Draw instructions
    gfx.drawTextAligned("Study this card, then press A to continue", 200, 200, kTextAlignment.center)
    gfx.drawTextAligned("B: Previous | A: Next", 200, 220, kTextAlignment.center)
end

local function drawHighScores()
    gfx.clear()

    -- Draw title
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("High Scores", 200, 20, kTextAlignment.center)
    gfx.setFont()

    -- Number to Card Quiz section
    gfx.drawTextAligned("-- Number to Card Quiz --", 200, 60, kTextAlignment.center)
    local numberToCardScores = gameState.highScores.numberToCard
    if numberToCardScores.bestScore > 0 then
        local scoreText = "Best Score: " .. numberToCardScores.bestScore .. "/52"
        gfx.drawTextAligned(scoreText, 200, 80, kTextAlignment.center)

        if numberToCardScores.bestTime < math.huge then
            local minutes = math.floor(numberToCardScores.bestTime / 60)
            local seconds = math.floor(numberToCardScores.bestTime % 60)
            local timeText = string.format("Best Time: %d:%02d", minutes, seconds)
            gfx.drawTextAligned(timeText, 200, 100, kTextAlignment.center)
        end
    else
        gfx.drawTextAligned("No scores yet", 200, 80, kTextAlignment.center)
    end

    -- Card to Number Quiz section
    gfx.drawTextAligned("-- Card to Number Quiz --", 200, 130, kTextAlignment.center)
    local cardToNumberScores = gameState.highScores.cardToNumber
    if cardToNumberScores.bestScore > 0 then
        local scoreText = "Best Score: " .. cardToNumberScores.bestScore .. "/52"
        gfx.drawTextAligned(scoreText, 200, 150, kTextAlignment.center)

        if cardToNumberScores.bestTime < math.huge then
            local minutes = math.floor(cardToNumberScores.bestTime / 60)
            local seconds = math.floor(cardToNumberScores.bestTime % 60)
            local timeText = string.format("Best Time: %d:%02d", minutes, seconds)
            gfx.drawTextAligned(timeText, 200, 170, kTextAlignment.center)
        end
    else
        gfx.drawTextAligned("No scores yet", 200, 150, kTextAlignment.center)
    end

    -- Simon Mode section
    gfx.drawTextAligned("-- Simon Mode --", 200, 190, kTextAlignment.center)
    if gameState.simonMode.maxRound > 0 then
        gfx.drawTextAligned("Best: Round " .. gameState.simonMode.maxRound, 200, 205, kTextAlignment.center)
    else
        gfx.drawTextAligned("No scores yet", 200, 205, kTextAlignment.center)
    end

    -- Instructions
    gfx.drawTextAligned("Press (B) to return to menu", 200, 225, kTextAlignment.center)
end

local function drawSettings()
    gfx.clear()

    -- Draw title
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Settings", 200, 20, kTextAlignment.center)
    gfx.setFont()

    -- Settings options
    local settingsItems = {
        "Sound: " .. (gameState.soundEnabled and "On" or "Off"),
        "Crank Sensitivity: " .. string.format("%.1f", gameState.crankSensitivity),
        "Reset Statistics",
        "Reset High Scores",
        "Credits",
        "Back to Menu"
    }

    -- Draw settings items with selection indicator
    UIHelpers.drawMenuList(settingsItems, 200, 60, 300, settingsSelection, 25)

    -- Draw instructions
    gfx.drawTextAligned("Up/Down: Select | A: Confirm", 200, 205, kTextAlignment.center)
    gfx.drawTextAligned("Left/Right: Adjust values | B: Back", 200, 220, kTextAlignment.center)
end

local function drawCredits()
    gfx.clear()

    -- Draw title in heading font
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Credits", 200, 15, kTextAlignment.center)

    -- Use static MarbleMadness font for all content (smaller font)
    gfx.setFont(marbleMadnessFont)

    -- Credits content with consistent left alignment
    local leftX = 40
    local lineHeight = 10  -- Adjusted line height for MarbleMadness font
    local y = 45

    gfx.drawText("Mnemonica Stack Memorizer", leftX, y)
    y = y + lineHeight
    gfx.drawText("for Playdate", leftX, y)
    y = y + lineHeight * 1.5

    gfx.drawText("Created by:", leftX, y)
    y = y + lineHeight
    gfx.drawText("  Mr. Poopybutthole", leftX, y)
    y = y + lineHeight * 1.5

    gfx.drawText("Playing Card Assets:", leftX, y)
    y = y + lineHeight
    gfx.drawText("  Free playing cards from:", leftX, y)
    y = y + lineHeight
    gfx.drawText("  devforum.play.date/t/", leftX, y)
    y = y + lineHeight
    gfx.drawText("  playing-card-deck-imagetable-", leftX, y)
    y = y + lineHeight
    gfx.drawText("  free-for-your-card-game/994", leftX, y)
    y = y + lineHeight * 2

    gfx.drawText("Press B to return", leftX, y)
end

-- State for menu crank navigation with hysteresis
local menuCrankState = {
    lastAngle = 0,
    hysteresisThreshold = 15  -- degrees of hysteresis to prevent flickering
}

local function updateMenuSelectionWithCrank()
    local crankPosition = pd.getCrankPosition()  -- 0-359 degrees

    -- Initialize on first call
    if menuCrankState.lastAngle == 0 then
        menuCrankState.lastAngle = crankPosition
    end

    -- Only process if crank position has changed significantly
    if math.abs(crankPosition - lastCrankPosition) < 0.5 then
        return  -- No significant change, skip processing
    end

    -- Calculate crank velocity for smooth feel
    local delta = crankPosition - lastCrankPosition
    -- Handle wrap-around at 0/360 boundary
    if delta > 180 then
        delta = delta - 360
    elseif delta < -180 then
        delta = delta + 360
    end
    crankVelocity = delta

    -- Map crank position to menu items (6 items total)
    local numMenuItems = 6
    local degreesPerItem = 360 / numMenuItems  -- 60 degrees per item
    local effectiveDegreesPerItem = degreesPerItem / gameState.crankSensitivity

    -- Calculate which menu item we should be on based on angle
    -- Add 0.5 to center each item in its range
    local targetSelection = math.floor((crankPosition / effectiveDegreesPerItem) + 0.5) + 1

    -- Wrap around
    if targetSelection > numMenuItems then targetSelection = targetSelection - numMenuItems end
    if targetSelection < 1 then targetSelection = targetSelection + numMenuItems end

    -- Apply hysteresis to prevent flickering
    if targetSelection ~= menuSelection then
        -- Calculate the angle boundaries for current and target selections
        local currentCenter = ((menuSelection - 1) * effectiveDegreesPerItem) % 360
        local targetCenter = ((targetSelection - 1) * effectiveDegreesPerItem) % 360

        -- Calculate angular distance from crank to target center
        local distToTarget = math.abs(crankPosition - targetCenter)
        if distToTarget > 180 then distToTarget = 360 - distToTarget end

        -- Calculate angular distance from crank to current center
        local distToCurrent = math.abs(crankPosition - currentCenter)
        if distToCurrent > 180 then distToCurrent = 360 - distToCurrent end

        -- Only switch if we're significantly closer to the new target
        -- This creates a "sticky" zone around each selection
        if distToTarget < distToCurrent - menuCrankState.hysteresisThreshold then
            menuSelection = targetSelection
            if gameState.soundEnabled then sounds.menuMove:play() end
            menuCrankState.lastAngle = crankPosition
        end
    else
        menuCrankState.lastAngle = crankPosition
    end

    lastCrankPosition = crankPosition
end

local function drawMenu()
    gfx.clear()

    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Mnemonica Stack", 200, 10, kTextAlignment.center)
    gfx.drawTextAligned("Memorizer", 200, 25, kTextAlignment.center)

    -- Menu options
    local menuItems = {
        "Number to Card Quiz",
        "Card to Number Quiz",
        "Study Mode",
        "Simon Mode",
        "High Scores",
        "Settings"
    }

    gfx.setFont(gfx.getSystemFont())

    -- Draw menu items with selection indicator
    UIHelpers.drawMenuList(menuItems, 200, 55, 280, menuSelection, 25)

    -- Draw crank indicator if docked
    if pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
    end

    gfx.setFont()
    gfx.drawTextAligned("Crank or D-pad to select", 200, 195, kTextAlignment.center)
    gfx.drawTextAligned("(A) Start selected mode", 200, 210, kTextAlignment.center)
end

-- Menu callback for pause/resume
local menu = pd.getSystemMenu()

local function updateMenuItems()
    menu:removeAllMenuItems()

    -- Don't show pause/resume in menu mode, study mode, or settings mode
    if gameState.currentMode ~= GameState.MODES.MENU and
       gameState.currentMode ~= GameState.MODES.STUDY and
       gameState.currentMode ~= GameState.MODES.SETTINGS then
        if gameState.isPaused then
            menu:addMenuItem("Resume", function()
                if gameState.soundEnabled then sounds.buttonPress:play() end
                gameState:resume()
                updateMenuItems()
            end)
        else
            menu:addMenuItem("Pause", function()
                if gameState.soundEnabled then sounds.buttonPress:play() end
                gameState:pause()
                updateMenuItems()
            end)
        end

        menu:addMenuItem("Restart Quiz", function()
            if gameState.soundEnabled then sounds.buttonPress:play() end
            resetGame()
            updateMenuItems()
        end)

        menu:addMenuItem("Main Menu", function()
            if gameState.soundEnabled then sounds.buttonPress:play() end
            gameState.currentMode = GameState.MODES.MENU
            menuCrankState.lastAngle = pd.getCrankPosition()  -- Reset menu crank state
            updateMenuItems()
        end)
    end

    -- Add sound toggle menu item (available in all modes)
    local soundLabel = gameState.soundEnabled and "Sound: On" or "Sound: Off"
    menu:addMenuItem(soundLabel, function()
        -- Toggle sound setting
        gameState.soundEnabled = not gameState.soundEnabled
        -- Save the setting immediately so it persists
        gameState:saveSettings()
        -- Play a confirmation sound if we just enabled sound
        if gameState.soundEnabled then sounds.buttonPress:play() end
        -- Update menu to reflect new state
        updateMenuItems()
    end)

    -- Add reset statistics menu item (available in all modes)
    menu:addMenuItem("Reset Statistics", function()
        if gameState.soundEnabled then sounds.buttonPress:play() end
        gameState:resetCardStats()
        -- Update menu to ensure it stays consistent
        updateMenuItems()
    end)
end

-- Simon Mode Draw Functions
drawSimonShowing = function()
    gfx.clear()

    -- Title
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Simon Mode - Round " .. gameState.simonMode.currentRound, 200, 10, kTextAlignment.center)
    gfx.setFont()

    -- Check if we have a valid sequence index
    if gameState.simonMode.sequenceIndex <= #gameState.simonMode.sequence then
        -- Show current card in sequence
        local position = gameState.simonMode.sequence[gameState.simonMode.sequenceIndex]
        local card = mnemonicaStack[position]

        -- Draw position number prominently (like study mode)
        gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
        gfx.drawTextAligned("Position " .. position, 200, 50, kTextAlignment.center)
        gfx.setFont()

        -- Draw the card at 1x scale (like study mode)
        drawCard(card, 200, 110, 1)

        -- Draw card name below the image for clarity
        gfx.drawTextAligned(card, 200, 160, kTextAlignment.center)

        -- Progress indicator
        gfx.drawTextAligned("Card " .. gameState.simonMode.sequenceIndex .. " of " .. gameState.simonMode.currentRound,
                           200, 200, kTextAlignment.center)

        -- Instructions
        gfx.drawTextAligned("Press A to skip, B to exit", 200, 220, kTextAlignment.center)
    else
        -- Should not happen, but show a message if it does
        gfx.drawTextAligned("Preparing next phase...", 200, 120, kTextAlignment.center)
    end
end

drawSimonWaiting = function()
    gfx.clear()

    -- Title
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Simon Mode - Round " .. gameState.simonMode.currentRound, 200, 10, kTextAlignment.center)
    gfx.setFont()

    gfx.drawTextAligned("Get ready to repeat the sequence!", 200, 100, kTextAlignment.center)
    gfx.drawTextAligned("Press A to begin", 200, 130, kTextAlignment.center)
end

drawSimonInput = function()
    gfx.clear()

    -- Title
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Simon Mode - Round " .. gameState.simonMode.currentRound, 200, 10, kTextAlignment.center)
    gfx.setFont()

    -- Show which card/position in sequence we're asking for
    gfx.drawTextAligned("Enter card " .. gameState.simonMode.playerIndex .. " of " .. gameState.simonMode.currentRound,
                       200, 35, kTextAlignment.center)

    local currentPosition = gameState.simonMode.sequence[gameState.simonMode.playerIndex]

    if gameState.simonMode.selectedInput == "card" then
        -- Player is selecting the card
        gfx.drawTextAligned("What card is at position " .. currentPosition .. "?", 200, 55, kTextAlignment.center)

        -- Use the dial renderer to show card selection with correct parameters
        dialRenderer:drawFrame()  -- Draw dial background/frame
        dialRenderer:draw(uspccOrder, selectedCard, getCardImage, drawCard)

        gfx.drawTextAligned("Crank to select card | A: Confirm", 200, 210, kTextAlignment.center)
        gfx.drawTextAligned("B: Cancel", 200, 225, kTextAlignment.center)
    else
        -- Player is selecting the position number
        local cardName = mnemonicaStack[currentPosition]
        gfx.drawTextAligned("What position is " .. cardName .. "?", 200, 55, kTextAlignment.center)

        -- Use the number dial renderer
        numberDialRenderer:drawFrame()  -- Draw dial background/frame
        numberDialRenderer:draw(selectedNumber)

        gfx.drawTextAligned("Crank to select position | A: Confirm", 200, 210, kTextAlignment.center)
        gfx.drawTextAligned("B: Cancel", 200, 225, kTextAlignment.center)
    end
end

drawSimonFeedback = function()
    gfx.clear()

    -- Title
    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Simon Mode", 200, 10, kTextAlignment.center)
    gfx.setFont()

    if gameState.simonMode.isCorrect then
        gfx.drawTextAligned("Correct!", 200, 60, kTextAlignment.center)

        if gameState.simonMode.playerIndex >= gameState.simonMode.currentRound then
            -- Completed the round
            gfx.drawTextAligned("Round " .. gameState.simonMode.currentRound .. " Complete!", 200, 90, kTextAlignment.center)
            gfx.drawTextAligned("Press A to continue to Round " .. (gameState.simonMode.currentRound + 1), 200, 120, kTextAlignment.center)
        else
            -- More cards to go in this round
            gfx.drawTextAligned("Press A to continue", 200, 90, kTextAlignment.center)
        end
    else
        -- Incorrect - game over
        gfx.drawTextAligned("Incorrect!", 200, 60, kTextAlignment.center)
        gfx.drawTextAligned("Game Over", 200, 90, kTextAlignment.center)

        -- Show the correct answer
        local position = gameState.simonMode.sequence[gameState.simonMode.playerIndex]
        local card = mnemonicaStack[position]
        gfx.drawTextAligned("Position " .. position .. " is " .. card, 200, 120, kTextAlignment.center)

        -- Show score
        local completedRounds = gameState.simonMode.currentRound - 1
        local partialCards = gameState.simonMode.playerIndex - 1
        gfx.drawTextAligned("Completed: " .. completedRounds .. " rounds + " .. partialCards .. " cards", 200, 150, kTextAlignment.center)

        -- Update max round if needed
        if gameState.simonMode.currentRound > gameState.simonMode.maxRound then
            gameState.simonMode.maxRound = gameState.simonMode.currentRound
            gameState:saveSettings()  -- Save the new best
            gfx.drawTextAligned("New best: Round " .. gameState.simonMode.maxRound .. "!", 200, 170, kTextAlignment.center)
        else
            gfx.drawTextAligned("Best: Round " .. gameState.simonMode.maxRound, 200, 170, kTextAlignment.center)
        end

        gfx.drawTextAligned("Press A to play again | B: Main Menu", 200, 200, kTextAlignment.center)
    end
end

checkSimonAnswer = function()
    local position = gameState.simonMode.sequence[gameState.simonMode.playerIndex]

    if gameState.simonMode.selectedInput == "card" then
        -- Check if selected card matches
        local correctCard = mnemonicaStack[position]
        local selectedCardName = uspccOrder[selectedCard]
        gameState.simonMode.isCorrect = (selectedCardName == correctCard)
    else
        -- Check if selected position matches
        gameState.simonMode.isCorrect = (selectedNumber == position)
    end

    if gameState.simonMode.isCorrect then
        if gameState.soundEnabled then sounds.correct:play() end

        if gameState.simonMode.playerIndex < gameState.simonMode.currentRound then
            -- Move to next card in sequence
            gameState.simonMode.playerIndex = gameState.simonMode.playerIndex + 1
            -- Randomly choose whether to ask for card or position
            gameState.simonMode.selectedInput = math.random() < 0.5 and "card" or "number"
        end
    else
        if gameState.soundEnabled then sounds.incorrect:play() end
    end

    gameState.simonMode.phase = "FEEDBACK"
end

updateSimonMode = function()
    if gameState.simonMode.phase == "SHOWING" then
        -- Auto-advance through sequence display
        gameState.simonMode.displayTimer = gameState.simonMode.displayTimer + 1

        if gameState.simonMode.displayTimer > 90 then  -- Show each card for 1.5 seconds at 60fps
            gameState.simonMode.displayTimer = 0
            gameState.simonMode.sequenceIndex = gameState.simonMode.sequenceIndex + 1

            if gameState.simonMode.sequenceIndex > gameState.simonMode.currentRound then
                -- Done showing sequence
                gameState.simonMode.phase = "WAITING"
            end
        end

        drawSimonShowing()

        -- Allow skip with A button
        if pd.buttonJustPressed(pd.kButtonA) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            gameState.simonMode.sequenceIndex = gameState.simonMode.sequenceIndex + 1
            gameState.simonMode.displayTimer = 0

            if gameState.simonMode.sequenceIndex > gameState.simonMode.currentRound then
                gameState.simonMode.phase = "WAITING"
            end
        elseif pd.buttonJustPressed(pd.kButtonB) then
            -- Back to menu
            if gameState.soundEnabled then sounds.buttonPress:play() end
            gameState.currentMode = GameState.MODES.MENU
            menuCrankState.lastAngle = pd.getCrankPosition()
        end

    elseif gameState.simonMode.phase == "WAITING" then
        drawSimonWaiting()

        if pd.buttonJustPressed(pd.kButtonA) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            gameState.simonMode.phase = "INPUT"
            gameState.simonMode.playerIndex = 1
            -- Randomly choose whether to ask for card or position for first one
            gameState.simonMode.selectedInput = math.random() < 0.5 and "card" or "number"
        elseif pd.buttonJustPressed(pd.kButtonB) then
            -- Back to menu
            if gameState.soundEnabled then sounds.buttonPress:play() end
            gameState.currentMode = GameState.MODES.MENU
            menuCrankState.lastAngle = pd.getCrankPosition()
        end

    elseif gameState.simonMode.phase == "INPUT" then
        -- Update selection based on input type
        if gameState.simonMode.selectedInput == "card" then
            updateSelectedCard()

            -- D-pad navigation for card selection
            if pd.buttonJustPressed(pd.kButtonUp) then
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedCard = selectedCard - 1
                if selectedCard < 1 then selectedCard = 52 end
            elseif pd.buttonJustPressed(pd.kButtonDown) then
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedCard = selectedCard + 1
                if selectedCard > 52 then selectedCard = 1 end
            elseif pd.buttonJustPressed(pd.kButtonLeft) then
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedCard = selectedCard - 13
                if selectedCard < 1 then selectedCard = selectedCard + 52 end
            elseif pd.buttonJustPressed(pd.kButtonRight) then
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedCard = selectedCard + 13
                if selectedCard > 52 then selectedCard = selectedCard - 52 end
            end
        else
            updateSelectedNumber()

            -- D-pad navigation for number selection
            if pd.buttonJustPressed(pd.kButtonUp) then
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedNumber = selectedNumber - 1
                if selectedNumber < 1 then selectedNumber = 52 end
            elseif pd.buttonJustPressed(pd.kButtonDown) then
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedNumber = selectedNumber + 1
                if selectedNumber > 52 then selectedNumber = 1 end
            elseif pd.buttonJustPressed(pd.kButtonLeft) then
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedNumber = selectedNumber - 10
                if selectedNumber < 1 then selectedNumber = selectedNumber + 52 end
            elseif pd.buttonJustPressed(pd.kButtonRight) then
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedNumber = selectedNumber + 10
                if selectedNumber > 52 then selectedNumber = selectedNumber - 52 end
            end
        end

        drawSimonInput()

        if pd.buttonJustPressed(pd.kButtonA) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            checkSimonAnswer()
        elseif pd.buttonJustPressed(pd.kButtonB) then
            -- Back to menu
            if gameState.soundEnabled then sounds.buttonPress:play() end
            gameState.currentMode = GameState.MODES.MENU
            menuCrankState.lastAngle = pd.getCrankPosition()
        end

    elseif gameState.simonMode.phase == "FEEDBACK" then
        drawSimonFeedback()

        if pd.buttonJustPressed(pd.kButtonA) then
            if gameState.soundEnabled then sounds.buttonPress:play() end

            if gameState.simonMode.isCorrect then
                if gameState.simonMode.playerIndex >= gameState.simonMode.currentRound then
                    -- Start next round
                    startSimonRound()
                else
                    -- Continue current round
                    gameState.simonMode.phase = "INPUT"
                end
            else
                -- Restart game
                gameState.simonMode.sequence = {}
                gameState.simonMode.playerIndex = 1
                gameState.simonMode.currentRound = 0
                gameState.simonMode.phase = "SHOWING"
                gameState.simonMode.sequenceIndex = 1
                gameState.simonMode.displayTimer = 0
                gameState.simonMode.isCorrect = true
                startSimonRound()
            end
        elseif pd.buttonJustPressed(pd.kButtonB) then
            -- Back to menu
            if gameState.soundEnabled then sounds.buttonPress:play() end
            gameState.currentMode = GameState.MODES.MENU
            menuCrankState.lastAngle = pd.getCrankPosition()
        end
    end
end

function playdate.update()
    -- Handle pause state
    if gameState.isPaused then
        gfx.clear()
        gfx.drawTextAligned("PAUSED", 200, 100, kTextAlignment.center)
        gfx.drawTextAligned("Press Menu to resume", 200, 130, kTextAlignment.center)
        return
    end

    if gameState.currentMode == GameState.MODES.MISTAKE_REVIEW then
        -- Handle mistake review mode
        if gameState.mistakeReviewMode then
            if gameState.mistakeReviewMode.currentPhase == MistakeReviewMode.PHASES.STUDY then
                -- Study phase - show mistake cards for review
                drawMistakeReviewStudy()

                if pd.buttonJustPressed(pd.kButtonA) then
                    if gameState.soundEnabled then sounds.buttonPress:play() end

                    gameState:advanceMistakeStudy()

                    if gameState.mistakeReviewMode.currentPhase == MistakeReviewMode.PHASES.QUIZ then
                        if gameState.mistakeReviewMode.originalMode == GameState.MODES.QUIZ_NUMBER_TO_CARD then
                            gameState.correctAnswer = mnemonicaStack[gameState.currentPosition]
                            selectedCard = 1
                        else
                            gameState.correctAnswer = tostring(gameState.currentPosition)
                            selectedNumber = 1
                        end
                    end
                elseif pd.buttonJustPressed(pd.kButtonB) then
                    if gameState.soundEnabled then sounds.buttonPress:play() end
                    gameState.mistakeReviewMode:previousStudyCard()
                end
            elseif gameState.mistakeReviewMode.currentPhase == MistakeReviewMode.PHASES.QUIZ then
                -- Quiz phase - handle like normal quiz but check for completion
                if gameState.quizState == GameState.QUIZ_STATES.QUESTION then
                    -- Update the appropriate selection based on original quiz mode
                    if gameState.mistakeReviewMode.originalMode == GameState.MODES.QUIZ_NUMBER_TO_CARD then
                        updateSelectedCard()
                        drawQuizNumberToCard()

                        -- D-pad navigation for card selection in mistake review
                        if pd.buttonJustPressed(pd.kButtonUp) then
                            if gameState.soundEnabled then sounds.crankTick:play() end
                            selectedCard = selectedCard - 1
                            if selectedCard < 1 then selectedCard = 52 end
                        elseif pd.buttonJustPressed(pd.kButtonDown) then
                            if gameState.soundEnabled then sounds.crankTick:play() end
                            selectedCard = selectedCard + 1
                            if selectedCard > 52 then selectedCard = 1 end
                        elseif pd.buttonJustPressed(pd.kButtonLeft) then
                            -- Jump back 13 cards (quarter deck)
                            if gameState.soundEnabled then sounds.crankTick:play() end
                            selectedCard = selectedCard - 13
                            if selectedCard < 1 then selectedCard = selectedCard + 52 end
                        elseif pd.buttonJustPressed(pd.kButtonRight) then
                            -- Jump forward 13 cards (quarter deck)
                            if gameState.soundEnabled then sounds.crankTick:play() end
                            selectedCard = selectedCard + 13
                            if selectedCard > 52 then selectedCard = selectedCard - 52 end
                        end
                    else
                        updateSelectedNumber()
                        drawQuizCardToNumber()

                        -- D-pad navigation for number selection in mistake review
                        if pd.buttonJustPressed(pd.kButtonUp) then
                            if gameState.soundEnabled then sounds.crankTick:play() end
                            selectedNumber = selectedNumber - 1
                            if selectedNumber < 1 then selectedNumber = 52 end
                        elseif pd.buttonJustPressed(pd.kButtonDown) then
                            if gameState.soundEnabled then sounds.crankTick:play() end
                            selectedNumber = selectedNumber + 1
                            if selectedNumber > 52 then selectedNumber = 1 end
                        elseif pd.buttonJustPressed(pd.kButtonLeft) then
                            -- Jump back 10 positions
                            if gameState.soundEnabled then sounds.crankTick:play() end
                            selectedNumber = selectedNumber - 10
                            if selectedNumber < 1 then selectedNumber = selectedNumber + 52 end
                        elseif pd.buttonJustPressed(pd.kButtonRight) then
                            -- Jump forward 10 positions
                            if gameState.soundEnabled then sounds.crankTick:play() end
                            selectedNumber = selectedNumber + 10
                            if selectedNumber > 52 then selectedNumber = selectedNumber - 52 end
                        end
                    end

                    if pd.buttonJustPressed(pd.kButtonA) then
                        if gameState.soundEnabled then sounds.buttonPress:play() end
                        checkAnswer()
                    elseif pd.buttonJustPressed(pd.kButtonB) then
                        if gameState.soundEnabled then sounds.buttonPress:play() end
                        -- Return to menu
                        gameState.currentMode = GameState.MODES.MENU
                        menuCrankState.lastAngle = pd.getCrankPosition()  -- Reset menu crank state
                        updateMenuItems()
                        -- Clear the mistake review mode
                        gameState.mistakeReviewMode = nil
                        gameState.originalSession = nil
                    end
                elseif gameState.quizState == GameState.QUIZ_STATES.FEEDBACK then
                    drawFeedback()

                    if pd.buttonJustPressed(pd.kButtonA) then
                        if gameState.soundEnabled then sounds.buttonPress:play() end
                        nextQuestion()
                    end
                elseif gameState.quizState == GameState.QUIZ_STATES.COMPLETE then
                    -- Show review completion screen
                    drawMistakeReviewComplete()

                    if pd.buttonJustPressed(pd.kButtonA) then
                        if gameState.soundEnabled then sounds.buttonPress:play() end
                        -- Return to original quiz summary
                        if gameState.originalSession then
                            -- Restore the original session
                            gameState.currentSession = gameState.originalSession
                            gameState.originalSession = nil
                            gameState.mistakeReviewMode = nil
                            gameState.quizState = GameState.QUIZ_STATES.COMPLETE
                            -- Set mode to show the completion screen
                            if gameState.currentSession.mode == GameState.MODES.QUIZ_NUMBER_TO_CARD then
                                gameState.currentMode = GameState.MODES.QUIZ_NUMBER_TO_CARD
                            else
                                gameState.currentMode = GameState.MODES.QUIZ_CARD_TO_NUMBER
                            end
                            -- Reset completion screen state
                            completionScreenState.showingMistakes = false
                            completionScreenState.mistakeScrollOffset = 0
                            completionScreenState.selectedOption = 1
                        else
                            -- Fallback to menu if no original session
                            gameState.currentMode = GameState.MODES.MENU
                            menuCrankState.lastAngle = pd.getCrankPosition()  -- Reset menu crank state
                            gameState.mistakeReviewMode = nil
                        end
                    end
                end
            end
        end
    elseif gameState.currentMode == GameState.MODES.MENU then
        -- Update menu selection with crank
        updateMenuSelectionWithCrank()

        drawMenu()

        -- Handle menu navigation
        if pd.buttonJustPressed(pd.kButtonUp) then
            if gameState.soundEnabled then sounds.menuMove:play() end
            menuSelection = menuSelection - 1
            if menuSelection < 1 then menuSelection = 6 end
        elseif pd.buttonJustPressed(pd.kButtonDown) then
            if gameState.soundEnabled then sounds.menuMove:play() end
            menuSelection = menuSelection + 1
            if menuSelection > 6 then menuSelection = 1 end
        elseif pd.buttonJustPressed(pd.kButtonA) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            startSelectedMode()
        end

    elseif gameState.currentMode == GameState.MODES.SIMON then
        -- Simon mode
        updateSimonMode()

    elseif gameState.currentMode == GameState.MODES.STUDY then
        -- Study mode - update position based on crank
        updateStudyModePosition()
        drawStudyMode()

        -- Handle D-pad for quick jumps
        if pd.buttonJustPressed(pd.kButtonUp) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            studyModePosition = studyModePosition - 10
            if studyModePosition < 1 then studyModePosition = studyModePosition + 52 end
        elseif pd.buttonJustPressed(pd.kButtonDown) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            studyModePosition = studyModePosition + 10
            if studyModePosition > 52 then studyModePosition = studyModePosition - 52 end
        elseif pd.buttonJustPressed(pd.kButtonLeft) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            studyModePosition = studyModePosition - 1
            if studyModePosition < 1 then studyModePosition = 52 end
        elseif pd.buttonJustPressed(pd.kButtonRight) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            studyModePosition = studyModePosition + 1
            if studyModePosition > 52 then studyModePosition = 1 end
        end

        -- Handle B button to return to menu
        if pd.buttonJustPressed(pd.kButtonB) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            gameState.currentMode = GameState.MODES.MENU
            menuCrankState.lastAngle = pd.getCrankPosition()  -- Reset menu crank state
        end

    elseif gameState.currentMode == GameState.MODES.HIGH_SCORES then
        -- High scores screen
        drawHighScores()

        if pd.buttonJustPressed(pd.kButtonB) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            gameState.currentMode = GameState.MODES.MENU
            menuCrankState.lastAngle = pd.getCrankPosition()  -- Reset menu crank state
        end

    elseif gameState.currentMode == GameState.MODES.SETTINGS then
        -- Settings mode
        if showingCredits then
            -- Credits screen
            drawCredits()

            if pd.buttonJustPressed(pd.kButtonB) then
                if gameState.soundEnabled then sounds.buttonPress:play() end
                showingCredits = false  -- Return to settings menu
            end
        else
            -- Main settings screen
            drawSettings()

            -- Handle settings navigation
            if pd.buttonJustPressed(pd.kButtonUp) then
                if gameState.soundEnabled then sounds.menuMove:play() end
                settingsSelection = settingsSelection - 1
                if settingsSelection < 1 then settingsSelection = 6 end
            elseif pd.buttonJustPressed(pd.kButtonDown) then
                if gameState.soundEnabled then sounds.menuMove:play() end
                settingsSelection = settingsSelection + 1
                if settingsSelection > 6 then settingsSelection = 1 end
            elseif pd.buttonJustPressed(pd.kButtonLeft) then
                -- Adjust values left
                if settingsSelection == 2 then
                    -- Crank sensitivity
                    gameState.crankSensitivity = math.max(0.1, gameState.crankSensitivity - 0.1)
                    gameState:saveSettings()
                    if gameState.soundEnabled then sounds.buttonPress:play() end
                end
            elseif pd.buttonJustPressed(pd.kButtonRight) then
                -- Adjust values right
                if settingsSelection == 2 then
                    -- Crank sensitivity
                    gameState.crankSensitivity = math.min(3.0, gameState.crankSensitivity + 0.1)
                    gameState:saveSettings()
                    if gameState.soundEnabled then sounds.buttonPress:play() end
                end
            elseif pd.buttonJustPressed(pd.kButtonA) then
                if gameState.soundEnabled then sounds.buttonPress:play() end

                if settingsSelection == 1 then
                    -- Toggle sound
                    gameState.soundEnabled = not gameState.soundEnabled
                    gameState:saveSettings()
                elseif settingsSelection == 3 then
                    -- Reset statistics
                    gameState:resetCardStats()
                elseif settingsSelection == 4 then
                    -- Reset high scores
                    gameState:resetHighScores()
                elseif settingsSelection == 5 then
                    -- Show credits
                    showingCredits = true
                elseif settingsSelection == 6 then
                    -- Back to menu
                    gameState.currentMode = GameState.MODES.MENU
                    menuCrankState.lastAngle = pd.getCrankPosition()  -- Reset menu crank state
                end
            elseif pd.buttonJustPressed(pd.kButtonB) then
                if gameState.soundEnabled then sounds.buttonPress:play() end
                gameState.currentMode = GameState.MODES.MENU
                menuCrankState.lastAngle = pd.getCrankPosition()  -- Reset menu crank state
            end
        end

    elseif gameState.quizState == GameState.QUIZ_STATES.QUESTION then
        -- Update the appropriate selection based on quiz mode
        if gameState.currentMode == GameState.MODES.QUIZ_NUMBER_TO_CARD then
            updateSelectedCard()
        elseif gameState.currentMode == GameState.MODES.QUIZ_CARD_TO_NUMBER then
            updateSelectedNumber()
        end

        drawQuiz()

        -- Handle D-pad navigation for quiz modes
        if gameState.currentMode == GameState.MODES.QUIZ_NUMBER_TO_CARD then
            -- D-pad navigation for card selection (Number to Card Quiz)
            if pd.buttonJustPressed(pd.kButtonUp) then
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedCard = selectedCard - 1
                if selectedCard < 1 then selectedCard = 52 end
            elseif pd.buttonJustPressed(pd.kButtonDown) then
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedCard = selectedCard + 1
                if selectedCard > 52 then selectedCard = 1 end
            elseif pd.buttonJustPressed(pd.kButtonLeft) then
                -- Jump back 13 cards (quarter deck)
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedCard = selectedCard - 13
                if selectedCard < 1 then selectedCard = selectedCard + 52 end
            elseif pd.buttonJustPressed(pd.kButtonRight) then
                -- Jump forward 13 cards (quarter deck)
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedCard = selectedCard + 13
                if selectedCard > 52 then selectedCard = selectedCard - 52 end
            end
        elseif gameState.currentMode == GameState.MODES.QUIZ_CARD_TO_NUMBER then
            -- D-pad navigation for number selection (Card to Number Quiz)
            if pd.buttonJustPressed(pd.kButtonUp) then
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedNumber = selectedNumber - 1
                if selectedNumber < 1 then selectedNumber = 52 end
            elseif pd.buttonJustPressed(pd.kButtonDown) then
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedNumber = selectedNumber + 1
                if selectedNumber > 52 then selectedNumber = 1 end
            elseif pd.buttonJustPressed(pd.kButtonLeft) then
                -- Jump back 10 positions
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedNumber = selectedNumber - 10
                if selectedNumber < 1 then selectedNumber = selectedNumber + 52 end
            elseif pd.buttonJustPressed(pd.kButtonRight) then
                -- Jump forward 10 positions
                if gameState.soundEnabled then sounds.crankTick:play() end
                selectedNumber = selectedNumber + 10
                if selectedNumber > 52 then selectedNumber = selectedNumber - 52 end
            end
        end

        if pd.buttonJustPressed(pd.kButtonA) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            checkAnswer()
        elseif pd.buttonJustPressed(pd.kButtonB) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            -- Return to menu
            gameState.currentMode = GameState.MODES.MENU
            menuCrankState.lastAngle = pd.getCrankPosition()  -- Reset menu crank state
            updateMenuItems()
        end

    elseif gameState.quizState == GameState.QUIZ_STATES.FEEDBACK then
        drawFeedback()

        if pd.buttonJustPressed(pd.kButtonA) then
            if gameState.soundEnabled then sounds.buttonPress:play() end
            nextQuestion()
        end

    elseif gameState.quizState == GameState.QUIZ_STATES.COMPLETE then
        drawComplete()

        if completionScreenState.showingMistakes then
            -- Mistakes list view controls
            if pd.buttonJustPressed(pd.kButtonUp) then
                if gameState.soundEnabled then sounds.buttonPress:play() end
                completionScreenState.mistakeScrollOffset = math.max(0, completionScreenState.mistakeScrollOffset - 1)
            elseif pd.buttonJustPressed(pd.kButtonDown) then
                if gameState.soundEnabled then sounds.buttonPress:play() end
                local maxOffset = math.max(0, #gameState.mistakes - 9)  -- 9 visible lines
                completionScreenState.mistakeScrollOffset = math.min(maxOffset, completionScreenState.mistakeScrollOffset + 1)
            elseif pd.buttonJustPressed(pd.kButtonA) then
                if gameState.soundEnabled then sounds.buttonPress:play() end
                -- Start review quiz with mistakes
                startMistakeReview()
            elseif pd.buttonJustPressed(pd.kButtonB) then
                if gameState.soundEnabled then sounds.buttonPress:play() end
                -- Go back to summary
                completionScreenState.showingMistakes = false
                completionScreenState.mistakeScrollOffset = 0
            end
        else
            -- Main completion screen controls
            local numOptions = #gameState.mistakes > 0 and 3 or 2  -- 3 options if mistakes, 2 if perfect

            if pd.buttonJustPressed(pd.kButtonUp) then
                if gameState.soundEnabled then sounds.menuMove:play() end
                completionScreenState.selectedOption = completionScreenState.selectedOption - 1
                if completionScreenState.selectedOption < 1 then
                    completionScreenState.selectedOption = numOptions
                end
            elseif pd.buttonJustPressed(pd.kButtonDown) then
                if gameState.soundEnabled then sounds.menuMove:play() end
                completionScreenState.selectedOption = completionScreenState.selectedOption + 1
                if completionScreenState.selectedOption > numOptions then
                    completionScreenState.selectedOption = 1
                end
            elseif pd.buttonJustPressed(pd.kButtonA) then
                if gameState.soundEnabled then sounds.buttonPress:play() end

                if #gameState.mistakes > 0 then
                    -- With mistakes: 1=Play Again, 2=Review, 3=Menu
                    if completionScreenState.selectedOption == 1 then
                        resetGame()
                        completionScreenState.selectedOption = 1  -- Reset for next time
                    elseif completionScreenState.selectedOption == 2 then
                        -- Show mistakes list
                        completionScreenState.showingMistakes = true
                        completionScreenState.mistakeScrollOffset = 0
                    else
                        gameState.currentMode = GameState.MODES.MENU
                        menuCrankState.lastAngle = pd.getCrankPosition()  -- Reset menu crank state
                        completionScreenState.selectedOption = 1  -- Reset for next time
                    end
                else
                    -- No mistakes: 1=Play Again, 2=Menu
                    if completionScreenState.selectedOption == 1 then
                        resetGame()
                        completionScreenState.selectedOption = 1  -- Reset for next time
                    else
                        gameState.currentMode = GameState.MODES.MENU
                        menuCrankState.lastAngle = pd.getCrankPosition()  -- Reset menu crank state
                        completionScreenState.selectedOption = 1  -- Reset for next time
                    end
                end
            end
        end
    end
end

-- Initialize game
math.randomseed(pd.getSecondsSinceEpoch())  -- Seed random number generator

-- Set target frame rate for consistent performance (30 FPS is optimal for Playdate)
pd.display.setRefreshRate(30)

gameState:loadHighScores()  -- Load saved high scores from persistent storage
gameState:loadSettings()  -- Load settings including last selected menu mode
menuSelection = gameState.lastSelectedMenuMode  -- Restore last selected menu item
gameState.currentMode = GameState.MODES.MENU  -- Start at main menu
lastCrankPosition = pd.getCrankPosition()  -- Initialize crank position
menuCrankState.lastAngle = pd.getCrankPosition()  -- Initialize menu crank state
updateMenuItems()  -- Set up menu
