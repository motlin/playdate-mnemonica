-- GameState manager for Mnemonica Quiz
-- Handles all game state tracking including mode, score, timer, progress, etc.

local pd <const> = playdate
import "QuizSession"
import "MistakeReviewMode"

GameState = {}
GameState.__index = GameState

-- Game modes
GameState.MODES = {
    QUIZ_NUMBER_TO_CARD = "quiz_number_to_card",
    QUIZ_CARD_TO_NUMBER = "quiz_card_to_number",
    STUDY = "study",
    SIMON = "simon",
    MENU = "menu",
    HIGH_SCORES = "high_scores",
    SETTINGS = "settings",
    MISTAKE_REVIEW = "mistake_review"  -- New mode for mistake review
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

    -- Current quiz session
    state.currentSession = nil  -- Will be initialized when quiz starts
    state.originalSession = nil  -- Preserve original session during mistake review
    state.usingSpacedRepetition = false  -- Track if current session uses spaced repetition

    -- Mistake review mode
    state.mistakeReviewMode = nil  -- Will be initialized when starting mistake review

    -- Simon mode state
    state.simonMode = {
        sequence = {},        -- Current sequence of positions to remember
        playerIndex = 1,      -- Current position in sequence the player is at
        currentRound = 0,     -- Current round (length of sequence)
        showingSequence = false,  -- Whether we're showing the sequence
        sequenceIndex = 1,    -- Current index when showing sequence
        displayTimer = 0,     -- Timer for showing each card
        phase = "SHOWING",    -- SHOWING, WAITING, INPUT, FEEDBACK
        isCorrect = true,     -- Track if player is correct so far
        maxRound = 0,         -- Track best performance
        selectedInput = "card"  -- "card" or "number" - what player is selecting
    }

    -- UI state (temporary, not part of session)
    state.selectedAnswer = 1  -- Currently selected answer (card index or position)
    state.correctAnswer = ""  -- Correct answer for current question
    state.userAnswer = ""     -- What the user selected
    state.userWasCorrect = false
    state.userPassed = false

    -- High scores
    state.highScores = GameState.emptyHighScores()

    -- Outcome of the most recently finished quiz: { isNewBest, previousBest }
    state.lastResult = nil

    -- Settings
    state.soundEnabled = true
    state.crankSensitivity = 1.0
    state.lastSelectedMenuMode = 1  -- Remember last selected menu option (1-3)

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

    -- Load saved settings including last selected menu mode
    state:loadSettings()

    return state
end

-- Start a new quiz session
function GameState:startQuiz(mode, useSpacedRepetition)
    self.currentMode = mode or GameState.MODES.QUIZ_NUMBER_TO_CARD
    self.quizState = GameState.QUIZ_STATES.QUESTION
    self.mistakeReviewMode = nil
    self.originalSession = nil

    -- Create new quiz session
    self.currentSession = QuizSession:new(self.currentMode, 52)

    -- Initialize questions with appropriate order
    local positions = {}

    -- Use spaced repetition if enabled and we have enough data
    if useSpacedRepetition == nil then
        useSpacedRepetition = true  -- Default to using spaced repetition
    end

    if useSpacedRepetition and self:hasEnoughDataForSpacedRepetition() then
        -- Get spaced repetition order
        positions = self:buildSpacedRepetitionOrder()
        self.currentSession:initializeQuestions(positions, false)  -- false = don't shuffle again
        self.usingSpacedRepetition = true
    else
        -- Use simple random shuffling
        for i = 1, 52 do
            positions[i] = i
        end
        self.currentSession:initializeQuestions(positions, true)  -- true = shuffle
        self.usingSpacedRepetition = false
    end

    -- Reset UI state
    self.selectedAnswer = 1
    self.correctAnswer = ""
    self.userAnswer = ""
    self.userWasCorrect = false
    self.userPassed = false
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
-- This prioritizes cards the user struggles with while maintaining some randomness
function GameState:buildSpacedRepetitionOrder()
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
    local questionOrder = {}
    local remaining = {}
    for _, item in ipairs(weightedPool) do
        table.insert(remaining, item.position)
    end

    -- Take 70% of cards weighted by difficulty, 30% random
    local weightedCount = math.floor(52 * 0.7)

    -- Add weighted selections (more difficult cards appear earlier)
    for _ = 1, weightedCount do
        if #remaining > 0 then
            -- Use weighted random selection biased towards beginning of array
            local maxIndex = math.min(#remaining, 10)  -- Consider top 10 most difficult
            local index = math.random(1, maxIndex)
            local position = remaining[index]
            table.insert(questionOrder, position)
            table.remove(remaining, index)
        end
    end

    -- Add remaining cards in random order
    for i = #remaining, 1, -1 do
        local j = math.random(1, i)
        remaining[i], remaining[j] = remaining[j], remaining[i]
    end

    for _, position in ipairs(remaining) do
        table.insert(questionOrder, position)
    end

    -- Final shuffle to add some randomness while keeping difficult cards toward the beginning
    for _ = 1, 10 do
        local j = math.random(1, 20)  -- Only shuffle within first 20 positions
        local k = math.random(1, 20)
        if j <= #questionOrder and k <= #questionOrder then
            questionOrder[j], questionOrder[k] = questionOrder[k], questionOrder[j]
        end
    end

    return questionOrder
end

-- Submit an answer
function GameState:submitAnswer(answer, passed)
    self.userAnswer = answer

    -- Explicitly handle the passed parameter
    if passed == true then
        self.userPassed = true
        self.userWasCorrect = false
    else
        self.userPassed = false
        self.userWasCorrect = (answer == self.correctAnswer)
    end

    self.currentSession:recordAnswer(answer, self.correctAnswer, passed)
    self:updateCardStats(self:getCurrentPosition(), self.userWasCorrect)

    self.quizState = GameState.QUIZ_STATES.FEEDBACK
end

-- Move to next question
function GameState:nextQuestion()
    if self.currentSession:nextQuestion() then
        self.quizState = GameState.QUIZ_STATES.QUESTION
        self.userAnswer = ""
        self.userWasCorrect = false
        self.userPassed = false
    else
        self:completeQuiz()
    end
end

-- Complete the current quiz. Mistake re-quizzes never count towards high scores.
function GameState:completeQuiz()
    self.currentSession:complete()
    self:saveCardStats()

    if not self.currentSession.isReviewSession then
        self.lastResult = self:recordHighScore()
    end

    self.quizState = GameState.QUIZ_STATES.COMPLETE
end

function GameState:getCurrentPosition()
    return self.currentSession:getCurrentQuestion().position
end

function GameState:getScore()
    return self.currentSession.statistics.score
end

function GameState:getQuestionsAnswered()
    return self.currentSession.statistics.questionsAnswered
end

function GameState:getMistakes()
    return self.currentSession.mistakes
end

function GameState:getFormattedTime()
    return self.currentSession:getFormattedTime()
end

function GameState:getProgressString()
    return self.currentSession:getProgressString()
end

-- Get score percentage
function GameState:getScorePercentage()
    if self:getQuestionsAnswered() == 0 then
        return 0
    end
    return math.floor((self:getScore() / self:getQuestionsAnswered()) * 100)
end

-- A mode with no finished quiz has bestScore 0 and no bestTime.
function GameState.emptyHighScores()
    return {
        numberToCard = { bestScore = 0 },
        cardToNumber = { bestScore = 0 }
    }
end

function GameState:getCurrentModeHighScores()
    if self.currentSession.mode == GameState.MODES.QUIZ_NUMBER_TO_CARD then
        return self.highScores.numberToCard
    end
    return self.highScores.cardToNumber
end

-- Compare the finished session with the record for its mode, saving it if better.
-- Best score wins; a tie on score goes to the faster time.
function GameState:recordHighScore()
    local modeScores = self:getCurrentModeHighScores()
    local score = self:getScore()
    local elapsedTime = self.currentSession:getElapsedTime()

    local previousBest = nil
    if modeScores.bestTime then
        previousBest = { bestScore = modeScores.bestScore, bestTime = modeScores.bestTime }
    end

    local isNewBest = previousBest == nil
        or score > previousBest.bestScore
        or (score == previousBest.bestScore and elapsedTime < previousBest.bestTime)

    if isNewBest then
        modeScores.bestScore = score
        modeScores.bestTime = elapsedTime
        self:saveHighScores()
    end

    return { isNewBest = isNewBest, previousBest = previousBest }
end

-- Save high scores to persistent storage
function GameState:saveHighScores()
    pd.datastore.write(self.highScores, "highscores")
end

-- Save settings including last selected menu mode
function GameState:saveSettings()
    local settings = {
        soundEnabled = self.soundEnabled,
        crankSensitivity = self.crankSensitivity,
        lastSelectedMenuMode = self.lastSelectedMenuMode,
        simonMaxRound = self.simonMode.maxRound
    }
    pd.datastore.write(settings, "settings")
end

-- Load settings including last selected menu mode
function GameState:loadSettings()
    local settings = pd.datastore.read("settings")
    if settings then
        self.soundEnabled = settings.soundEnabled ~= false  -- Default to true
        self.crankSensitivity = settings.crankSensitivity or 1.0
        self.lastSelectedMenuMode = settings.lastSelectedMenuMode or 1
        self.simonMode.maxRound = settings.simonMaxRound or 0
    end
end

-- Load high scores from persistent storage. Saves written before bestTime became optional
-- stored an infinite bestTime for modes with no finished quiz; those load as empty.
function GameState:loadHighScores()
    local savedScores = pd.datastore.read("highscores")
    if not savedScores then
        return
    end

    for mode, emptyScores in pairs(GameState.emptyHighScores()) do
        local saved = savedScores[mode]
        local hasFinishedQuiz = saved and type(saved.bestTime) == "number" and saved.bestTime < math.huge
        self.highScores[mode] = hasFinishedQuiz and saved or emptyScores
    end
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

-- Reset all high scores
function GameState:resetHighScores()
    self.highScores = GameState.emptyHighScores()
    self:saveHighScores()
end

-- The system menu opened, the device locked, or the game is closing: stop the quiz clock
-- and write anything not yet saved, since the game may not come back.
function GameState:suspend()
    if self.currentSession then
        self.currentSession:pauseTimer()
    end
    self:saveCardStats()
end

function GameState:unsuspend()
    if self.currentSession then
        self.currentSession:resumeTimer()
    end
end

-- Start mistake review mode
function GameState:startMistakeReview()
    if self.currentSession and self.currentSession:hasMistakes() then
        -- Get the mistakes from the current session
        local mistakes = self.currentSession.mistakes
        local originalMode = self.currentSession.mode

        -- Preserve the original session so we can return to its summary
        self.originalSession = self.currentSession

        -- Create the mistake review mode
        self.mistakeReviewMode = MistakeReviewMode:new(mistakes, originalMode)

        -- Switch to mistake review mode
        self.currentMode = GameState.MODES.MISTAKE_REVIEW

        -- Reset UI state
        self.selectedAnswer = 1
        self.correctAnswer = ""
        self.userAnswer = ""
        self.userWasCorrect = false
        self.userPassed = false

        return true
    end
    return false
end

-- The quiz being answered. During mistake review this is the mode of the quiz under review.
function GameState:getQuizMode()
    if self.currentMode == GameState.MODES.MISTAKE_REVIEW then
        return self.mistakeReviewMode.originalMode
    end
    return self.currentMode
end

-- Advance the study phase of a mistake review. After the last mistake, the re-quiz session
-- built by MistakeReviewMode becomes the current session.
function GameState:advanceMistakeStudy()
    if self.mistakeReviewMode:nextStudyCard() then
        return
    end

    self.currentSession = self.mistakeReviewMode.quizSession
    self.quizState = GameState.QUIZ_STATES.QUESTION

    self.selectedAnswer = 1
    self.correctAnswer = ""
    self.userAnswer = ""
    self.userWasCorrect = false
    self.userPassed = false
end

-- Get session summary
function GameState:getSessionSummary()
    return self.currentSession:getSummary()
end
