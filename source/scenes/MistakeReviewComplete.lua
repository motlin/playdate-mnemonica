-- Results of a mistake review, shown once its re-quiz is finished.

import "App"
import "Layout"
import "Assets"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local gameState <const> = App.gameState
local sounds <const> = Assets.sounds

MistakeReviewCompleteScene = {}

local FOOTER_HINTS <const> = { { button = "A", label = "Summary" } }

local function draw()
    gfx.clear()
    Layout.drawTitleBar("Review complete")

    local summary = gameState.mistakeReviewMode:getSummary()

    Layout.drawLargeText(summary.quizScore .. "/" .. summary.quizTotal, 200, 80)

    local remaining = summary.quizTotal - summary.quizScore
    local verdict = remaining == 0 and "Every mistake fixed" or (remaining .. " still to practice")
    gfx.setFont(Layout.boldFont)
    gfx.drawTextAligned(verdict, 200, 118, kTextAlignment.center)
    gfx.setFont()
    gfx.drawTextAligned("Studied for " .. Layout.formatTime(summary.studyTimeTotal), 200, 148, kTextAlignment.center)

    Layout.drawFooter(FOOTER_HINTS, false)
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
