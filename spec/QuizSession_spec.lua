local stub = require("spec.support.playdate_stub")
local QuizSession = require("QuizSession")

describe("QuizSession", function()
    before_each(function() stub.reset() end)

    it("asks every position exactly once when shuffled", function()
        local positions = {}
        for position = 1, 52 do positions[position] = position end

        local session = QuizSession:new("quiz_number_to_card", 52)
        session:initializeQuestions(positions, true)

        local seen = {}
        for _, question in ipairs(session.questions) do
            seen[question.position] = (seen[question.position] or 0) + 1
        end
        for position = 1, 52 do
            assert.are.equal(1, seen[position])
        end
    end)
end)
