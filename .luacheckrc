std = "lua54"
include_files = { "source/**/*.lua", "spec/**/*.lua" }
globals = { "playdate" }
read_globals = { "import", "kTextAlignment" }
max_line_length = false

files["spec"] = { std = "+busted", globals = { "playdate", "import" } }
