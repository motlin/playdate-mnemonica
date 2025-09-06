-- QuizSession data structure for Mnemonica Quiz
-- Encapsulates all data for a single quiz session including questions, answers, and mistakes

local pd <const> = playdate

local QuizSession = {}
QuizSession.__index = QuizSession

function QuizSession:new(mode, totalQuestions)
    local session = setmetatable({}, self)

    -- Session metadata
    session.mode = mode  -- Quiz mode (number_to_card or card_to_number)
    session.totalQuestions = totalQuestions or 52
    session.startTime = pd.getCurrentTimeMilliseconds() / 1000
    session.endTime = nil
    session.isComplete = false

    -- Question management
    session.questions = {}  -- Array of question objects
    session.currentQuestionIndex = 1

    -- Answer tracking
    session.answers = {}  -- Array of answer objects indexed by question number

    -- Mistake tracking
    session.mistakes = {}  -- Array of mistake objects for review

    -- Statistics
    session.statistics = {
        questionsAnswered = 0,
        questionsCorrect = 0,
        questionsIncorrect = 0,
        questionsPassed = 0,
        score = 0,
        elapsedTime = 0,
        accuracy = 0  -- Percentage
    }

    return session
end

-- Initialize questions for the session (shuffled order)
function QuizSession:initializeQuestions(positions, shuffleOrder)
    self.questions = {}

    if shuffleOrder then
        -- Create shuffled copy
        local shuffled = {}
        for i, pos in ipairs(positions) do
            shuffled[i] = pos
        end

        -- Fisher-Yates shuffle
        for i = #shuffled, 2, -1 do
            local j = math.random(1, i)
            shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        end

        -- Create question objects
        for i, position in ipairs(shuffled) do
            self.questions[i] = {
                index = i,
                position = position,  -- The Mnemonica stack position (1-52)
                askedAt = nil,  -- Timestamp when question was asked
                answeredAt = nil  -- Timestamp when answer was submitted
            }
        end
    else
        -- Use provided order
        for i, position in ipairs(positions) do
            self.questions[i] = {
                index = i,
                position = position,
                askedAt = nil,
                answeredAt = nil
            }
        end
    end

    self.currentQuestionIndex = 1
end

-- Get the current question
function QuizSession:getCurrentQuestion()
    if self.currentQuestionIndex <= #self.questions then
        local question = self.questions[self.currentQuestionIndex]
        -- Mark as asked if not already
        if not question.askedAt then
            question.askedAt = pd.getCurrentTimeMilliseconds() / 1000
        end
        return question
    end
    return nil
end

-- Record an answer for the current question
function QuizSession:recordAnswer(userAnswer, correctAnswer, passed)
    local question = self:getCurrentQuestion()
    if not question then return false end

    local answeredAt = pd.getCurrentTimeMilliseconds() / 1000
    question.answeredAt = answeredAt

    -- Calculate time taken for this question
    local timeTaken = answeredAt - question.askedAt

    -- Determine if answer is correct
    local isCorrect = false
    if not passed then
        isCorrect = (userAnswer == correctAnswer)
    end

    -- Create answer record
    local answerRecord = {
        questionIndex = self.currentQuestionIndex,
        position = question.position,
        userAnswer = userAnswer,
        correctAnswer = correctAnswer,
        isCorrect = isCorrect,
        passed = passed,
        timeTaken = timeTaken,
        answeredAt = answeredAt
    }

    -- Store answer
    self.answers[self.currentQuestionIndex] = answerRecord

    -- Update statistics
    self.statistics.questionsAnswered = self.statistics.questionsAnswered + 1

    if passed then
        self.statistics.questionsPassed = self.statistics.questionsPassed + 1
        -- Track as mistake for review
        table.insert(self.mistakes, {
            position = question.position,
            correctAnswer = correctAnswer,
            userAnswer = "PASSED",
            questionIndex = self.currentQuestionIndex
        })
    elseif isCorrect then
        self.statistics.questionsCorrect = self.statistics.questionsCorrect + 1
        self.statistics.score = self.statistics.score + 1
    else
        self.statistics.questionsIncorrect = self.statistics.questionsIncorrect + 1
        -- Track mistake for review
        table.insert(self.mistakes, {
            position = question.position,
            correctAnswer = correctAnswer,
            userAnswer = userAnswer,
            questionIndex = self.currentQuestionIndex
        })
    end

    -- Update accuracy
    if self.statistics.questionsAnswered > 0 then
        self.statistics.accuracy = math.floor((self.statistics.score / self.statistics.questionsAnswered) * 100)
    end

    return true
