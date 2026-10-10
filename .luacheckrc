std = "lua54"
include_files = { "source/**/*.lua", "spec/**/*.lua" }
max_line_length = false
self = false

-- Playdate SDK globals.
read_globals = { "import", "kTextAlignment", "playdate" }

-- Each module and scene publishes itself as a global for the Playdate runtime.
globals = {
    "GameState", "QuizSession", "MistakeReviewMode",
    "CrankSelector", "Picker", "AnswerDial", "CarouselLayout", "Carousel", "Layout", "FactView", "SimonGame", "CardTones",
    "App", "Assets", "Deck", "SceneManager", "SystemMenu",
    "MenuScene", "QuizScene", "FeedbackScene", "SummaryScene", "MistakeListScene", "MistakeStudyScene",
    "MistakeReviewCompleteScene", "StudyScene", "SimonScene", "HighScoresScene", "SettingsScene", "CreditsScene",
}

-- main.lua installs the Playdate lifecycle callbacks.
files["source/main.lua"] = {
    globals = {
        "playdate.update",
        "playdate.gameWillPause",
        "playdate.gameWillResume",
        "playdate.deviceWillLock",
        "playdate.deviceDidUnlock",
        "playdate.deviceWillSleep",
        "playdate.gameWillTerminate",
    },
}

files["spec"] = { std = "+busted", globals = { "playdate", "import" } }
