require("spec.support.playdate_stub")
import "CrankSelector"

describe("CrankSelector", function()
    local DEGREES_PER_CARD <const> = 360 / 52

    it("starts on the first item", function()
        assert.are.equal(1, CrankSelector:new(52, DEGREES_PER_CARD).index)
    end)

    it("visits every item once per full rotation and ends where it started", function()
        local selector = CrankSelector:new(52, DEGREES_PER_CARD)
        local visited = {}

        for _ = 1, 720 do
            selector:turn(0.5, 1.0)
            visited[selector.index] = true
        end

        for index = 1, 52 do assert.is_true(visited[index], "never reached " .. index) end
        assert.are.equal(1, selector.index)
    end)

    it("reaches every item at any sensitivity, with no dead zone", function()
        for _, sensitivity in ipairs({ 0.1, 0.5, 3.0 }) do
            local selector = CrankSelector:new(52, DEGREES_PER_CARD)
            local visited = {}
            for _ = 1, 52 do
                selector:turn(DEGREES_PER_CARD / sensitivity, sensitivity)
                visited[selector.index] = true
            end
            for index = 1, 52 do
                assert.is_true(visited[index], "sensitivity " .. sensitivity .. " never reached " .. index)
            end
        end
    end)

    it("wraps backwards from the first item to the last", function()
        local selector = CrankSelector:new(52, DEGREES_PER_CARD)

        selector:turn(-DEGREES_PER_CARD, 1.0)

        assert.are.equal(52, selector.index)
    end)

    it("reports how many items a turn moved, for tick sounds", function()
        local selector = CrankSelector:new(52, DEGREES_PER_CARD)

        assert.are.equal(0, selector:turn(DEGREES_PER_CARD * 0.4, 1.0))
        assert.are.equal(3, selector:turn(DEGREES_PER_CARD * 2.6, 1.0))
        assert.are.equal(-2, selector:turn(-DEGREES_PER_CARD * 2, 1.0))
    end)

    it("does not flicker when the crank jitters around the point where it just moved", function()
        local selector = CrankSelector:new(52, DEGREES_PER_CARD)
        selector:turn(DEGREES_PER_CARD, 1.0)
        assert.are.equal(2, selector.index)

        for _ = 1, 20 do
            selector:turn(-1, 1.0)
            assert.are.equal(2, selector.index)
            selector:turn(1, 1.0)
            assert.are.equal(2, selector.index)
        end
    end)

    it("steps by whole items for the D-pad, wrapping in both directions", function()
        local selector = CrankSelector:new(52, DEGREES_PER_CARD)

        selector:step(-13)
        assert.are.equal(40, selector.index)

        selector:step(13)
        selector:step(52 + 5)
        assert.are.equal(6, selector.index)
    end)

    it("forgets partial crank travel when the D-pad moves the selection", function()
        local selector = CrankSelector:new(52, DEGREES_PER_CARD)
        selector:turn(DEGREES_PER_CARD * 0.9, 1.0)

        selector:step(1)
        selector:turn(DEGREES_PER_CARD * 0.2, 1.0)

        assert.are.equal(2, selector.index)
    end)
end)
