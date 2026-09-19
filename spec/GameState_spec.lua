local stub = require("spec.support.playdate_stub")
import "GameState"

local function finishQuizWithMistakes(gameState, mistakeCount)
    gameState:startQuiz(GameState.MODES.QUIZ_NUMBER_TO_CARD)
    for question = 1, 52 do
        gameState.correctAnswer = "RIGHT"
        gameState:submitAnswer(question <= mistakeCount and "WRONG" or "RIGHT")
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

    it("abandons any mistake review when a new quiz starts", function()
        local gameState = GameState:new()
        finishQuizWithMistakes(gameState, 2)
        gameState:startMistakeReview()

        gameState:startQuiz(GameState.MODES.QUIZ_CARD_TO_NUMBER)

        assert.is_nil(gameState.mistakeReviewMode)
        assert.is_nil(gameState.originalSession)
        assert.are.equal(GameState.MODES.QUIZ_CARD_TO_NUMBER, gameState:getQuizMode())
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

describe("GameState card statistics", function()
    before_each(function() stub.reset() end)

    it("writes the statistics file when a quiz finishes, not after every answer", function()
        local gameState = GameState:new()
        gameState:startQuiz(GameState.MODES.QUIZ_NUMBER_TO_CARD)
        for _ = 1, 51 do
            gameState.correctAnswer = "RIGHT"
            gameState:submitAnswer("RIGHT")
            gameState:nextQuestion()
        end
        assert.is_nil(stub.writeCounts.cardstats)

        gameState.correctAnswer = "RIGHT"
        gameState:submitAnswer("RIGHT")
        gameState:nextQuestion()

        assert.are.equal(1, stub.writeCounts.cardstats)
        assert.are.equal(1, stub.datastore.cardstats[1].timesAsked)
    end)

    it("stops the quiz clock while the game is suspended and saves progress", function()
        local gameState = GameState:new()
        gameState:startQuiz(GameState.MODES.QUIZ_NUMBER_TO_CARD)
        gameState.correctAnswer = "RIGHT"
        gameState:submitAnswer("RIGHT")
        stub.advanceSeconds(10)

        gameState:suspend()
        stub.advanceSeconds(600)
        gameState:unsuspend()
        stub.advanceSeconds(5)

        assert.are.equal(15, gameState.currentSession:getElapsedTime())
        assert.are.equal(1, stub.writeCounts.cardstats)
    end)

    it("can be suspended outside a quiz", function()
        local gameState = GameState:new()
        gameState:suspend()
        gameState:unsuspend()
    end)
end)
