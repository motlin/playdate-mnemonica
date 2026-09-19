import "App"
import "Assets"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState

HighScoresScene = {}

local function drawQuizScores(title, scores, y)
    gfx.drawTextAligned(title, 200, y, kTextAlignment.center)
    if scores.bestTime then
        gfx.drawTextAligned("Best Score: " .. scores.bestScore .. "/52", 200, y + 20, kTextAlignment.center)

        local minutes = math.floor(scores.bestTime / 60)
        local seconds = math.floor(scores.bestTime % 60)
        gfx.drawTextAligned(string.format("Best Time: %d:%02d", minutes, seconds), 200, y + 40, kTextAlignment.center)
    else
        gfx.drawTextAligned("No scores yet", 200, y + 20, kTextAlignment.center)
    end
end

local function draw()
    gfx.clear()

    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("High Scores", 200, 20, kTextAlignment.center)
    gfx.setFont()

    drawQuizScores("-- Number to Card Quiz --", gameState.highScores.numberToCard, 60)
    drawQuizScores("-- Card to Number Quiz --", gameState.highScores.cardToNumber, 130)

    gfx.drawTextAligned("-- Simon Mode --", 200, 190, kTextAlignment.center)
    if gameState.simonMode.maxRound > 0 then
        gfx.drawTextAligned("Best: Round " .. gameState.simonMode.maxRound, 200, 205, kTextAlignment.center)
    else
        gfx.drawTextAligned("No scores yet", 200, 205, kTextAlignment.center)
    end

    gfx.drawTextAligned("Press (B) to return to menu", 200, 225, kTextAlignment.center)
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
