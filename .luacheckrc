std = "lua54"
include_files = { "source/**/*.lua", "spec/**/*.lua" }
globals = {
    "playdate",
    "GameState", "QuizSession", "MistakeReviewMode",
    "DialRenderer", "NumberDialRenderer", "UIHelpers", "CrankSelector",
}
read_globals = { "import", "kTextAlignment" }
max_line_length = false

files["spec"] = { std = "+busted", globals = { "playdate", "import" } }
