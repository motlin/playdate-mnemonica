-- Selection and crank state that leaks from one scene into the next: every dial scene reads and
-- writes the same selection, the dial renderers keep animating from wherever the previous scene
-- left them, and crank movement is measured from the last angle any scene saw.

import "Assets"
import "DialRenderer"
import "NumberDialRenderer"

SharedState = {
    selectedCard = 1,  -- Index into Deck.uspccOrder
    selectedNumber = 1,  -- Stack position (1-52)
    lastCrankPosition = 0,
    dialRenderer = DialRenderer:new(Assets.cardImages, Assets.CARD_WIDTH, Assets.CARD_HEIGHT),
    numberDialRenderer = NumberDialRenderer:new()
}
