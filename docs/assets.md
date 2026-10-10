# Assets

## Playing cards

- `source/images/cards.png`, from the free deck shared on the [Playdate developer forum](https://devforum.play.date/t/playing-card-deck-imagetable-free-for-your-card-game/994).
- A 650×350 sheet of 50×70 sprites, 5 rows × 13 columns:
    - Row 1: blank card, joker, and card backs (unused)
    - Row 2: A-K of hearts
    - Row 3: A-K of diamonds
    - Row 4: A-K of spades
    - Row 5: A-K of clubs
- `source/Deck.lua` maps card names to sprites; `source/Assets.lua` slices the sheet.
- Cards are only ever drawn at 1× or 2×. The 1-bit art turns to mush at any other scale.

## Sounds

Retro 8-bit effects in `source/sounds/`:

- `crank_tick.wav`: the selection moved
- `menu_move.wav`: a menu row changed
- `button_press.wav`: A or B pressed (played at 30% volume)
- `correct.wav` and `incorrect.wav`: answer feedback
- `session_complete.wav`: a quiz finished

## Fonts

The Playdate system font only: regular for body text, bold for titles, and bold scaled 2× for large numbers (`Layout.drawLargeText`). It has no suit symbols and no Ⓐ/Ⓑ glyphs, so cards are named like `10C` and the button hints are drawn by `Layout.drawFooter`.

## Launcher

`source/launcher/` holds the launcher card (350×155), its highlighted animation, and the list icon (32×32). They are generated from the game's own font and card art, not drawn by hand:

```sh
tools/screenshots/run.sh launcher_art builds/launcher
```

then copy `card.png`, `card-highlighted.png`, and `icon.png` into `source/launcher/`.
