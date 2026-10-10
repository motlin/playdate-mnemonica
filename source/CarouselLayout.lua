-- Where each item of a horizontal carousel sits for a given scroll position.
-- The item nearest the scroll position is the selection, drawn at double size in the middle;
-- the rest are single size. Only whole-number scales are used because the 1-bit card art
-- turns to mush at anything else.

CarouselLayout = {}

-- Centre-to-centre distances for a 100px selection and 50px neighbours. They leave gaps of
-- 16px and 18px, and put the third neighbour just off a 400px screen when at rest.
local SELECTION_SPACING <const> = 91
local NEIGHBOUR_SPACING <const> = 68
local REACH <const> = 3
local SETTLE_DISTANCE <const> = 0.02

local function offsetToX(offset, centerX)
    local distance = math.abs(offset)
    local pixels
    if distance <= 1 then
        pixels = distance * SELECTION_SPACING
    else
        pixels = SELECTION_SPACING + (distance - 1) * NEIGHBOUR_SPACING
    end
    return math.floor(centerX + (offset < 0 and -pixels or pixels) + 0.5)
end

-- Items to draw, furthest from the middle first so the selection ends up on top.
-- `scrollPosition` may sit between two item numbers while the carousel is moving.
-- Items whose centre is further than `halfWidth` from `centerX` are left out.
function CarouselLayout.visibleItems(scrollPosition, itemCount, centerX, halfWidth)
    local nearest = math.floor(scrollPosition + 0.5)
    local items = {}

    for candidate = nearest - REACH, nearest + REACH do
        local x = offsetToX(candidate - scrollPosition, centerX)
        if math.abs(x - centerX) < halfWidth then
            items[#items + 1] = {
                index = (candidate - 1) % itemCount + 1,
                x = x,
                scale = candidate == nearest and 2 or 1,
            }
        end
    end

    table.sort(items, function(a, b)
        if a.scale ~= b.scale then return a.scale < b.scale end
        return math.abs(a.x - centerX) > math.abs(b.x - centerX)
    end)

    return items
end

-- Move `scrollPosition` a fraction of the way to `target`, going the short way round the wrap.
-- The result stays within half an item of the valid range so it never drifts.
function CarouselLayout.approach(scrollPosition, target, fraction, itemCount)
    local delta = (target - scrollPosition + itemCount / 2) % itemCount - itemCount / 2
    if math.abs(delta) < SETTLE_DISTANCE then return target end

    local nextPosition = scrollPosition + delta * fraction
    if nextPosition > itemCount + 0.5 then
        nextPosition = nextPosition - itemCount
    elseif nextPosition < 0.5 then
        nextPosition = nextPosition + itemCount
    end
    return nextPosition
end
