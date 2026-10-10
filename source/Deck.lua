-- Card data: the memorized stack, the order the answer dial scrolls through, and where each
-- card sits in the sprite sheet. Cards are named rank then suit, e.g. "10C".

Deck = {}

-- Mnemonica stack order (positions 1-52)
Deck.mnemonicaStack = {
    "4C",
    "2H",
    "7D",
    "3C",
    "4H",
    "6D",
    "AS",
    "5H",
    "9S",
    "2S",
    "QH",
    "3D",
    "QC",
    "8H",
    "6S",
    "5S",
    "9H",
    "KC",
    "2D",
    "JH",
    "3S",
    "8S",
    "6H",
    "10C",
    "5D",
    "KD",
    "2C",
    "3H",
    "8D",
    "5C",
    "KS",
    "JD",
    "8C",
    "10S",
    "KH",
    "JC",
    "7S",
    "10H",
    "AD",
    "4S",
    "7H",
    "4D",
    "AC",
    "9C",
    "JS",
    "QD",
    "7C",
    "QS",
    "10D",
    "6C",
    "AH",
    "9D",
}

-- USPCC new deck order for crank selection
Deck.uspccOrder = {
    -- A through K of Spades (positions 1-13)
    "AS",
    "2S",
    "3S",
    "4S",
    "5S",
    "6S",
    "7S",
    "8S",
    "9S",
    "10S",
    "JS",
    "QS",
    "KS",
    -- A through K of Diamonds (positions 14-26)
    "AD",
    "2D",
    "3D",
    "4D",
    "5D",
    "6D",
    "7D",
    "8D",
    "9D",
    "10D",
    "JD",
    "QD",
    "KD",
    -- K through A of Clubs (positions 27-39, reversed)
    "KC",
    "QC",
    "JC",
    "10C",
    "9C",
    "8C",
    "7C",
    "6C",
    "5C",
    "4C",
    "3C",
    "2C",
    "AC",
    -- K through A of Hearts (positions 40-52, reversed)
    "KH",
    "QH",
    "JH",
    "10H",
    "9H",
    "8H",
    "7H",
    "6H",
    "5H",
    "4H",
    "3H",
    "2H",
    "AH",
}

-- The sprite sheet has 13 columns. Row 1 holds the blank, jokers and card backs; rows 2-5 hold
-- A-K of hearts, diamonds, spades and clubs.
Deck.SPRITE_COLUMNS = 13
Deck.SPRITE_ROWS = 5

Deck.spriteIndex = {}
local ranks = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }
for suitRow, suit in ipairs({ "H", "D", "S", "C" }) do
    for column, rank in ipairs(ranks) do
        Deck.spriteIndex[rank .. suit] = suitRow * Deck.SPRITE_COLUMNS + column
    end
end
