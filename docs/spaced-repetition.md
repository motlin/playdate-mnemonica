# Spaced Repetition Algorithm

## Overview

The Mnemonica Playdate game uses a spaced repetition algorithm to help users learn more efficiently by prioritizing cards they struggle with.

## How it Works

### Card Statistics Tracking

Each card/position pair tracks:

- `timesAsked`: Total times the question was asked
- `timesCorrect`: Times answered correctly
- `timesIncorrect`: Times answered incorrectly
- `lastAsked`: Timestamp of last time asked
- `streak`: Current consecutive correct answers
- `difficulty`: Dynamic difficulty weight (0.1 to 10.0)

### Difficulty Adjustment

- **Correct answer**: Difficulty multiplied by 0.9 (gets easier)
- **Incorrect answer**: Difficulty multiplied by 1.5 (gets harder)
- Difficulty clamped between 0.1 (easiest) and 10.0 (hardest)

### Question Ordering Algorithm

1. **Activation Threshold**: Needs at least 52 questions answered (one full deck) before activating

2. **Weight Calculation**:
   - Base weight = card's difficulty score
   - Time bonus: If not seen in >5 minutes, weight increases by up to 50%
   - Success rate penalty:
     - <50% success rate: weight × 2
     - <70% success rate: weight × 1.5

3. **Question Distribution**:
   - 70% of questions selected from high-difficulty cards
   - 30% randomly distributed for variety
   - Top 10 most difficult cards prioritized
   - Light final shuffle within first 20 positions

### Visual Indicator

When spaced repetition is active, "[Smart Mode]" appears below the progress indicator during quizzes.

## Benefits

- Focuses practice on challenging cards
- Gradually reduces time spent on mastered cards
- Maintains some randomness to prevent predictability
- Automatically adapts to user's learning progress

## Data Persistence

All card statistics are automatically saved after each answer and persist between sessions.
