require("spec.support.playdate_stub")
import "CarouselLayout"

describe("CarouselLayout", function()
    local function byIndex(items)
        local found = {}
        for _, item in ipairs(items) do found[item.index] = item end
        return found
    end

    it("centres the selection at double size with two single-size neighbours each side", function()
        local items = byIndex(CarouselLayout.visibleItems(10, 52, 200, 200))

        assert.are.same({ index = 10, x = 200, scale = 2 }, items[10])
        assert.are.same({ index = 9, x = 109, scale = 1 }, items[9])
        assert.are.same({ index = 11, x = 291, scale = 1 }, items[11])
        assert.are.same({ index = 8, x = 41, scale = 1 }, items[8])
        assert.are.same({ index = 12, x = 359, scale = 1 }, items[12])
    end)

    it("never lets single-size neighbours touch the double-size selection", function()
        local halfSelected, halfNeighbour = 50, 25
        local items = byIndex(CarouselLayout.visibleItems(10, 52, 200, 200))

        assert.are.equal(16, (items[11].x - halfNeighbour) - (items[10].x + halfSelected))
        assert.are.equal(18, (items[12].x - halfNeighbour) - (items[11].x + halfNeighbour))
    end)

    it("keeps the third neighbour entirely off a 400px screen at rest", function()
        local items = byIndex(CarouselLayout.visibleItems(10, 52, 200, 250))
        assert.is_true(items[13].x - 25 >= 400)
        assert.is_true(items[7].x + 25 <= 0)
    end)

    it("wraps around both ends of the list", function()
        local atStart = byIndex(CarouselLayout.visibleItems(1, 52, 200, 200))
        assert.are.equal(109, atStart[52].x)
        assert.are.equal(41, atStart[51].x)

        local atEnd = byIndex(CarouselLayout.visibleItems(52, 52, 200, 200))
        assert.are.equal(291, atEnd[1].x)
    end)

    it("keeps items on screen while scrolling between two selections", function()
        for step = 0, 10 do
            local items = CarouselLayout.visibleItems(10 + step / 10, 52, 200, 200)
            assert.is_true(#items >= 5, "only " .. #items .. " items at step " .. step)

            local doubleSized = 0
            for _, item in ipairs(items) do
                if item.scale == 2 then doubleSized = doubleSized + 1 end
            end
            assert.are.equal(1, doubleSized)
        end
    end)

    it("shows fewer neighbours when given a narrower area off-centre", function()
        local items = byIndex(CarouselLayout.visibleItems(10, 52, 270, 130))

        assert.are.equal(270, items[10].x)
        assert.are.equal(179, items[9].x)
        assert.are.equal(361, items[11].x)
        assert.is_nil(items[8])
        assert.is_nil(items[12])
    end)

    it("draws the double-size selection last so it sits on top", function()
        local items = CarouselLayout.visibleItems(10.4, 52, 200, 200)
        assert.are.equal(2, items[#items].scale)
    end)

    it("scrolls the short way round the wrap", function()
        assert.are.equal(52.5, CarouselLayout.approach(52, 1, 0.5, 52, 200, 200))
        assert.are.equal(0.5, CarouselLayout.approach(1, 52, 0.5, 52, 200, 200))
        assert.are.equal(12, CarouselLayout.approach(10, 14, 0.5, 52, 200, 200))
    end)

    it("lands exactly on the selection once it is close", function()
        assert.are.equal(14, CarouselLayout.approach(13.99, 14, 0.5, 52, 200, 200))
    end)
end)
