-- SuitIcons.lua
-- Extracts and provides suit symbols from the card sprite sheet

local gfx <const> = playdate.graphics

local SuitIcons = {}

-- Card sprite sheet dimensions
local CARD_WIDTH = 32
local CARD_HEIGHT = 32

-- Initialize suit icons from the card sprite sheet
function SuitIcons:init(cardSpriteSheet)
    self.icons = {}

    -- Extract suit symbols from ace cards (they have the clearest single suit symbol)
    -- The aces are at specific positions in the sprite sheet:
    -- A♠ is at position 7 (row 2, col 1)
    -- A♦ is at position 20 (row 3, col 1)
    -- A♣ is at position 33 (row 4, col 1)
    -- A♥ is at position 46 (row 5, col 1)

    local positions = {
        S = {row = 2, col = 1},  -- Ace of Spades
        D = {row = 3, col = 1},  -- Ace of Diamonds
        C = {row = 4, col = 1},  -- Ace of Clubs
        H = {row = 5, col = 1},  -- Ace of Hearts
    }

    for suit, pos in pairs(positions) do
        -- Extract a small region from the center of each ace card where the suit symbol is
        local x = (pos.col - 1) * CARD_WIDTH + 12  -- Center region
        local y = (pos.row - 1) * CARD_HEIGHT + 12
        local width = 8
        local height = 8

        -- Create a new image for this suit icon
        local iconImage = gfx.image.new(width, height)
        gfx.pushContext(iconImage)
        cardSpriteSheet:draw(-x, -y)
        gfx.popContext()

        self.icons[suit] = iconImage
    end

    return self
end

-- Draw a suit icon at the specified position
function SuitIcons:drawSuit(suit, x, y, scale)
    scale = scale or 1
    local icon = self.icons[suit]
    if icon then
        if scale == 1 then
            icon:draw(x, y)
        else
            icon:drawScaled(x, y, scale)
        end
    else
        -- Fallback to text if icon not available
        gfx.drawText(suit, x, y)
    end
end

-- Get the width of a suit icon
function SuitIcons:getWidth()
    return 8
end

-- Get the height of a suit icon
function SuitIcons:getHeight()
    return 8
end

return SuitIcons