end

-- Move to the next question
function QuizSession:nextQuestion()
    if self.currentQuestionIndex < #self.questions then
        self.currentQuestionIndex = self.currentQuestionIndex + 1
        return true
    else
        -- Session is complete
        self:complete()
        return false
    end
end

-- Complete the session
function QuizSession:complete()
    if not self.isComplete then
        self.endTime = pd.getCurrentTimeMilliseconds() / 1000
        self.statistics.elapsedTime = self.endTime - self.startTime
        self.isComplete = true
    end
end

-- Get elapsed time for the session
function QuizSession:getElapsedTime()
    if self.isComplete and self.endTime then
        return self.endTime - self.startTime
    else
        local currentTime = pd.getCurrentTimeMilliseconds() / 1000
        return currentTime - self.startTime
    end
end

-- Get formatted time string (MM:SS)
function QuizSession:getFormattedTime()
    local elapsed = self:getElapsedTime()
    local minutes = math.floor(elapsed / 60)
    local seconds = math.floor(elapsed % 60)
    return string.format("%d:%02d", minutes, seconds)
end

-- Get progress string
function QuizSession:getProgressString()
    return string.format("Question %d of %d", self.currentQuestionIndex, self.totalQuestions)
end

-- Check if session has mistakes to review
function QuizSession:hasMistakes()
    return #self.mistakes > 0
end

-- Get mistake positions for review
function QuizSession:getMistakePositions()
    local positions = {}
    local seen = {}  -- Avoid duplicates

    for _, mistake in ipairs(self.mistakes) do
        if not seen[mistake.position] then
            table.insert(positions, mistake.position)
            seen[mistake.position] = true
        end
    end

    return positions
end

-- Create a review session from mistakes
function QuizSession:createReviewSession()
    if not self:hasMistakes() then
        return nil
    end

    local reviewSession = QuizSession:new(self.mode, #self:getMistakePositions())
    reviewSession:initializeQuestions(self:getMistakePositions(), true)
    reviewSession.isReviewSession = true
    reviewSession.parentSessionId = self.sessionId  -- Link to original session if needed

    return reviewSession
end

-- Get session summary
function QuizSession:getSummary()
    return {
        mode = self.mode,
        score = self.statistics.score,
        totalQuestions = self.totalQuestions,
        questionsAnswered = self.statistics.questionsAnswered,
        questionsCorrect = self.statistics.questionsCorrect,
        questionsIncorrect = self.statistics.questionsIncorrect,
        questionsPassed = self.statistics.questionsPassed,
        accuracy = self.statistics.accuracy,
        elapsedTime = self.statistics.elapsedTime,
        formattedTime = self:getFormattedTime(),
        mistakes = self.mistakes,
        hasMistakes = self:hasMistakes(),
        isComplete = self.isComplete
    }
end

-- Export session data for persistence
function QuizSession:export()
    return {
        mode = self.mode,
        totalQuestions = self.totalQuestions,
        startTime = self.startTime,
        endTime = self.endTime,
        isComplete = self.isComplete,
        questions = self.questions,
        currentQuestionIndex = self.currentQuestionIndex,
        answers = self.answers,
        mistakes = self.mistakes,
        statistics = self.statistics,
        isReviewSession = self.isReviewSession,
        parentSessionId = self.parentSessionId
    }
end

-- Import session data from persistence
function QuizSession:import(data)
    if not data then return false end

    self.mode = data.mode
    self.totalQuestions = data.totalQuestions
    self.startTime = data.startTime
    self.endTime = data.endTime
    self.isComplete = data.isComplete
    self.questions = data.questions
    self.currentQuestionIndex = data.currentQuestionIndex
    self.answers = data.answers
    self.mistakes = data.mistakes
    self.statistics = data.statistics
    self.isReviewSession = data.isReviewSession
    self.parentSessionId = data.parentSessionId

    return true
end

return QuizSession
