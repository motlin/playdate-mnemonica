-- ===== INPUT DEBUG OVERLAY (appended to a build copy of main.lua; never shipped) =====
-- Shows what the hardware reports, on top of the running game: how many presses of each
-- button the game has seen, crank travel, and the selected menu row. It wraps the input
-- functions instead of calling them itself, so the game still receives every event.
do
    local realUpdate = playdate.update
    local realJustPressed = pd.buttonJustPressed
    local realCrankChange = pd.getCrankChange

    local buttons = { pd.kButtonUp, pd.kButtonDown, pd.kButtonLeft, pd.kButtonRight, pd.kButtonA, pd.kButtonB }
    local pressCounts, countedThisFrame = {}, {}
    for _, button in ipairs(buttons) do
        pressCounts[button] = 0
    end

    local crankTotal, crankLast = 0, 0
    local rowChanges, lastRow = 0, nil

    pd.buttonJustPressed = function(button)
        local pressed = realJustPressed(button)
        if pressed and not countedThisFrame[button] then
            countedThisFrame[button] = true
            pressCounts[button] = pressCounts[button] + 1
        end
        return pressed
    end

    pd.getCrankChange = function()
        local change, accelerated = realCrankChange()
        crankLast = change
        crankTotal = crankTotal + change
        return change, accelerated
    end

    function playdate.update()
        countedThisFrame = {}
        realUpdate()

        if MenuScene.selection ~= lastRow then
            if lastRow then rowChanges = rowChanges + 1 end
            lastRow = MenuScene.selection
        end

        -- A narrow column in the left margin, clear of the menu rows
        local lines = {
            "U" .. pressCounts[pd.kButtonUp] .. " D" .. pressCounts[pd.kButtonDown],
            "L" .. pressCounts[pd.kButtonLeft] .. " R" .. pressCounts[pd.kButtonRight],
            "A" .. pressCounts[pd.kButtonA] .. " B" .. pressCounts[pd.kButtonB],
            "row " .. tostring(MenuScene.selection),
            "moves " .. rowChanges,
            string.format("c %+.1f", crankTotal),
            string.format("l %+.2f", crankLast),
            "held " .. pd.getButtonState(),
        }

        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 26, 90, 8 + #lines * 20)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(0, 26, 90, 8 + #lines * 20)
        for line, text in ipairs(lines) do
            gfx.drawText(text, 4, 30 + (line - 1) * 20)
        end
    end
end
