require("spec.support.playdate_stub")
import "Deck"

describe("Deck", function()
    local function split(cards)
        local list = {}
        for card in cards:gmatch("%S+") do list[#list + 1] = card end
        return list
    end

    it("holds the Mnemonica stack in order", function()
        assert.are.same(split([[
            4C 2H 7D 3C 4H 6D AS 5H 9S 2S
            QH 3D QC 8H 6S 5S 9H KC 2D JH
            3S 8S 6H 10C 5D KD 2C 3H 8D 5C
            KS JD 8C 10S KH JC 7S 10H AD 4S
            7H 4D AC 9C JS QD 7C QS 10D 6C
            AH 9D
        ]]), Deck.mnemonicaStack)
    end)

    it("orders the dial like a new USPCC deck", function()
        assert.are.same(split([[
            AS 2S 3S 4S 5S 6S 7S 8S 9S 10S JS QS KS
            AD 2D 3D 4D 5D 6D 7D 8D 9D 10D JD QD KD
            KC QC JC 10C 9C 8C 7C 6C 5C 4C 3C 2C AC
            KH QH JH 10H 9H 8H 7H 6H 5H 4H 3H 2H AH
        ]]), Deck.uspccOrder)
    end)

    it("has every card exactly once in both orders", function()
        for _, order in ipairs({ Deck.mnemonicaStack, Deck.uspccOrder }) do
            local seen = {}
            for _, card in ipairs(order) do
                assert.is_nil(seen[card], card .. " appears twice")
                seen[card] = true
            end
            assert.are.equal(52, #order)
        end
    end)

    it("maps each card to its sprite, skipping the sheet's first row of jokers and backs", function()
        assert.are.equal(14, Deck.spriteIndex["AH"])
        assert.are.equal(26, Deck.spriteIndex["KH"])
        assert.are.equal(27, Deck.spriteIndex["AD"])
        assert.are.equal(40, Deck.spriteIndex["AS"])
        assert.are.equal(62, Deck.spriteIndex["10C"])
        assert.are.equal(65, Deck.spriteIndex["KC"])

        local seen = {}
        for _, card in ipairs(Deck.uspccOrder) do
            local index = Deck.spriteIndex[card]
            assert.is_nil(seen[index], card .. " shares a sprite")
            seen[index] = true
        end
    end)
end)
