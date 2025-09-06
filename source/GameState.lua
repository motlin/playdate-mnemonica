-- GameState manager for Mnemonica Quiz
-- Handles all game state tracking including mode, score, timer, progress, etc.

local pd <const> = playdate

local GameState = {}
GameState.__index = GameState

-- Game modes
GameState.MODES = {
    QUIZ_NUMBER_TO_CARD = "quiz_number_to_card",
    QUIZ_CARD_TO_NUMBER = "quiz_card_to_number",
    STUDY = "study",
    MENU = "menu"
}

-- Quiz states
GameState.QUIZ_STATES = {
    QUESTION = "question",
    FEEDBACK = "feedback",
    COMPLETE = "complete"
}

function GameState:new()
    local state = setmetatable({}, self)

    -- Current game mode
    state.currentMode = GameState.MODES.QUIZ_NUMBER_TO_CARD

    -- Quiz state
    state.quizState = GameState.QUIZ_STATES.QUESTION

    -- Score tracking
    state.score = 0
    state.totalQuestions = 52

    -- Timer tracking (in seconds)
    state.startTime = 0
    state.elapsedTime = 0
    state.isPaused = false

    -- Question tracking
    state.questionOrder = {}  -- Shuffled array of positions 1-52
    state.questionIndex = 1   -- Current index in questionOrder
    state.currentPosition = 1 -- Current position being asked

    -- Answer tracking
    state.selectedAnswer = 1  -- Currently selected answer (card index or position)
    state.correctAnswer = ""  -- Correct answer for current question
    state.userAnswer = ""     -- What the user selected
    state.userWasCorrect = false
    state.userPassed = false

    -- Mistake tracking for review
    state.mistakes = {}  -- Array of {position, correctCard, userCard}

    -- Session statistics
    state.questionsAnswered = 0
    state.questionsCorrect = 0
    state.questionsIncorrect = 0
    state.questionsPassed = 0

    -- High scores
    state.highScores = {
        numberToCard = { bestScore = 0, bestTime = math.huge },
        cardToNumber = { bestScore = 0, bestTime = math.huge }
    }

    -- Settings
    state.soundEnabled = true
    state.crankSensitivity = 1.0

    -- Card statistics for spaced repetition
    -- Each entry tracks performance for a specific card/position pair
    state.cardStats = {}
    for i = 1, 52 do
        state.cardStats[i] = {
            timesAsked = 0,
            timesCorrect = 0,
            timesIncorrect = 0,
            lastAsked = 0,  -- Timestamp of last time this was asked
            streak = 0,     -- Current correct answer streak
            difficulty = 1.0  -- Difficulty weight for spaced repetition (higher = harder)
        }
    end

    -- Load any saved card statistics
    state:loadCardStats()

    return state
end

-- Start a new quiz session
function GameState:startQuiz(mode)
    self.currentMode = mode or GameState.MODES.QUIZ_NUMBER_TO_CARD
    self.quizState = GameState.QUIZ_STATES.QUESTION

    -- Reset scores and statistics
    self.score = 0
    self.questionsAnswered = 0
    self.questionsCorrect = 0
    self.questionsIncorrect = 0
    self.questionsPassed = 0

    -- Reset timer
    self.startTime = pd.getCurrentTimeMilliseconds() / 1000
    self.elapsedTime = 0
    self.isPaused = false

    -- Initialize shuffled question order
    self:initializeQuestionOrder()

    -- Clear mistakes
    self.mistakes = {}

    -- Reset answer tracking
    self.selectedAnswer = 1
    self.correctAnswer = ""
    self.userAnswer = ""
    self.userWasCorrect = false
    self.userPassed = false
end

-- Initialize shuffled question order using Fisher-Yates algorithm
function GameState:initializeQuestionOrder(useSpacedRepetition)
    self.questionOrder = {}

    if useSpacedRepetition and self:hasEnoughDataForSpacedRepetition() then
        -- Use weighted random selection based on difficulty
        self:initializeSpacedRepetitionOrder()
    else
        -- Standard Fisher-Yates shuffle
        for i = 1, self.totalQuestions do
            self.questionOrder[i] = i
        end

        for i = #self.questionOrder, 2, -1 do
            local j = math.random(1, i)
            self.questionOrder[i], self.questionOrder[j] = self.questionOrder[j], self.questionOrder[i]
        end
    end

    self.questionIndex = 1
    self.currentPosition = self.questionOrder[1]
