-- Rules of Simon mode: watch a sequence of stack positions that grows by one each round, then
-- answer every card of it in order. One wrong answer ends the game.

import "Deck"

SimonGame = {}
SimonGame.__index = SimonGame

SimonGame.PHASES = {
    SHOWING = "showing", -- the sequence is being shown, one card at a time
    WAITING = "waiting", -- the sequence has been shown; waiting for the player to begin
    INPUT = "input", -- the player is answering a card of the sequence
    FEEDBACK = "feedback", -- the answer just given is being shown as right or wrong
}

SimonGame.INPUT_KINDS = {
    CARD = "card", -- given the position, answer with the card
    POSITION = "position", -- given the card, answer with the position
}

-- options: bestRounds (the record to beat), randomPosition() and randomInputKind()
function SimonGame:new(options)
    local game = setmetatable({}, self)
    game.bestRounds = options.bestRounds
    game.randomPosition = options.randomPosition
    game.randomInputKind = options.randomInputKind

    game.sequence = {}
    game.round = 0
    game.questionNumber = 0
    game.isOver = false
    game.isNewBest = false
    game:startRound()
    return game
end

function SimonGame:startRound()
    self.round = self.round + 1
    self.sequence[self.round] = self.randomPosition()
    self.phase = SimonGame.PHASES.SHOWING
    self.showIndex = 1
end

-- The position on screen while the sequence is being shown.
function SimonGame:shownPosition() return self.sequence[self.showIndex] end

function SimonGame:showNext()
    self.showIndex = self.showIndex + 1
    if self.showIndex > self.round then self.phase = SimonGame.PHASES.WAITING end
end

function SimonGame:askQuestion(answerIndex)
    self.answerIndex = answerIndex
    self.inputKind = self.randomInputKind()
    -- Changes with every question so the screen knows to start from a clean dial
    self.questionNumber = self.questionNumber + 1
    self.phase = SimonGame.PHASES.INPUT
end

function SimonGame:beginInput() self:askQuestion(1) end

function SimonGame:askedPosition() return self.sequence[self.answerIndex] end

-- A card name or a position, depending on what the question asks for.
function SimonGame:correctAnswer()
    if self.inputKind == SimonGame.INPUT_KINDS.CARD then return Deck.mnemonicaStack[self:askedPosition()] end
    return self:askedPosition()
end

function SimonGame:isRoundComplete() return self.lastAnswerCorrect and self.answerIndex == self.round end

-- Rounds answered in full; the round that ended the game does not count.
function SimonGame:completedRounds() return self:isRoundComplete() and self.round or self.round - 1 end

function SimonGame:submit(answer)
    self.lastAnswerCorrect = answer == self:correctAnswer()
    self.phase = SimonGame.PHASES.FEEDBACK

    if not self.lastAnswerCorrect then
        self.isOver = true
        self.isNewBest = self:completedRounds() > self.bestRounds
        if self.isNewBest then self.bestRounds = self:completedRounds() end
    end
end

-- Leave the feedback for a correct answer: on to the next card, or the next round.
function SimonGame:continue()
    assert(not self.isOver, "the game is over; start a new one")
    if self:isRoundComplete() then
        self:startRound()
    else
        self:askQuestion(self.answerIndex + 1)
    end
end
