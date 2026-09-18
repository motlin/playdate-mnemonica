local gfx <const> = playdate.graphics

UIHelpers = {}

-- Draw a menu item with consistent selection highlighting
-- Uses outlined rectangle with arrow indicators for selected items
function UIHelpers.drawMenuItem(text, x, y, width, isSelected, centerText)
    if centerText == nil then centerText = true end

    if isSelected then
        -- Draw outlined selection box
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(2)
        gfx.drawRoundRect(x - width/2, y - 3, width, 22, 3)
        gfx.setLineWidth(1)

        -- Draw arrow indicators on sides
        local leftArrowX = x - width/2 - 18
        local rightArrowX = x + width/2 + 14
        local arrowY = y + 7

        gfx.fillTriangle(leftArrowX, arrowY, leftArrowX + 4, arrowY - 3, leftArrowX + 4, arrowY + 3)
        gfx.fillTriangle(rightArrowX, arrowY, rightArrowX - 4, arrowY - 3, rightArrowX - 4, arrowY + 3)

        -- Draw text normally (black on white)
        if centerText then
            gfx.drawTextAligned(text, x, y, kTextAlignment.center)
        else
            gfx.drawText(text, x - width/2, y)
        end
    else
        -- Draw text without selection
        if centerText then
            gfx.drawTextAligned(text, x, y, kTextAlignment.center)
        else
            gfx.drawText(text, x - width/2, y)
        end
    end
end

-- Draw a list of menu items with consistent styling
function UIHelpers.drawMenuList(items, x, startY, width, selectedIndex, spacing)
    spacing = spacing or 25

    for i, item in ipairs(items) do
        local y = startY + (i - 1) * spacing
        UIHelpers.drawMenuItem(item, x, y, width, i == selectedIndex)
    end
end
