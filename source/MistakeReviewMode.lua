-- MistakeReviewMode handles the two-phase mistake review process
-- Phase 1: Study cards (review what you got wrong)
-- Phase 2: Re-quiz on mistake cards
local pd <const> = playdate

MistakeReviewMode = {}
MistakeReviewMode.__index = MistakeReviewMode

-- Review phases
MistakeReviewMode.PHASES = {
    STUDY = "study", -- Phase 1: Study the mistake cards
    QUIZ = "quiz", -- Phase 2: Re-quiz on mistakes
}

function MistakeReviewMode:new(mistakes, originalMode)
    local review = setmetatable({}, self)

    -- Store the mistakes and original quiz mode
    review.mistakes = mistakes
    review.originalMode = originalMode -- QUIZ_NUMBER_TO_CARD or QUIZ_CARD_TO_NUMBER

    -- Current phase
    review.currentPhase = MistakeReviewMode.PHASES.STUDY

    -- Study phase state
    review.studyIndex = 1 -- Current mistake being studied (1-based)
    review.studyStartTime = pd.getCurrentTimeMilliseconds() / 1000

    -- Quiz phase state (will be initialized when entering quiz phase)
    review.quizSession = nil

    -- Track overall review performance
    review.studyTimePerCard = {} -- Time spent studying each card
    review.quizResults = {} -- Results from the re-quiz

    return review
end

-- Get the current mistake being studied
function MistakeReviewMode:getCurrentStudyMistake()
    if self.currentPhase == MistakeReviewMode.PHASES.STUDY and self.studyIndex <= #self.mistakes then
        return self.mistakes[self.studyIndex]
    end
    return nil
end

-- Move to next study card. Returns false once the study phase is over and the re-quiz is ready.
function MistakeReviewMode:nextStudyCard()
    if self.currentPhase ~= MistakeReviewMode.PHASES.STUDY then return false end

    -- Record time spent on current card
    local currentTime = pd.getCurrentTimeMilliseconds() / 1000
    local timeSpent = currentTime - self.studyStartTime
    table.insert(self.studyTimePerCard, timeSpent)

    self.studyIndex = self.studyIndex + 1
    self.studyStartTime = currentTime

    -- Check if we've studied all mistakes
    if self.studyIndex > #self.mistakes then
        self:startQuizPhase()
        return false
    end

    return true
end

-- Move to previous study card
function MistakeReviewMode:previousStudyCard()
    if self.currentPhase ~= MistakeReviewMode.PHASES.STUDY then return false end

    if self.studyIndex > 1 then
        self.studyIndex = self.studyIndex - 1
        self.studyStartTime = pd.getCurrentTimeMilliseconds() / 1000
        return true
    end

    return false
end

-- Start the quiz phase
function MistakeReviewMode:startQuizPhase()
    self.currentPhase = MistakeReviewMode.PHASES.QUIZ

    -- Create a quiz session with just the mistake positions
    local positions = {}
    local seen = {}

    -- Get unique positions from mistakes
    for _, mistake in ipairs(self.mistakes) do
        if not seen[mistake.position] then
            table.insert(positions, mistake.position)
            seen[mistake.position] = true
        end
    end

    -- Create the review quiz session
    self.quizSession = QuizSession:new(self.originalMode, #positions)
    self.quizSession:initializeQuestions(positions, true) -- Shuffle the mistakes
    self.quizSession.isReviewSession = true
    self.quizSession.reviewType = "mistake_review"

    return self.quizSession
end

-- Get progress information
function MistakeReviewMode:getProgress()
    if self.currentPhase == MistakeReviewMode.PHASES.STUDY then
        return {
            phase = "study",
            current = self.studyIndex,
            total = #self.mistakes,
            text = string.format("Studying Mistake %d of %d", self.studyIndex, #self.mistakes),
        }
    elseif self.currentPhase == MistakeReviewMode.PHASES.QUIZ and self.quizSession then
        return {
            phase = "quiz",
            current = self.quizSession.currentQuestionIndex,
            total = self.quizSession.totalQuestions,
            text = self.quizSession:getProgressString(),
        }
    end

    return {
        phase = self.currentPhase,
        current = 0,
        total = 0,
        text = "",
    }
end

-- Check if review is complete
function MistakeReviewMode:isComplete()
    return self.currentPhase == MistakeReviewMode.PHASES.QUIZ and self.quizSession and self.quizSession.isComplete
end

-- Get review summary
function MistakeReviewMode:getSummary()
    local summary = {
        mistakesReviewed = #self.mistakes,
        studyTimeTotal = 0,
        averageStudyTime = 0,
    }

    -- Calculate study time stats
    for _, time in ipairs(self.studyTimePerCard) do
        summary.studyTimeTotal = summary.studyTimeTotal + time
    end

    if #self.studyTimePerCard > 0 then summary.averageStudyTime = summary.studyTimeTotal / #self.studyTimePerCard end

    -- Add quiz results if available
    if self.quizSession then
        summary.quizComplete = self.quizSession.isComplete
        summary.quizScore = self.quizSession.statistics.score
        summary.quizTotal = self.quizSession.totalQuestions
        summary.quizAccuracy = self.quizSession.statistics.accuracy
        summary.improvedMistakes = {} -- Track which mistakes were corrected in review

        -- Check which mistakes were corrected
        if self.quizSession.isComplete then
            for _, mistake in ipairs(self.mistakes) do
                local wasCorrect = true
                -- Check if this mistake was answered correctly in the review
                for _, reviewMistake in ipairs(self.quizSession.mistakes) do
                    if reviewMistake.position == mistake.position then
                        wasCorrect = false
                        break
                    end
                end
                if wasCorrect then table.insert(summary.improvedMistakes, mistake.position) end
            end
        end
    end

    return summary
end
