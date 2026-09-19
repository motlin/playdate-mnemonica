-- The three bands every screen is laid out in: a black title bar, the content, and a footer
-- of button hints. Nothing else draws in the title bar or footer, which keeps text from
-- colliding as screens change.

import "CoreLibs/graphics"
import "CoreLibs/ui"

local pd <const> = playdate
local gfx <const> = playdate.graphics

Layout = {}

Layout.SCREEN_WIDTH = 400
Layout.TITLE_HEIGHT = 24
Layout.FOOTER_TOP = 218
Layout.CONTENT_TOP = Layout.TITLE_HEIGHT
Layout.CONTENT_BOTTOM = Layout.FOOTER_TOP
Layout.CONTENT_CENTER_Y = (Layout.CONTENT_TOP + Layout.CONTENT_BOTTOM) // 2

Layout.boldFont = gfx.getSystemFont(gfx.font.kVariantBold)

local TITLE_TEXT_Y <const> = 3
local FOOTER_TEXT_Y <const> = 220
local SIDE_MARGIN <const> = 8
-- Every digit gets the width of the widest one so a running timer does not jitter
local DIGIT_ADVANCE <const> = 10
local COLON_ADVANCE <const> = 5
-- The crank indicator covers the bottom-right corner when the crank is docked
local CRANK_INDICATOR_WIDTH <const> = 92

local function drawFixedWidthRightAligned(text, rightX, y)
    local x = rightX
    for position = #text, 1, -1 do
        local character = text:sub(position, position)
        local advance = character == ":" and COLON_ADVANCE or DIGIT_ADVANCE
        x = x - advance
        gfx.drawTextAligned(character, x + advance / 2, y, kTextAlignment.center)
    end
end

local function drawTitleBarText(title, left, right)
    gfx.setFont(Layout.boldFont)
    gfx.drawTextAligned(title, Layout.SCREEN_WIDTH / 2, TITLE_TEXT_Y, kTextAlignment.center)
    gfx.setFont()
    if left then
        gfx.drawText(left, SIDE_MARGIN, TITLE_TEXT_Y)
    end
    if right and right:match("^%d+:%d%d$") then
        drawFixedWidthRightAligned(right, Layout.SCREEN_WIDTH - SIDE_MARGIN, TITLE_TEXT_Y)
    elseif right then
        gfx.drawTextAligned(right, Layout.SCREEN_WIDTH - SIDE_MARGIN, TITLE_TEXT_Y, kTextAlignment.right)
    end
end

-- `left` and `right` are optional short status texts. A `right` that looks like a timer is
-- drawn fixed-width so it does not jitter as it counts.
function Layout.drawTitleBar(title, left, right)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, Layout.SCREEN_WIDTH, Layout.TITLE_HEIGHT)

    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    drawTitleBarText(title, left, right)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

-- The title bar for bad news: black on white with a heavy rule, so a wrong answer looks
-- different from a right one before any text is read.
function Layout.drawOutlinedTitleBar(title, left, right)
    drawTitleBarText(title, left, right)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, Layout.TITLE_HEIGHT - 3, Layout.SCREEN_WIDTH, 3)
end

-- "Position 31" over its card at double size: the fact every screen is teaching.
function Layout.drawPositionWithCard(position, cardName, x, drawCard)
    gfx.setFont(Layout.boldFont)
    gfx.drawTextAligned("Position " .. position, x, Layout.CONTENT_TOP + 6, kTextAlignment.center)
    gfx.setFont()
    drawCard(cardName, x, Layout.CONTENT_TOP + 28 + 70, 2)
end

local BUTTON_RADIUS <const> = 8
local BUTTON_LABEL_GAP <const> = 4
local HINT_GAP <const> = 16

local function hintWidth(hint)
    return BUTTON_RADIUS * 2 + BUTTON_LABEL_GAP + gfx.getSystemFont():getTextWidth(hint.label)
end

-- A filled circle with the button's letter, like the buttons on the device
local function drawHint(hint, x)
    local centerY = FOOTER_TEXT_Y + 8
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(x + BUTTON_RADIUS, centerY, BUTTON_RADIUS)

    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.setFont(Layout.boldFont)
    gfx.drawTextAligned(hint.button, x + BUTTON_RADIUS, centerY - Layout.boldFont:getHeight() / 2 + 1, kTextAlignment.center)
    gfx.setFont()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)

    gfx.drawText(hint.label, x + BUTTON_RADIUS * 2 + BUTTON_LABEL_GAP, FOOTER_TEXT_Y)
end

-- Button hints, e.g. { { button = "A", label = "Confirm" }, { button = "B", label = "Menu" } }.
-- With `usesCrank`, a docked crank shows the system indicator and the hints move left to stay
-- clear of it.
function Layout.drawFooter(hints, usesCrank)
    local availableWidth = Layout.SCREEN_WIDTH
    if usesCrank and pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
        availableWidth = availableWidth - CRANK_INDICATOR_WIDTH
    end

    local totalWidth = HINT_GAP * (#hints - 1)
    for _, hint in ipairs(hints) do
        totalWidth = totalWidth + hintWidth(hint)
    end

    local x = (availableWidth - totalWidth) // 2
    for _, hint in ipairs(hints) do
        drawHint(hint, x)
        x = x + hintWidth(hint) + HINT_GAP
    end
end

local doubleSizeNumbers = {}

local function getDoubleSizeNumber(number)
    if not doubleSizeNumbers[number] then
        local text = tostring(number)
        local image = gfx.image.new(Layout.boldFont:getTextWidth(text), Layout.boldFont:getHeight())
        gfx.pushContext(image)
        -- The cached image must be black whatever draw mode the first caller happens to be in
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        gfx.setFont(Layout.boldFont)
        gfx.drawText(text, 0, 0)
        gfx.popContext()
        doubleSizeNumbers[number] = image:scaledImage(2)
    end
    return doubleSizeNumbers[number]
end

-- A number in double-size bold, centred at x, y. Honours the current image draw mode.
function Layout.drawLargeNumber(number, x, y)
    getDoubleSizeNumber(number):drawCentered(x, y)
end
