-- Card images and sound effects shared by every scene.

import "CoreLibs/graphics"
import "App"
import "CardTones"
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

    if scaledCardCache[cacheKey] then return scaledCardCache[cacheKey] end

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

function Assets.getCardImage(cardName) return Assets.cardImages[Deck.spriteIndex[cardName]] end

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

-- A square wave for the suit and a softer triangle for the rank keep the two easy to tell apart
local suitSynth = snd.synth.new(snd.kWaveSquare)
local rankSynth = snd.synth.new(snd.kWaveTriangle)
suitSynth:setADSR(0.005, 0.04, 0.7, 0.04)
rankSynth:setADSR(0.005, 0.08, 0.6, 0.12)

local SUIT_TONE_SECONDS <const> = 0.16
local RANK_NOTE_SECONDS <const> = 0.32
local SUIT_TONE_VOLUME <const> = 0.25
local RANK_NOTE_VOLUME <const> = 0.6

-- A card's two-note motif: its suit tone, then its rank note.
function Assets.playCardTones(cardName)
    if not App.gameState.soundEnabled then return end

    local now = snd.getCurrentTime()
    suitSynth:playNote(CardTones.suitFrequency(cardName), SUIT_TONE_VOLUME, SUIT_TONE_SECONDS, now)
    rankSynth:playMIDINote(
        CardTones.rankMidiNote(cardName),
        RANK_NOTE_VOLUME,
        RANK_NOTE_SECONDS,
        now + SUIT_TONE_SECONDS + 0.02
    )
end
