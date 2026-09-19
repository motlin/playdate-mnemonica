std = "lua54"
include_files = { "source/**/*.lua", "spec/**/*.lua" }
globals = {
    "playdate",
    "GameState", "QuizSession", "MistakeReviewMode",
    "UIHelpers", "CrankSelector", "Picker", "AnswerDial", "CarouselLayout", "Carousel", "Layout",
    "App", "Assets", "Deck", "SceneManager", "SystemMenu",
    "MenuScene", "QuizScene", "FeedbackScene", "SummaryScene", "MistakeListScene", "MistakeStudyScene",
    "MistakeReviewCompleteScene", "StudyScene", "SimonScene", "HighScoresScene", "SettingsScene", "CreditsScene",
}
read_globals = { "import", "kTextAlignment" }
max_line_length = false

files["spec"] = { std = "+busted", globals = { "playdate", "import" } }
