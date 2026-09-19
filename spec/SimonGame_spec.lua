require("spec.support.playdate_stub")
import "SimonGame"

describe("SimonGame", function()
    -- Positions come out in this order, and every question asks for the card
    local function scriptedGame(positions, bestRounds)
        local nextPosition = 0
        return SimonGame:new({
            bestRounds = bestRounds or 0,
            randomPosition = function()
                nextPosition = nextPosition + 1
                return positions[nextPosition]
            end,
            randomInputKind = function() return SimonGame.INPUT_KINDS.CARD end,
        })
    end

    local function watchSequence(game)
        while game.phase == SimonGame.PHASES.SHOWING do game:showNext() end
        game:beginInput()
    end

    local function answerCorrectly(game)
        game:submit(game:correctAnswer())
        game:continue()
    end

    it("starts by showing a one-card sequence", function()
        local game = scriptedGame({ 7 })

        assert.are.equal(SimonGame.PHASES.SHOWING, game.phase)
        assert.are.equal(1, game.round)
        assert.are.same({ 7 }, game.sequence)
        assert.are.equal(7, game:shownPosition())
    end)

    it("shows every card of the sequence before asking for any", function()
        local game = scriptedGame({ 7, 20 })
        watchSequence(game)
        answerCorrectly(game)

        assert.are.equal(SimonGame.PHASES.SHOWING, game.phase)
        assert.are.equal(7, game:shownPosition())
        game:showNext()
        assert.are.equal(20, game:shownPosition())
        game:showNext()
        assert.are.equal(SimonGame.PHASES.WAITING, game.phase)
    end)

    it("keeps earlier positions and adds one each round", function()
        local game = scriptedGame({ 7, 20, 33 })
        watchSequence(game)
        answerCorrectly(game)
        watchSequence(game)
        answerCorrectly(game)
        answerCorrectly(game)

        assert.are.equal(3, game.round)
        assert.are.same({ 7, 20, 33 }, game.sequence)
    end)

    it("asks for the second card after the first is answered correctly", function()
        local game = scriptedGame({ 7, 20 })
        watchSequence(game)
        answerCorrectly(game)
        watchSequence(game)

        game:submit("AS")
        assert.is_true(game.lastAnswerCorrect)
        assert.is_false(game:isRoundComplete())
        game:continue()

        assert.are.equal(SimonGame.PHASES.INPUT, game.phase)
        assert.are.equal(2, game.round)
        assert.are.equal(2, game.answerIndex)
        assert.are.equal("JH", game:correctAnswer())
    end)

    it("finishes the round only when the last card is answered", function()
        local game = scriptedGame({ 7, 20, 33 })
        watchSequence(game)
        answerCorrectly(game)
        watchSequence(game)
        answerCorrectly(game)

        game:submit("JH")
        assert.is_true(game:isRoundComplete())
        game:continue()

        assert.are.equal(3, game.round)
        assert.are.equal(SimonGame.PHASES.SHOWING, game.phase)
    end)

    it("counts a new question each time, so the screen can start it from a clean dial", function()
        local game = scriptedGame({ 7, 20 })
        watchSequence(game)
        local firstQuestion = game.questionNumber
        answerCorrectly(game)
        watchSequence(game)
        local secondQuestion = game.questionNumber
        answerCorrectly(game)

        assert.is_true(secondQuestion > firstQuestion)
        assert.is_true(game.questionNumber > secondQuestion)
    end)

    it("accepts a position when the question asks for one", function()
        local game = SimonGame:new({
            bestRounds = 0,
            randomPosition = function() return 7 end,
            randomInputKind = function() return SimonGame.INPUT_KINDS.POSITION end,
        })
        watchSequence(game)

        assert.are.equal(7, game:correctAnswer())
        game:submit(7)
        assert.is_true(game.lastAnswerCorrect)
    end)

    it("ends on a wrong answer, scoring only the rounds finished", function()
        local game = scriptedGame({ 7, 20 }, 0)
        watchSequence(game)
        answerCorrectly(game)
        watchSequence(game)

        game:submit("2C")

        assert.is_false(game.lastAnswerCorrect)
        assert.is_true(game.isOver)
        assert.are.equal(1, game:completedRounds())
        assert.is_true(game.isNewBest)
        assert.are.equal(1, game.bestRounds)
    end)

    it("does not claim a new best for matching the record", function()
        local game = scriptedGame({ 7, 20 }, 1)
        watchSequence(game)
        answerCorrectly(game)
        watchSequence(game)

        game:submit("2C")

        assert.is_false(game.isNewBest)
        assert.are.equal(1, game.bestRounds)
    end)
end)
