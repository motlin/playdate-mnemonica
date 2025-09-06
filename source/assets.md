# Asset List for Mnemonica Stack Memorizer

## ✅ Acquired Assets

### Playing Cards

- **Location**: `source/images/cards.png`
- **Format**: 32x32 pixel sprites in a grid
- **Contents**: All 52 cards + 4 different card back designs
- **Layout**: 4 rows × 14 columns sprite sheet
- **Card Order**: A-K of each suit in rows (Spades, Diamonds, Clubs, Hearts)

### Sound Effects

All retro 8-bit style sounds generated and saved:

- **crank_tick.wav** - Short click for crank rotation
- **button_press.wav** - Confirmation beep
- **correct.wav** - Happy ascending tone
- **incorrect.wav** - Low error buzz
- **session_complete.wav** - Victory fanfare
- **menu_move.wav** - UI navigation blip
- **Location**: `source/sounds/`

### Icon Sheets (16x16 pixel icons)

Multiple icon sheets with useful UI elements:

#### Playing Card Icons (playing-cards-16px.png)

- **Contents**: Simplified card representations in 16x16
- **Useful for**: Compact card display in UI, progress indicators
- Card ranks (A, 2-10, J, Q, K) in minimalist style
- Suit symbols (♠♥♦♣)

#### UI Icons Part 1 (1-bit 16px icons part-1.png)

- **Contents**: 400+ general purpose icons
- **Useful elements**:
  - Checkmarks and X marks (for correct/incorrect)
  - Arrows (for navigation hints)
  - Stars (for achievements/high scores)
  - Clock/timer icons
  - Trophy icons (for completion)
  - Settings gear
  - Play/pause buttons
  - Home icon (for main menu)

#### UI Icons Part 2 (1bit 16px icons part-2.png)

- **Contents**: 400+ additional icons
- **Useful elements**:
  - Numbers and mathematical symbols
  - Heart icons (for lives/attempts)
  - Star ratings
  - Lock/unlock icons
  - Refresh/replay icons
  - Chart/statistics icons
  - Question mark (for help)

#### Patterns and Tiles (1bit 16px patterns and tiles.png)

- **Contents**: Decorative patterns and UI frames
- **Useful elements**:
  - Various border styles for dialogs/menus
  - "BONUS" text decoration
  - Rounded and square frames
  - Dotted and striped patterns for backgrounds
  - Progress bar components

## 📝 Assets To Acquire

### Fonts

For the dial display showing numbers 1-52 and card names (A♠, K♥, etc.):

- **Option 1**: Use Playdate's built-in font with `drawTextAligned()`
- **Option 2**: Create custom fixed-width font using Caps tool
- **Option 3**: Use a bitmap font generator for monospace numbers

**Recommendation**: Start with built-in fonts, upgrade to custom if needed.

### Sound Effects (Retro/8-bit style)

Essential sounds to create or find:

1. **crank_tick.wav** - Subtle click for each crank position
   - Very short (~50ms)
   - High-pitched tick or click

2. **button_press.wav** - Confirmation sound
   - Medium pitch beep
   - ~100ms duration

3. **correct.wav** - Positive feedback
   - Rising two-tone chime
   - Happy/upbeat sound

4. **incorrect.wav** - Negative feedback
   - Low buzz or thud
   - Descending tone

5. **session_complete.wav** - Victory fanfare
   - Multi-note ascending melody
   - 1-2 seconds long

6. **menu_move.wav** - UI navigation
   - Light blip or beep
   - Very short

**Best source**: https://sfxr.me/ - Generate custom retro sounds

### UI Elements

Since you're using `drawTextAligned()` for most UI, minimal graphics needed:

1. **Optional**: Progress dots or bar graphic
2. **Optional**: Timer/clock icon (can use text: "⏱")
3. **Optional**: Checkmark/X icons (can use text: "✓" "✗")

**Recommendation**: Start with text-only UI, add graphics if needed for polish.

## 🎮 Playdate Unicode Support

The Playdate SDK has limited Unicode support. For card suits:

- ♠ (Spades) - May need to use "S"
- ♥ (Hearts) - May need to use "H"
- ♦ (Diamonds) - May need to use "D"
- ♣ (Clubs) - May need to use "C"

Test Unicode first, fall back to letters if needed.

## 🛠 Asset Preparation

### Converting the card sprite sheet:

The Playdate uses "image tables" for sprite sheets. The cards.png will need to be:

1. Converted to Playdate's format (.pdt)
2. Split into individual 32x32 frames
3. Indexed properly for card lookups

### Sound format requirements:

- 16-bit WAV or AIFF
- 44.1kHz sample rate recommended
- Keep under 100KB per sound for efficiency
- Can use ADPCM compression if needed

## 📦 Current Asset Organization

```
source/
├── images/
│   └── cards.png (32x32 sprites, all 52 cards + backs)
├── sounds/
│   ├── crank_tick.wav
│   ├── button_press.wav
│   ├── correct.wav
│   ├── incorrect.wav
│   ├── session_complete.wav
│   └── menu_move.wav
└── icon-sheets/
    ├── playing-cards-16px.png (16x16 simplified playing cards)
    ├── 1-bit 16px icons part-1.png (400+ UI icons)
    ├── 1-bit 16px icons part-1 outlines.png
    ├── 1bit 16px icons part-2.png (400+ more icons)
    ├── 1bit 16px icons part-2 outlines.png
    ├── 1bit 16px patterns and tiles.png (borders, frames)
    └── 1bit 16px patterns and tiles - outlines.png
```

## 🎮 Key Assets for Implementation

### For the Rotating Dial UI:

- Use built-in text rendering for numbers 1-52
- playing-cards-16px.png has compact card representations perfect for the dial
- Arrow icons from part-1.png for crank direction indicators

### For Feedback:

- Checkmark/X icons from part-1.png for correct/incorrect
- All sound effects ready in source/sounds/

### For Menus and UI:

- Frame styles from patterns and tiles sheet
- Navigation arrows and home icon from part-1.png
- Settings gear for options menu

### For Progress/Stats:

- Progress bar components from patterns sheet
- Chart/statistics icons from part-2.png
- Trophy and star icons for achievements
