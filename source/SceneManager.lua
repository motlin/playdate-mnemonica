-- Runs one scene at a time. A scene is a table with update(), which handles a frame's input and
-- drawing, and optionally enter(...) and exit().

SceneManager = {}

local currentScene

function SceneManager.switch(scene, ...)
    if currentScene and currentScene.exit then currentScene.exit() end
    currentScene = scene
    if scene.enter then scene.enter(...) end
end

function SceneManager.update()
    currentScene.update()
end

function SceneManager.isCurrent(scene)
    return currentScene == scene
end
