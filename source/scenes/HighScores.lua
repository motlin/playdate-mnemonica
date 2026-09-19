import "App"
import "Assets"
import "Layout"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState

HighScoresScene = {}

local FOOTER_HINTS <const> = { { button = "B", label = "Menu" } }
local LABEL_X <const> = 40
local VALUE_X <const> = 360

local function drawRow(label, value, y)
    gfx.setFont(Layout.boldFont)
    gfx.drawText(label, LABEL_X, y)
    gfx.setFont()
    gfx.drawTextAligned(value, VALUE_X, y, kTextAlignment.right)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(LABEL_X, y + 28, VALUE_X, y + 28)
end

local function quizRecord(scores)
    if not scores.bestTime then
        return "not played yet"
    end
    return scores.bestScore .. "/52 in " .. Layout.formatTime(scores.bestTime)
end

local function draw()
    gfx.clear()
    Layout.drawTitleBar("High scores")

    drawRow("Number to Card", quizRecord(gameState.highScores.numberToCard), 50)
    drawRow("Card to Number", quizRecord(gameState.highScores.cardToNumber), 100)

    local simonRounds = gameState.simonMode.maxRound
    drawRow("Simon", simonRounds == 1 and "1 round" or (simonRounds .. " rounds"), 150)

    Layout.drawFooter(FOOTER_HINTS, false)
end

function HighScoresScene.enter()
    gameState.currentMode = GameState.MODES.HIGH_SCORES
end

function HighScoresScene.update()
    draw()

    if pd.buttonJustPressed(pd.kButtonB) then
        Assets.playSound(Assets.sounds.buttonPress)
        SceneManager.switch(MenuScene)
    end
end
