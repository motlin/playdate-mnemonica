-- Results of a mistake review, shown once its re-quiz is finished.

import "App"
import "Assets"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

MistakeReviewCompleteScene = {}

local function draw()
    gfx.clear()

    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Mistake Review Complete!", 200, 20, kTextAlignment.center)
    gfx.setFont()

    local summary = gameState.mistakeReviewMode:getSummary()

    gfx.drawTextAligned("-- Study Phase --", 200, 50, kTextAlignment.center)
    gfx.drawTextAligned("Mistakes studied: " .. summary.mistakesReviewed, 200, 70, kTextAlignment.center)
    local studyMinutes = math.floor(summary.studyTimeTotal / 60)
    local studySeconds = math.floor(summary.studyTimeTotal % 60)
    gfx.drawTextAligned(string.format("Study time: %d:%02d", studyMinutes, studySeconds), 200, 85, kTextAlignment.center)

    gfx.drawTextAligned("-- Quiz Results --", 200, 110, kTextAlignment.center)
    local scoreText = string.format("Score: %d/%d (%d%%)", summary.quizScore, summary.quizTotal, summary.quizAccuracy)
    gfx.drawTextAligned(scoreText, 200, 130, kTextAlignment.center)

    if #summary.improvedMistakes > 0 then
        local improvementRate = math.floor((#summary.improvedMistakes / summary.mistakesReviewed) * 100)
        gfx.drawTextAligned("Improved: " .. #summary.improvedMistakes .. " cards (" .. improvementRate .. "%)",
            200, 150, kTextAlignment.center)
    end

    local remainingMistakes = summary.mistakesReviewed - summary.quizScore
    if remainingMistakes > 0 then
        gfx.drawTextAligned("Still need practice: " .. remainingMistakes .. " cards", 200, 170, kTextAlignment.center)
    else
        gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
        gfx.drawTextAligned("Perfect! All mistakes corrected!", 200, 170, kTextAlignment.center)
        gfx.setFont()
    end

    gfx.drawTextAligned("Press A to return to quiz summary", 200, 210, kTextAlignment.center)
end

function MistakeReviewCompleteScene.update()
    draw()

    if pd.buttonJustPressed(pd.kButtonA) then
        Assets.playSound(sounds.buttonPress)

        -- Back to the summary of the quiz that was under review
        gameState.currentSession = gameState.originalSession
        gameState.originalSession = nil
        gameState.mistakeReviewMode = nil
        gameState.quizState = GameState.QUIZ_STATES.COMPLETE
        gameState.currentMode = gameState.currentSession.mode
        SceneManager.switch(SummaryScene)
    end
end
