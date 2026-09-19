-- Card images and sound effects shared by every scene.

import "CoreLibs/graphics"
import "App"
import "Deck"

local gfx <const> = playdate.graphics
local snd <const> = playdate.sound

Assets = {}

Assets.CARD_WIDTH = 50
Assets.CARD_HEIGHT = 70

local cardSpriteSheet = gfx.image.new("images/cards")
assert(cardSpriteSheet, "Failed to load card sprite sheet")

Assets.cardImages = {}
for row = 1, Deck.SPRITE_ROWS do
    for column = 1, Deck.SPRITE_COLUMNS do
        local cardImage = gfx.image.new(Assets.CARD_WIDTH, Assets.CARD_HEIGHT)
        gfx.pushContext(cardImage)
        cardSpriteSheet:draw(-(column - 1) * Assets.CARD_WIDTH, -(row - 1) * Assets.CARD_HEIGHT)
        gfx.popContext()
        Assets.cardImages[(row - 1) * Deck.SPRITE_COLUMNS + column] = cardImage
    end
end

-- Scaling is expensive, so scaled cards are cached. The cache is capped to bound memory.
local scaledCardCache = {}
local maxCacheSize = 20

local function getCachedScaledCard(cardIndex, scale)
    -- Round scale to nearest 0.2 to further limit cache size
    local roundedScale = math.floor(scale * 5 + 0.5) / 5
    local cacheKey = cardIndex .. "_" .. roundedScale

    if scaledCardCache[cacheKey] then
        return scaledCardCache[cacheKey]
    end

    local cacheCount = 0
    for _ in pairs(scaledCardCache) do
        cacheCount = cacheCount + 1
    end

    if cacheCount >= maxCacheSize then
        -- Not true LRU: evicts whichever entry the table yields first
        scaledCardCache[next(scaledCardCache)] = nil
    end

    scaledCardCache[cacheKey] = Assets.cardImages[cardIndex]:scaledImage(roundedScale)
    return scaledCardCache[cacheKey]
end

function Assets.getCardImage(cardName)
    return Assets.cardImages[Deck.spriteIndex[cardName]]
end

-- Draw a card centered at a position
function Assets.drawCard(cardName, x, y, scale)
    if scale ~= 1 then
        getCachedScaledCard(Deck.spriteIndex[cardName], scale):drawCentered(x, y)
    else
        Assets.getCardImage(cardName):drawCentered(x, y)
    end
end

local function loadSound(name)
    local sound = snd.sampleplayer.new("sounds/" .. name)
    assert(sound, "Failed to load " .. name .. ".wav")
    return sound
end

Assets.sounds = {
    crankTick = loadSound("crank_tick"),
    buttonPress = loadSound("button_press"),
    menuMove = loadSound("menu_move"),
    correct = loadSound("correct"),
    incorrect = loadSound("incorrect"),
    sessionComplete = loadSound("session_complete"),
}

Assets.sounds.buttonPress:setVolume(0.3)

function Assets.playSound(sound)
    if App.gameState.soundEnabled then sound:play() end
end
