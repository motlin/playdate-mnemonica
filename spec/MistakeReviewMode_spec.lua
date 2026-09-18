local stub = require("spec.support.playdate_stub")
-- Load modules the way main.lua does: GameState first, then the rest.
import "GameState"
import "MistakeReviewMode"

describe("MistakeReviewMode", function()
    local mistakes

    before_each(function()
        stub.reset()
        mistakes = {
            { position = 7, correctAnswer = "AS", userAnswer = "2S" },
            { position = 20, correctAnswer = "JH", userAnswer = "10H" },
        }
    end)

    it("is reachable after GameState has already imported it", function()
        assert.is_table(MistakeReviewMode)
        assert.are.equal("study", MistakeReviewMode.PHASES.STUDY)
    end)

    it("keeps studying while mistakes remain", function()
        local review = MistakeReviewMode:new(mistakes, "quiz_number_to_card")

        assert.is_true(review:nextStudyCard())
        assert.are.equal(MistakeReviewMode.PHASES.STUDY, review.currentPhase)
        assert.are.equal(20, review:getCurrentStudyMistake().position)
    end)

    it("reports the study phase is over and builds the re-quiz after the last mistake", function()
        local review = MistakeReviewMode:new(mistakes, "quiz_number_to_card")
        review:nextStudyCard()

        assert.is_false(review:nextStudyCard())
        assert.are.equal(MistakeReviewMode.PHASES.QUIZ, review.currentPhase)
        assert.are.equal(2, review.quizSession.totalQuestions)
    end)
end)
