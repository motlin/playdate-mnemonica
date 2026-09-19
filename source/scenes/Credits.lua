import "App"
import "Assets"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics

CreditsScene = {}

local marbleMadnessFont = gfx.font.new("fonts/MarbleMadness")
assert(marbleMadnessFont, "Failed to load Marble Madness font")

local function draw()
    gfx.clear()

    gfx.setFont(gfx.getSystemFont(gfx.font.kFontFamilyHeading))
    gfx.drawTextAligned("Credits", 200, 15, kTextAlignment.center)

    gfx.setFont(marbleMadnessFont)

    local leftX = 40
    local lineHeight = 10
    local y = 45

    gfx.drawText("Mnemonica Stack Memorizer", leftX, y)
    y = y + lineHeight
    gfx.drawText("for Playdate", leftX, y)
    y = y + lineHeight * 1.5

    gfx.drawText("Created by:", leftX, y)
    y = y + lineHeight
    gfx.drawText("  Mr. Poopybutthole", leftX, y)
    y = y + lineHeight * 1.5

    gfx.drawText("Playing Card Assets:", leftX, y)
    y = y + lineHeight
    gfx.drawText("  Free playing cards from:", leftX, y)
    y = y + lineHeight
    gfx.drawText("  devforum.play.date/t/", leftX, y)
    y = y + lineHeight
    gfx.drawText("  playing-card-deck-imagetable-", leftX, y)
    y = y + lineHeight
    gfx.drawText("  free-for-your-card-game/994", leftX, y)
    y = y + lineHeight * 2

    gfx.drawText("Press B to return", leftX, y)
end

function CreditsScene.update()
    draw()

    if pd.buttonJustPressed(pd.kButtonB) then
        Assets.playSound(Assets.sounds.buttonPress)
        SceneManager.switch(SettingsScene, SettingsScene.CREDITS)
    end
end
