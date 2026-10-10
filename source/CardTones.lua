-- The sound of a card in Simon mode: a tone for its suit, then a note for its rank.
-- Ranks climb the thirteen semitones from middle C (ace) to the C above (king).
-- Suits use the four tones of the original Simon game, lowest for spades and rising through
-- diamonds, clubs, and hearts in new-deck order.

CardTones = {}

local MIDDLE_C <const> = 60

local RANK_STEPS <const> = {
    A = 0,
    ["2"] = 1,
    ["3"] = 2,
    ["4"] = 3,
    ["5"] = 4,
    ["6"] = 5,
    ["7"] = 6,
    ["8"] = 7,
    ["9"] = 8,
    ["10"] = 9,
    J = 10,
    Q = 11,
    K = 12,
}

local SUIT_FREQUENCIES <const> = {
    S = 207.652,
    D = 247.942,
    C = 311.127,
    H = 415.305,
}

-- Card names are a rank followed by one suit letter, like "10C" or "AS".
function CardTones.rankMidiNote(cardName) return MIDDLE_C + RANK_STEPS[cardName:sub(1, -2)] end

function CardTones.suitFrequency(cardName) return SUIT_FREQUENCIES[cardName:sub(-1)] end
