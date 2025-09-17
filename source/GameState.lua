-- GameState manager for Mnemonica Quiz
-- Handles all game state tracking including mode, score, timer, progress, etc.

local pd <const> = playdate
local QuizSession = import "QuizSession"
local MistakeReviewMode = import "MistakeReviewMode"

local GameState = {}
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

    -- Pause state
    state.isPaused = false

    -- Legacy fields for compatibility (lazily populated from session when needed)
    state._legacyFieldsCache = nil  -- Cache for legacy field access

    -- High scores
    state.highScores = {
        numberToCard = { bestScore = 0, bestTime = math.huge },
        cardToNumber = { bestScore = 0, bestTime = math.huge }
    }

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

    -- Add metamethod for lazy loading of legacy fields
    local mt = getmetatable(state) or {}
    mt.__index = function(self, key)
        -- Legacy field access - get from session if available
        if key == "score" then
            return self.currentSession and self.currentSession.statistics.score or 0
        elseif key == "questionsAnswered" then
            return self.currentSession and self.currentSession.statistics.questionsAnswered or 0
        elseif key == "questionsCorrect" then
            return self.currentSession and self.currentSession.statistics.questionsCorrect or 0
        elseif key == "questionsIncorrect" then
            return self.currentSession and self.currentSession.statistics.questionsIncorrect or 0
        elseif key == "questionsPassed" then
            return self.currentSession and self.currentSession.statistics.questionsPassed or 0
        elseif key == "mistakes" then
            return self.currentSession and self.currentSession.mistakes or {}
        elseif key == "currentPosition" then
            if self.currentSession then
                local question = self.currentSession:getCurrentQuestion()
                return question and question.position or 1
            end
            return 1
        elseif key == "questionIndex" then
            return self.currentSession and self.currentSession.currentQuestionIndex or 1
        elseif key == "elapsedTime" then
            return self.currentSession and self.currentSession:getElapsedTime() or 0
        elseif key == "startTime" then
            return self.currentSession and self.currentSession.startTime or 0
        elseif key == "questionOrder" then
            if self.currentSession then
                local order = {}
                for i, q in ipairs(self.currentSession.questions) do
                    order[i] = q.position
                end
                return order
            end
            return {}
        else
            -- Use original __index behavior
            return rawget(GameState, key)
        end
    end
    setmetatable(state, mt)

    return state
end

-- Start a new quiz session
function GameState:startQuiz(mode, useSpacedRepetition)
    self.currentMode = mode or GameState.MODES.QUIZ_NUMBER_TO_CARD
    self.quizState = GameState.QUIZ_STATES.QUESTION

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
        self:initializeSpacedRepetitionOrder()
        for i = 1, 52 do
            positions[i] = self.questionOrder[i]
        end
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

    -- Update legacy fields for compatibility
    self:syncLegacyFields()

    -- Reset UI state
    self.selectedAnswer = 1
    self.correctAnswer = ""
    self.userAnswer = ""
    self.userWasCorrect = false
    self.userPassed = false
    self.isPaused = false
end

-- Legacy compatibility function (now a no-op due to lazy loading)
function GameState:syncLegacyFields()
    -- Fields are now lazily loaded via __index metamethod
    -- This function is kept for compatibility but does nothing
end

