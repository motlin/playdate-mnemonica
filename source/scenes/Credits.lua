import "App"
import "Assets"
import "Layout"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics

CreditsScene = {}

local FOOTER_HINTS <const> = { { button = "B", label = "Back" } }

local function draw()
    gfx.clear()
    Layout.drawTitleBar("Credits")

    gfx.setFont(Layout.boldFont)
    gfx.drawTextAligned("Mnemonica Stack Memorizer", 200, 40, kTextAlignment.center)
    gfx.setFont()
    gfx.drawTextAligned("by Mr. Poopybutthole", 200, 64, kTextAlignment.center)

    gfx.setFont(Layout.boldFont)
    gfx.drawTextAligned("Playing card art", 200, 110, kTextAlignment.center)
    gfx.setFont()
    gfx.drawTextAligned("Free deck from the Playdate developer forum", 200, 134, kTextAlignment.center)
    gfx.drawTextAligned("devforum.play.date/t/994", 200, 156, kTextAlignment.center)

    Layout.drawFooter(FOOTER_HINTS, false)
end

function CreditsScene.update()
    draw()

    if pd.buttonJustPressed(pd.kButtonB) then
        Assets.playSound(Assets.sounds.buttonPress)
        SceneManager.switch(SettingsScene, SettingsScene.CREDITS)
    end
end
