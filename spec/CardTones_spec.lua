require("spec.support.playdate_stub")
import "CardTones"

describe("CardTones", function()
    local MIDDLE_C <const> = 60

    it("gives the thirteen ranks the thirteen semitones from middle C up to the next C", function()
        local ranks = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }
        for step, rank in ipairs(ranks) do
            assert.are.equal(MIDDLE_C + step - 1, CardTones.rankMidiNote(rank .. "S"))
        end
        assert.are.equal(72, CardTones.rankMidiNote("KH"))
    end)

    it(
        "reads the rank of a ten, which is two characters",
        function() assert.are.equal(MIDDLE_C + 9, CardTones.rankMidiNote("10D")) end
    )

    it("gives the four suits the four tones of the original Simon", function()
        local tones = {
            CardTones.suitFrequency("AS"),
            CardTones.suitFrequency("AD"),
            CardTones.suitFrequency("AC"),
            CardTones.suitFrequency("AH"),
        }
        table.sort(tones)
        assert.are.same({ 207.652, 247.942, 311.127, 415.305 }, tones)
    end)

    it(
        "uses the same suit tone whatever the rank",
        function() assert.are.equal(CardTones.suitFrequency("2C"), CardTones.suitFrequency("10C")) end
    )
end)