-- Initialize shuffled question order using Fisher-Yates algorithm
-- This is now mostly handled by QuizSession, but kept for compatibility
function GameState:initializeQuestionOrder(useSpacedRepetition)
    if self.currentSession then
        -- Session handles its own question order
        return
    end

    -- Legacy implementation
    self.questionOrder = {}

    if useSpacedRepetition and self:hasEnoughDataForSpacedRepetition() then
        self:initializeSpacedRepetitionOrder()
    else
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
-- This prioritizes cards the user struggles with while maintaining some randomness
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

    -- Explicitly handle the passed parameter
    if passed == true then
        self.userPassed = true
        self.userWasCorrect = false
    else
        self.userPassed = false
        self.userWasCorrect = (answer == self.correctAnswer)
    end

    -- Record answer in session
    if self.currentSession then
        self.currentSession:recordAnswer(answer, self.correctAnswer, passed)

        -- Update card statistics
        local question = self.currentSession:getCurrentQuestion()
        if question then
            self:updateCardStats(question.position, self.userWasCorrect)
        end

        -- Sync legacy fields
        self:syncLegacyFields()
    else
        -- Fallback to legacy behavior if no session
        self.questionsAnswered = self.questionsAnswered + 1

        if passed then
            self.questionsPassed = self.questionsPassed + 1
            self:updateCardStats(self.currentPosition, false)
        else
            if self.userWasCorrect then
                self.score = self.score + 1
                self.questionsCorrect = self.questionsCorrect + 1
                self:updateCardStats(self.currentPosition, true)
            else
                self.questionsIncorrect = self.questionsIncorrect + 1
                table.insert(self.mistakes, {
                    position = self.currentPosition,
                    correctAnswer = self.correctAnswer,
                    userAnswer = answer
                })
                self:updateCardStats(self.currentPosition, false)
            end
        end
    end

    self.quizState = GameState.QUIZ_STATES.FEEDBACK
end

-- Move to next question
function GameState:nextQuestion()
    if self.currentSession then
        if self.currentSession:nextQuestion() then
            -- More questions available
            self.quizState = GameState.QUIZ_STATES.QUESTION

            -- Sync legacy fields
            self:syncLegacyFields()

            -- Reset answer state
            self.userAnswer = ""
            self.userWasCorrect = false
            self.userPassed = false
        else
            -- Quiz complete
            self:completeQuiz()
        end
    else
        -- Fallback to legacy behavior
        self.questionIndex = self.questionIndex + 1

        if self.questionIndex > self.totalQuestions then
            self:completeQuiz()
        else
            self.currentPosition = self.questionOrder[self.questionIndex]
            self.quizState = GameState.QUIZ_STATES.QUESTION
            self.userAnswer = ""
            self.userWasCorrect = false
            self.userPassed = false
        end
    end
end

-- Complete the current quiz
function GameState:completeQuiz()
    if self.currentSession then
        self.currentSession:complete()
        -- Sync legacy fields one final time
        self:syncLegacyFields()
    else
        -- Legacy behavior
        local currentTime = pd.getCurrentTimeMilliseconds() / 1000
        self.elapsedTime = currentTime - self.startTime
    end

    -- Update high scores if better
    self:updateHighScoresIfBetter()

    self.quizState = GameState.QUIZ_STATES.COMPLETE
end

-- Update timer (call in update loop)
function GameState:updateTimer()
    if not self.isPaused and self.quizState ~= GameState.QUIZ_STATES.COMPLETE then
        if self.currentSession then
            self.elapsedTime = self.currentSession:getElapsedTime()
        else
            local currentTime = pd.getCurrentTimeMilliseconds() / 1000
            self.elapsedTime = currentTime - self.startTime
        end
    end
end

-- Get formatted time string (MM:SS)
function GameState:getFormattedTime()
    if self.currentSession then
        return self.currentSession:getFormattedTime()
    else
        local minutes = math.floor(self.elapsedTime / 60)
        local seconds = math.floor(self.elapsedTime % 60)
        return string.format("%d:%02d", minutes, seconds)
    end
end

-- Get progress string
function GameState:getProgressString()
    if self.currentSession then
        return self.currentSession:getProgressString()
    else
        return string.format("Question %d of %d", self.questionIndex, self.totalQuestions)
    end
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
        soundEnabled = self.soundEnabled,
        crankSensitivity = self.crankSensitivity,
        lastSelectedMenuMode = self.lastSelectedMenuMode,
        selectedAnswer = self.selectedAnswer,
        correctAnswer = self.correctAnswer,
        userAnswer = self.userAnswer,
        userWasCorrect = self.userWasCorrect,
        userPassed = self.userPassed
    }

    -- Save session data if exists
    if self.currentSession then
        stateData.sessionData = self.currentSession:export()
    end
    -- Note: Legacy fields are now lazily loaded, no need to save them separately

    pd.datastore.write(stateData, "gamestate")
