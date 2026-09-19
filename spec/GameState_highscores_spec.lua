local stub = require("spec.support.playdate_stub")
import "GameState"

local function playQuiz(gameState, mode, correctCount, seconds)
    gameState:startQuiz(mode)
    for question = 1, 52 do
        gameState.correctAnswer = "RIGHT"
        gameState:submitAnswer(question <= correctCount and "RIGHT" or "WRONG")
        if question == 52 then stub.advanceSeconds(seconds) end
        gameState:nextQuestion()
    end
end

describe("GameState high scores", function()
    local NUMBER_TO_CARD <const> = "quiz_number_to_card"

    before_each(function() stub.reset() end)

    it("treats the first finished quiz as a new best with no previous best", function()
        local gameState = GameState:new()

        playQuiz(gameState, NUMBER_TO_CARD, 40, 100)

        assert.is_true(gameState.lastResult.isNewBest)
        assert.is_nil(gameState.lastResult.previousBest)
        assert.are.same({ bestScore = 40, bestTime = 100 }, gameState.highScores.numberToCard)
    end)

    it("keeps the record and reports it as the previous best when a later quiz scores lower", function()
        local gameState = GameState:new()
        playQuiz(gameState, NUMBER_TO_CARD, 40, 100)

        playQuiz(gameState, NUMBER_TO_CARD, 30, 50)

        assert.is_false(gameState.lastResult.isNewBest)
        assert.are.same({ bestScore = 40, bestTime = 100 }, gameState.lastResult.previousBest)
        assert.are.same({ bestScore = 40, bestTime = 100 }, gameState.highScores.numberToCard)
    end)

    it("breaks a tie on score with the faster time", function()
        local gameState = GameState:new()
        playQuiz(gameState, NUMBER_TO_CARD, 40, 100)

        playQuiz(gameState, NUMBER_TO_CARD, 40, 90)

        assert.is_true(gameState.lastResult.isNewBest)
        assert.are.same({ bestScore = 40, bestTime = 100 }, gameState.lastResult.previousBest)
        assert.are.same({ bestScore = 40, bestTime = 90 }, gameState.highScores.numberToCard)
    end)

    it("does not let a mistake re-quiz touch the high scores", function()
        local gameState = GameState:new()
        playQuiz(gameState, NUMBER_TO_CARD, 1, 100)
        gameState:startMistakeReview()
        for _ = 1, 51 do gameState:advanceMistakeStudy() end

        for _ = 1, 51 do
            gameState.correctAnswer = "RIGHT"
            gameState:submitAnswer("RIGHT")
            gameState:nextQuestion()
        end

        assert.are.equal(GameState.QUIZ_STATES.COMPLETE, gameState.quizState)
        assert.are.same({ bestScore = 1, bestTime = 100 }, gameState.highScores.numberToCard)
    end)

    it("persists only finite numbers so the save file is valid JSON", function()
        local gameState = GameState:new()
        gameState:resetHighScores()

        for _, modeScores in pairs(stub.datastore.highscores) do
            for _, value in pairs(modeScores) do
                assert.is_true(value < math.huge)
            end
        end
    end)
end)