end

-- Check if we have enough data to use spaced repetition
function GameState:hasEnoughDataForSpacedRepetition()
    local totalAsked = 0
    for i = 1, 52 do
        totalAsked = totalAsked + self.cardStats[i].timesAsked
    end
    -- Need at least 52 questions answered (one full deck) before using spaced repetition
    return totalAsked >= 52
end

-- Initialize question order using spaced repetition algorithm
function GameState:initializeSpacedRepetitionOrder()
    -- Create weighted pool based on difficulty and time since last asked
    local weightedPool = {}
    local currentTime = pd.getCurrentTimeMilliseconds() / 1000

    for position = 1, 52 do
        local stats = self.cardStats[position]
        local weight = stats.difficulty

        -- Increase weight if it's been a while since last asked
        if stats.lastAsked > 0 then
            local timeSinceLastAsked = currentTime - stats.lastAsked
            -- Add weight for cards not seen recently (more than 5 minutes)
            if timeSinceLastAsked > 300 then
                weight = weight * (1 + (timeSinceLastAsked / 300) * 0.5)
            end
        end

        -- Cards with low success rate get higher weight
        if stats.timesAsked > 0 then
            local successRate = stats.timesCorrect / stats.timesAsked
            if successRate < 0.5 then
                weight = weight * 2
            elseif successRate < 0.7 then
                weight = weight * 1.5
            end
        end

        -- Add this position to the weighted pool
        table.insert(weightedPool, {position = position, weight = weight})
    end

    -- Sort by weight (highest difficulty first)
    table.sort(weightedPool, function(a, b) return a.weight > b.weight end)

    -- Create question order with bias towards difficult cards
    self.questionOrder = {}
    local remaining = {}
    for _, item in ipairs(weightedPool) do
        table.insert(remaining, item.position)
    end

    -- Take 70% of cards weighted by difficulty, 30% random
    local weightedCount = math.floor(52 * 0.7)
    local addedPositions = {}

    -- Add weighted selections (more difficult cards appear earlier)
    for i = 1, weightedCount do
        if #remaining > 0 then
            -- Use weighted random selection biased towards beginning of array
            local maxIndex = math.min(#remaining, 10)  -- Consider top 10 most difficult
            local index = math.random(1, maxIndex)
            local position = remaining[index]
            table.insert(self.questionOrder, position)
            addedPositions[position] = true
            table.remove(remaining, index)
        end
    end

    -- Add remaining cards in random order
    for i = #remaining, 1, -1 do
        local j = math.random(1, i)
        remaining[i], remaining[j] = remaining[j], remaining[i]
    end

    for _, position in ipairs(remaining) do
        table.insert(self.questionOrder, position)
    end

    -- Final shuffle to add some randomness while keeping difficult cards toward the beginning
    for i = 1, 10 do
        local j = math.random(1, 20)  -- Only shuffle within first 20 positions
        local k = math.random(1, 20)
        if j <= #self.questionOrder and k <= #self.questionOrder then
            self.questionOrder[j], self.questionOrder[k] = self.questionOrder[k], self.questionOrder[j]
        end
    end
end

-- Submit an answer
function GameState:submitAnswer(answer, passed)
    self.userAnswer = answer
    self.userPassed = passed or false
    self.questionsAnswered = self.questionsAnswered + 1

    if passed then
        self.questionsPassed = self.questionsPassed + 1
        self.userWasCorrect = false
        -- Update card statistics for passed questions (counts as incorrect)
        self:updateCardStats(self.currentPosition, false)
    else
        self.userWasCorrect = (answer == self.correctAnswer)

        if self.userWasCorrect then
            self.score = self.score + 1
            self.questionsCorrect = self.questionsCorrect + 1
            -- Update card statistics for correct answer
            self:updateCardStats(self.currentPosition, true)
        else
            self.questionsIncorrect = self.questionsIncorrect + 1
            -- Track mistake for review
            table.insert(self.mistakes, {
                position = self.currentPosition,
                correctAnswer = self.correctAnswer,
                userAnswer = answer
            })
            -- Update card statistics for incorrect answer
            self:updateCardStats(self.currentPosition, false)
        end
    end

    self.quizState = GameState.QUIZ_STATES.FEEDBACK
end

-- Move to next question
function GameState:nextQuestion()
    self.questionIndex = self.questionIndex + 1

    if self.questionIndex > self.totalQuestions then
        -- Quiz complete
        self:completeQuiz()
    else
        -- Set up next question
        self.currentPosition = self.questionOrder[self.questionIndex]
        self.quizState = GameState.QUIZ_STATES.QUESTION

        -- Reset answer state
        self.userAnswer = ""
        self.userWasCorrect = false
        self.userPassed = false
    end
end

-- Complete the current quiz
function GameState:completeQuiz()
    -- Capture final time
    local currentTime = pd.getCurrentTimeMilliseconds() / 1000
    self.elapsedTime = currentTime - self.startTime

    -- Update high scores if better
    self:updateHighScoresIfBetter()

    self.quizState = GameState.QUIZ_STATES.COMPLETE
end

-- Update timer (call in update loop)
function GameState:updateTimer()
    if not self.isPaused and self.quizState ~= GameState.QUIZ_STATES.COMPLETE then
        local currentTime = pd.getCurrentTimeMilliseconds() / 1000
        self.elapsedTime = currentTime - self.startTime
    end
end

-- Get formatted time string (MM:SS)
function GameState:getFormattedTime()
    local minutes = math.floor(self.elapsedTime / 60)
    local seconds = math.floor(self.elapsedTime % 60)
    return string.format("%d:%02d", minutes, seconds)
end

-- Get progress string
function GameState:getProgressString()
    return string.format("Question %d of %d", self.questionIndex, self.totalQuestions)
end

-- Get score percentage
function GameState:getScorePercentage()
    if self.questionsAnswered == 0 then
        return 0
    end
    return math.floor((self.score / self.questionsAnswered) * 100)
end

-- Check if current score is a new high score
function GameState:isNewHighScore()
    local modeScores = self:getCurrentModeHighScores()

    if self.score > modeScores.bestScore then
        return true
    elseif self.score == modeScores.bestScore and self.elapsedTime < modeScores.bestTime then
        return true
    end

    return false
end

-- Get high scores for current mode
function GameState:getCurrentModeHighScores()
    if self.currentMode == GameState.MODES.QUIZ_NUMBER_TO_CARD then
        return self.highScores.numberToCard
    elseif self.currentMode == GameState.MODES.QUIZ_CARD_TO_NUMBER then
        return self.highScores.cardToNumber
    end
    return { bestScore = 0, bestTime = math.huge }
end

-- Update high scores if current score is better
function GameState:updateHighScoresIfBetter()
    local modeScores = self:getCurrentModeHighScores()

    if self:isNewHighScore() then
        modeScores.bestScore = self.score
        modeScores.bestTime = self.elapsedTime
        self:saveHighScores()
        return true
    end

    return false
end

-- Save high scores to persistent storage
function GameState:saveHighScores()
    pd.datastore.write(self.highScores, "highscores")
end

-- Load high scores from persistent storage
function GameState:loadHighScores()
    local savedScores = pd.datastore.read("highscores")
    if savedScores then
        -- Merge saved scores with defaults (in case structure changed)
        if savedScores.numberToCard then
            self.highScores.numberToCard = savedScores.numberToCard
            -- Handle old saves that might not have bestTime
            if not self.highScores.numberToCard.bestTime then
                self.highScores.numberToCard.bestTime = math.huge
            end
        end

        if savedScores.cardToNumber then
            self.highScores.cardToNumber = savedScores.cardToNumber
            if not self.highScores.cardToNumber.bestTime then
                self.highScores.cardToNumber.bestTime = math.huge
            end
        end

        -- Handle legacy single high score format
        if savedScores.bestScore and not savedScores.numberToCard then
            self.highScores.numberToCard.bestScore = savedScores.bestScore
            self.highScores.numberToCard.bestTime = savedScores.bestTime or math.huge
        end
    end
end

-- Save entire game state (for pause/resume)
function GameState:saveState()
    local stateData = {
        currentMode = self.currentMode,
        quizState = self.quizState,
        score = self.score,
        startTime = self.startTime,
        elapsedTime = self.elapsedTime,
        questionOrder = self.questionOrder,
        questionIndex = self.questionIndex,
        currentPosition = self.currentPosition,
        mistakes = self.mistakes,
        questionsAnswered = self.questionsAnswered,
        questionsCorrect = self.questionsCorrect,
        questionsIncorrect = self.questionsIncorrect,
        questionsPassed = self.questionsPassed,
        soundEnabled = self.soundEnabled,
        crankSensitivity = self.crankSensitivity,
        selectedAnswer = self.selectedAnswer,
        correctAnswer = self.correctAnswer,
        userAnswer = self.userAnswer,
        userWasCorrect = self.userWasCorrect,
        userPassed = self.userPassed
    }

    pd.datastore.write(stateData, "gamestate")
end

-- Load game state (for resume)
function GameState:loadState()
    local stateData = pd.datastore.read("gamestate")
    if stateData then
        -- Restore state
        for key, value in pairs(stateData) do
            self[key] = value
        end
        return true
    end
    return false
end

-- Clear saved state
function GameState:clearSavedState()
    pd.datastore.delete("gamestate")
end

-- Save card statistics for spaced repetition
function GameState:saveCardStats()
    pd.datastore.write(self.cardStats, "cardstats")
end

-- Load card statistics from persistent storage
function GameState:loadCardStats()
    local savedStats = pd.datastore.read("cardstats")
    if savedStats then
        self.cardStats = savedStats
    end
end

-- Update card statistics after answering a question
function GameState:updateCardStats(position, wasCorrect)
    local stats = self.cardStats[position]
    if stats then
        stats.timesAsked = stats.timesAsked + 1
        stats.lastAsked = pd.getCurrentTimeMilliseconds() / 1000

        if wasCorrect then
            stats.timesCorrect = stats.timesCorrect + 1
            stats.streak = stats.streak + 1
            -- Reduce difficulty when answered correctly
            stats.difficulty = math.max(0.1, stats.difficulty * 0.9)
        else
            stats.timesIncorrect = stats.timesIncorrect + 1
            stats.streak = 0
            -- Increase difficulty when answered incorrectly
            stats.difficulty = math.min(10.0, stats.difficulty * 1.5)
        end

        -- Auto-save card stats after each update
        self:saveCardStats()
    end
end

-- Get success rate for a specific position
function GameState:getCardSuccessRate(position)
    local stats = self.cardStats[position]
    if stats and stats.timesAsked > 0 then
        return stats.timesCorrect / stats.timesAsked
    end
    return 0
end

-- Reset all card statistics
function GameState:resetCardStats()
    for i = 1, 52 do
        self.cardStats[i] = {
            timesAsked = 0,
            timesCorrect = 0,
            timesIncorrect = 0,
            lastAsked = 0,
            streak = 0,
            difficulty = 1.0
        }
    end
    self:saveCardStats()
end

-- Pause the game
function GameState:pause()
    self.isPaused = true
    self:saveState()
end

-- Resume the game
function GameState:resume()
    self.isPaused = false
    -- Adjust start time to account for pause duration
    local currentTime = pd.getCurrentTimeMilliseconds() / 1000
    self.startTime = currentTime - self.elapsedTime
end

-- Reset to initial state
function GameState:reset()
    -- Keep high scores, settings, and card statistics
    local savedHighScores = self.highScores
    local savedSoundEnabled = self.soundEnabled
    local savedCrankSensitivity = self.crankSensitivity
    local savedCardStats = self.cardStats

    -- Re-initialize
    local newState = GameState:new()
    for key, value in pairs(newState) do
        self[key] = value
    end

    -- Restore saved values
    self.highScores = savedHighScores
    self.soundEnabled = savedSoundEnabled
    self.crankSensitivity = savedCrankSensitivity
    self.cardStats = savedCardStats
end

return GameState