end

-- Load game state (for resume)
function GameState:loadState()
    local stateData = pd.datastore.read("gamestate")
    if stateData then
        -- Restore basic state
        self.currentMode = stateData.currentMode
        self.quizState = stateData.quizState
        self.soundEnabled = stateData.soundEnabled
        self.crankSensitivity = stateData.crankSensitivity
        self.lastSelectedMenuMode = stateData.lastSelectedMenuMode or 1
        self.selectedAnswer = stateData.selectedAnswer
        self.correctAnswer = stateData.correctAnswer
        self.userAnswer = stateData.userAnswer
        self.userWasCorrect = stateData.userWasCorrect
        self.userPassed = stateData.userPassed

        -- Restore session if exists
        if stateData.sessionData then
            self.currentSession = QuizSession:new(self.currentMode, 52)
            self.currentSession:import(stateData.sessionData)
        end
        -- Legacy fields are handled by __index metamethod
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

-- Reset all high scores
function GameState:resetHighScores()
    self.highScores = {
        numberToCard = { bestScore = 0, bestTime = math.huge },
        cardToNumber = { bestScore = 0, bestTime = math.huge }
    }
    self:saveHighScores()
end

-- Pause the game
function GameState:pause()
    self.isPaused = true
    if self.currentSession then
        self.currentSession:pauseTimer()
    end
    self:saveState()
end

-- Resume the game
function GameState:resume()
    self.isPaused = false
    if self.currentSession and not self.currentSession.isComplete then
        self.currentSession:resumeTimer()
    else
        -- Legacy: Adjust start time to account for pause duration
        local currentTime = pd.getCurrentTimeMilliseconds() / 1000
        self.startTime = currentTime - self.elapsedTime
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

-- Create a review session from current session's mistakes (legacy support)
function GameState:createReviewSession()
    -- This now uses the new mistake review system
    return self:startMistakeReview()
end

-- Transition from study phase to quiz phase in mistake review
function GameState:transitionToMistakeQuiz()
    if self.mistakeReviewMode and
       self.mistakeReviewMode.currentPhase == MistakeReviewMode.PHASES.STUDY then
        -- Start the quiz phase
        local quizSession = self.mistakeReviewMode:startQuizPhase()
        if quizSession then
            -- Set the review quiz session as current (original is preserved)
            self.currentSession = quizSession
            self.quizState = GameState.QUIZ_STATES.QUESTION

            -- Sync legacy fields
            self:syncLegacyFields()

            -- Reset UI state
            self.selectedAnswer = 1
            self.correctAnswer = ""
            self.userAnswer = ""
            self.userWasCorrect = false
            self.userPassed = false

            return true
        end
    end
    return false
end

-- Get session summary
function GameState:getSessionSummary()
    if self.currentSession then
        return self.currentSession:getSummary()
    else
        -- Create legacy summary
        return {
            mode = self.currentMode,
            score = self.score,
            totalQuestions = self.totalQuestions,
            questionsAnswered = self.questionsAnswered,
            questionsCorrect = self.questionsCorrect,
            questionsIncorrect = self.questionsIncorrect,
            questionsPassed = self.questionsPassed,
            accuracy = self:getScorePercentage(),
            elapsedTime = self.elapsedTime,
            formattedTime = self:getFormattedTime(),
            mistakes = self.mistakes,
            hasMistakes = #self.mistakes > 0,
            isComplete = self.quizState == GameState.QUIZ_STATES.COMPLETE
        }
    end
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
