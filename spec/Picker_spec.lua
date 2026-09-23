require("spec.support.playdate_stub")
import "Picker"

describe("Picker", function()
    local DEGREES_PER_CARD <const> = 360 / 52
    local QUIZ_STEPS <const> = { up = -1, down = 1, left = -13, right = 13 }
    local crankChange, pressedButton, ticks

    before_each(function()
        crankChange, pressedButton, ticks = 0, nil, 0
        playdate.kButtonUp, playdate.kButtonDown = "up", "down"
        playdate.kButtonLeft, playdate.kButtonRight = "left", "right"
        -- Like the device: reports travel since the previous call
        playdate.getCrankChange = function()
            local change = crankChange
            crankChange = 0
            return change
        end
        playdate.buttonJustPressed = function(button) return button == pressedButton end
    end)

    local function newPicker()
        return Picker:new(52, QUIZ_STEPS, function() ticks = ticks + 1 end, 1)
    end

    it("moves with the crank and ticks once per frame that changes the selection", function()
        local picker = newPicker()

        crankChange = DEGREES_PER_CARD * 3
        picker:update(1.0)

        assert.are.equal(4, picker:getSelection())
        assert.are.equal(1, ticks)
    end)

    it("stays put and silent when nothing moves", function()
        local picker = newPicker()

        picker:update(1.0)

        assert.are.equal(1, picker:getSelection())
        assert.are.equal(0, ticks)
    end)

    it("jumps by the configured step for each D-pad direction", function()
        local picker = newPicker()

        pressedButton = "right"
        picker:update(1.0)
        assert.are.equal(14, picker:getSelection())

        pressedButton = "up"
        picker:update(1.0)
        assert.are.equal(13, picker:getSelection())
        assert.are.equal(2, ticks)
    end)

    it("ignores crank travel that built up before it was created", function()
        crankChange = 200
        local picker = newPicker()

        picker:update(1.0)

        assert.are.equal(1, picker:getSelection())
    end)

    it("takes the given number of crank turns to go once through the list", function()
        local picker = Picker:new(52, QUIZ_STEPS, function() end, 2)

        crankChange = 360
        picker:update(1.0)
        assert.are.equal(27, picker:getSelection())

        crankChange = 360
        picker:update(1.0)
        assert.are.equal(1, picker:getSelection())
    end)
end)
