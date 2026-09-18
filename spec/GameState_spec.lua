local stub = require("spec.support.playdate_stub")
import "GameState"

local function finishQuizWithMistakes(gameState, mistakeCount)
    gameState:startQuiz(GameState.MODES.QUIZ_NUMBER_TO_CARD)
    for question = 1, 52 do
        gameState.correctAnswer = "RIGHT"
        gameState:submitAnswer(question <= mistakeCount and "WRONG" or "RIGHT", false)
        gameState:nextQuestion()
    end
end

describe("GameState mistake review", function()
    before_each(function() stub.reset() end)

    it("moves from studying the last mistake into a re-quiz of only the mistakes", function()
        local gameState = GameState:new()
        finishQuizWithMistakes(gameState, 3)
        assert.are.equal(GameState.QUIZ_STATES.COMPLETE, gameState.quizState)
        local originalSession = gameState.currentSession

        assert.is_true(gameState:startMistakeReview())
        gameState:advanceMistakeStudy()
        gameState:advanceMistakeStudy()
        assert.are.equal(GameState.QUIZ_STATES.COMPLETE, gameState.quizState)

        gameState:advanceMistakeStudy()

        assert.are.equal(GameState.QUIZ_STATES.QUESTION, gameState.quizState)
        assert.are.equal(3, gameState.currentSession.totalQuestions)
        assert.are.equal(originalSession, gameState.originalSession)
    end)

    it("reports the quiz being answered, which during review is the original quiz's mode", function()
        local gameState = GameState:new()
        finishQuizWithMistakes(gameState, 1)
        assert.are.equal(GameState.MODES.QUIZ_NUMBER_TO_CARD, gameState:getQuizMode())

        gameState:startMistakeReview()

        assert.are.equal(GameState.MODES.MISTAKE_REVIEW, gameState.currentMode)
        assert.are.equal(GameState.MODES.QUIZ_NUMBER_TO_CARD, gameState:getQuizMode())
    end)
end)
