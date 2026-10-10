-- ===== SCREENSHOT HARNESS (appended to a build copy of main.lua; never shipped) =====
-- It drives the game with simulator-only calls. If this build is ever uploaded to a device by
-- mistake, it stays out of the way and the game runs normally.
if playdate.isSimulator then
    local pd <const> = playdate
    local gfx <const> = playdate.graphics
    local gameState <const> = App.gameState
    local OUT <const> = HARNESS_OUT
    local SCENARIO <const> = HARNESS_SCENARIO
    local realUpdate = playdate.update
    local pressed = {}
    local crank = 0
    local docked = false
    local pendingShot = nil
    local shotCount = 0

    -- Deterministic runs: fixed shuffle order and a clock that advances one frame per update,
    -- so two runs of the same code produce byte-identical screenshots.
    local frameCount = 0
    math.randomseed(52)
    pd.getCurrentTimeMilliseconds = function() return frameCount * 33 end

    pd.buttonJustPressed = function(b) return pressed[b] == true end
    pd.getCrankPosition = function() return crank end
    -- Like the device: travel since the previous call, taking the short way round
    local reportedCrank = 0
    pd.getCrankChange = function()
        local change = (crank - reportedCrank + 180) % 360 - 180
        reportedCrank = crank
        return change
    end
    pd.isCrankDocked = function() return docked end
    gameState.soundEnabled = false
    -- The game being replaced saves its statistics as it quits, after run.sh has cleared the
    -- data folder, so start every scenario from fresh statistics regardless.
    gameState:resetCardStats()

    local function log(msg)
        print("[harness] " .. msg)
        local f = pd.file.open("harness-log.txt", pd.file.kFileAppend)
        if f then
            f:write(msg .. "\n")
            f:close()
        end
    end

    local function frames(n)
        for _ = 1, (n or 1) do
            coroutine.yield()
        end
    end
    local function press(b, settle)
        pressed[b] = true
        coroutine.yield()
        pressed[b] = nil
        frames(settle or 2)
    end
    local function shot(name)
        shotCount = shotCount + 1
        pendingShot = string.format("%s-%02d-%s", SCENARIO, shotCount, name)
        coroutine.yield()
    end
    local function setCrank(deg) crank = deg % 360 end
    local function expect(condition, message)
        if not condition then error("expectation failed: " .. message, 2) end
    end
    local function indexOf(list, value)
        for i, v in ipairs(list) do
            if v == value then return i end
        end
    end

    -- Answer the current question. correct=true picks the right answer.
    local function answer(correct, shotName)
        local pos = gameState:getCurrentPosition()
        if gameState:getQuizMode() == GameState.MODES.QUIZ_CARD_TO_NUMBER then
            QuizScene.dial:select(correct and pos or (pos % 52) + 1)
        else
            local right = indexOf(Deck.uspccOrder, Deck.mnemonicaStack[pos])
            QuizScene.dial:select(correct and right or (right % 52) + 1)
        end
        frames(1)
        press(pd.kButtonA, 3)
        if shotName then shot(shotName) end
        press(pd.kButtonA, 2)
    end

    local function menuTo(index)
        MenuScene.select(index)
        frames(2)
    end

    local function quizTour(prefix)
        frames(30)
        shot(prefix .. "-q-rest")
        setCrank(7)
        frames(2)
        shot(prefix .. "-q-anim-mid")
        frames(40)
        shot(prefix .. "-q-crank7-settled")
        setCrank(180)
        frames(3)
        shot(prefix .. "-q-crank180-mid")
        frames(45)
        shot(prefix .. "-q-crank180-settled")
        setCrank(355)
        frames(45)
        shot(prefix .. "-q-crank355-wrap")
        press(pd.kButtonRight, 0)
        press(pd.kButtonRight, 1)
        shot(prefix .. "-q-dpad-jump-mid")
        frames(45)
        shot(prefix .. "-q-dpad-jump-settled")
        docked = true
        frames(3)
        shot(prefix .. "-q-docked")
        docked = false
        frames(2)
        answer(true, prefix .. "-fb-correct")
        answer(false, prefix .. "-fb-wrong")
    end

    local scenarios = {}

    -- Tour of every screen reachable without finishing a quiz.
    scenarios.tour = function()
        frames(10)
        docked = true
        frames(3)
        shot("menu-docked")
        docked = false
        for i = 1, 6 do
            menuTo(i)
            shot("menu-sel" .. i)
        end

        menuTo(1)
        press(pd.kButtonA, 2)
        quizTour("n2c")
        press(pd.kButtonB, 3)
        menuTo(2)
        press(pd.kButtonA, 2)
        quizTour("c2n")
        press(pd.kButtonB, 3)

        menuTo(3)
        press(pd.kButtonA, 5)
        shot("study-1")
        press(pd.kButtonRight, 3)
        shot("study-2")
        press(pd.kButtonDown, 3)
        press(pd.kButtonDown, 3)
        shot("study-22")
        setCrank(200)
        frames(10)
        shot("study-crank200")
        docked = true
        frames(3)
        shot("study-docked")
        docked = false
        press(pd.kButtonB, 3)

        menuTo(4)
        press(pd.kButtonA, 5)
        shot("simon-showing")
        press(pd.kButtonA, 3)
        shot("simon-waiting")
        press(pd.kButtonA, 30)
        shot("simon-input")
        docked = true
        frames(3)
        shot("simon-input-docked")
        docked = false
        press(pd.kButtonA, 5)
        shot("simon-feedback")
        press(pd.kButtonA, 5)
        shot("simon-after-feedback")
        press(pd.kButtonB, 5)
        shot("simon-after-b")
        if gameState.currentMode ~= GameState.MODES.MENU then press(pd.kButtonB, 5) end

        menuTo(5)
        press(pd.kButtonA, 5)
        shot("highscores")
        press(pd.kButtonB, 3)

        menuTo(6)
        press(pd.kButtonA, 5)
        for i = 1, 6 do
            SettingsScene.selection = i
            frames(2)
            shot("settings-sel" .. i)
        end
        gameState.cardStats[1].timesAsked = 5
        SettingsScene.selection = 3
        frames(1)
        press(pd.kButtonA, 3)
        shot("settings-reset-armed")
        expect(gameState.cardStats[1].timesAsked == 5, "first A on Reset Statistics only asks for confirmation")
        press(pd.kButtonDown, 2)
        press(pd.kButtonUp, 2)
        press(pd.kButtonA, 3)
        expect(gameState.cardStats[1].timesAsked == 5, "moving away cancels the pending reset")
        press(pd.kButtonA, 3)
        shot("settings-reset-done")
        expect(gameState.cardStats[1].timesAsked == 0, "second A resets statistics")
        SettingsScene.selection = 5
        frames(1)
        press(pd.kButtonA, 5)
        shot("credits")
        press(pd.kButtonB, 3)
        press(pd.kButtonB, 3)
        shot("menu-final")
    end

    -- Finish a whole quiz with `wrong` mistakes, then walk summary + mistake review.
    local function completeQuiz(menuIndex, wrong, prefix)
        menuTo(menuIndex)
        press(pd.kButtonA, 3)
        for q = 1, 52 do
            answer(q > wrong)
        end
        frames(5)
        shot(prefix .. "-summary")
        for i = 2, 4 do
            press(pd.kButtonDown, 2)
            shot(prefix .. "-summary-opt" .. i)
        end
    end

    scenarios.complete = function()
        frames(10)
        completeQuiz(1, 5, "n2c-5wrong")
        -- walk the options: find mistakes list and review
        SummaryScene.selectedOption = 2
        frames(2)
        press(pd.kButtonA, 4)
        shot("opt2-result")
        press(pd.kButtonDown, 2)
        press(pd.kButtonDown, 2)
        shot("opt2-after-down")
        press(pd.kButtonB, 4)
        shot("opt2-after-b")
        SummaryScene.selectedOption = 3
        frames(2)
        press(pd.kButtonA, 4)
        shot("opt3-result")
        for i = 1, 8 do
            press(pd.kButtonA, 4)
            shot("opt3-after-a" .. i)
        end
    end

    scenarios.complete_many = function()
        frames(10)
        completeQuiz(2, 30, "c2n-30wrong")
        SummaryScene.selectedOption = 2
        frames(2)
        press(pd.kButtonA, 4)
        shot("mistakes-list")
        for i = 1, 25 do
            press(pd.kButtonDown, 1)
        end
        shot("mistakes-list-scrolled")
        press(pd.kButtonB, 4)
        -- second perfect run to see new-high-score + zero-mistake layout
        SummaryScene.selectedOption = 1
        frames(2)
        press(pd.kButtonA, 4)
        shot("after-opt1")
    end

    -- Summary -> mistakes list -> "Start Review Quiz": study phase, then the re-quiz.
    scenarios.review = function()
        frames(10)
        completeQuiz(1, 3, "n2c-3wrong")
        SummaryScene.selectedOption = 2
        frames(2)
        press(pd.kButtonA, 4)
        shot("mistakes-list")
        press(pd.kButtonA, 4)
        shot("review-study-1")
        expect(gameState.currentMode == GameState.MODES.MISTAKE_REVIEW, "review mode started")
        press(pd.kButtonA, 4)
        shot("review-study-2")
        press(pd.kButtonB, 4)
        shot("review-study-back")
        press(pd.kButtonA, 4)
        press(pd.kButtonA, 4)
        shot("review-study-3")
        press(pd.kButtonA, 4)
        shot("review-quiz-question-1")
        expect(gameState.quizState == GameState.QUIZ_STATES.QUESTION, "re-quiz started after last study card")
        expect(gameState.currentSession.totalQuestions == 3, "re-quiz asks only the 3 mistakes")
        answer(true, "review-quiz-feedback-correct")
        answer(false, "review-quiz-feedback-wrong")
        answer(true)
        frames(4)
        shot("review-complete")
        expect(gameState.quizState == GameState.QUIZ_STATES.COMPLETE, "re-quiz completes")
        expect(gameState.currentSession.statistics.score == 2, "re-quiz scored 2 of 3")
        press(pd.kButtonA, 4)
        shot("back-to-summary")
        expect(gameState.currentMode == GameState.MODES.QUIZ_NUMBER_TO_CARD, "returns to original summary")
        expect(gameState.currentSession.totalQuestions == 52, "original session restored")
    end

    -- D-pad on the main menu: every press moves exactly one row, in both directions, however
    -- quickly the presses come and whatever the crank is doing.
    scenarios.menu_dpad = function()
        frames(10)
        local function expectSelection(expected, action)
            expect(
                MenuScene.selection == expected,
                action .. " should select row " .. expected .. ", got " .. tostring(MenuScene.selection)
            )
        end

        MenuScene.select(1)
        for row = 2, 6 do
            press(pd.kButtonDown, 1)
            expectSelection(row, "Down")
        end
        press(pd.kButtonDown, 1)
        expectSelection(1, "Down past the end")

        for _, row in ipairs({ 6, 5, 4, 3, 2, 1 }) do
            press(pd.kButtonUp, 1)
            expectSelection(row, "Up")
        end

        -- Presses on consecutive frames
        MenuScene.select(4)
        press(pd.kButtonUp, 0)
        press(pd.kButtonUp, 0)
        press(pd.kButtonUp, 0)
        expectSelection(1, "three fast Ups")

        -- A resting crank that wobbles a degree or two each frame, as a real one does
        MenuScene.select(4)
        for _, row in ipairs({ 3, 2, 1, 6 }) do
            setCrank(crank + 1.5)
            frames(1)
            setCrank(crank - 2)
            frames(1)
            press(pd.kButtonUp, 1)
            expectSelection(row, "Up with a wobbling crank")
        end

        -- A crank slowly drifting forward while Up is pressed
        MenuScene.select(4)
        for _, row in ipairs({ 3, 2, 1 }) do
            for _ = 1, 10 do
                setCrank(crank + 5)
                frames(1)
            end
            press(pd.kButtonUp, 1)
            expectSelection(row, "Up while the crank drifts forward")
        end
        shot("menu-after-dpad")
    end

    -- Plays Simon through three rounds, then loses, checking the rules on the way.
    scenarios.simon = function()
        local PHASES <const> = SimonGame.PHASES

        local function watchSequence(round)
            for card = 1, round do
                expect(SimonScene.game.phase == PHASES.SHOWING, "round " .. round .. " shows card " .. card)
                if card == round then shot("round" .. round .. "-showing-card" .. card) end
                press(pd.kButtonA, 3)
            end
            expect(SimonScene.game.phase == PHASES.WAITING, "round " .. round .. " waits after its whole sequence")
            press(pd.kButtonA, 3)
        end

        local function answerQuestion(round, card, correct)
            local game = SimonScene.game
            expect(game.phase == PHASES.INPUT, "round " .. round .. " asks for card " .. card)
            expect(
                game.answerIndex == card,
                "round " .. round .. " is on card " .. card .. ", not " .. tostring(game.answerIndex)
            )
            expect(
                SimonScene.dial:getSelection() == 1,
                "round " .. round .. " card " .. card .. " starts from a clean dial"
            )
            shot("round" .. round .. "-input-card" .. card)

            local answer = game:correctAnswer()
            local index = type(answer) == "number" and answer or indexOf(Deck.uspccOrder, answer)
            SimonScene.dial:select(correct and index or index % 52 + 1)
            frames(12)
            press(pd.kButtonA, 3)
            shot("round" .. round .. "-feedback-card" .. card)
            expect(game.lastAnswerCorrect == correct, "round " .. round .. " card " .. card .. " judged correctly")
        end

        frames(10)

        -- The harness runs muted, which would skip the synth calls entirely. Play one card's
        -- motif out loud so a wrong sound API call fails here rather than on someone's device.
        gameState.soundEnabled = true
        Assets.playCardTones("10C")
        gameState.soundEnabled = false
        frames(20)

        menuTo(4)
        press(pd.kButtonA, 5)

        for round = 1, 2 do
            watchSequence(round)
            for card = 1, round do
                answerQuestion(round, card, true)
                press(pd.kButtonA, 3)
            end
        end

        watchSequence(3)
        answerQuestion(3, 1, true)
        press(pd.kButtonA, 3)
        answerQuestion(3, 2, false)
        expect(SimonScene.game.isOver, "a wrong answer ends the game")
        expect(SimonScene.game:completedRounds() == 2, "two rounds were completed")
        expect(gameState.simonMode.maxRound == 2, "the record is saved")

        press(pd.kButtonA, 5)
        shot("new-game")
        expect(SimonScene.game.round == 1 and #SimonScene.game.sequence == 1, "A starts a fresh game")
    end

    -- Not a playthrough: draws the launcher card and icon from the game's own font and card art.
    scenarios.launcher_art = function()
        local function save(name, width, height, drawContents)
            local image = gfx.image.new(width, height, gfx.kColorBlack)
            gfx.pushContext(image)
            drawContents()
            gfx.popContext()
            pd.simulator.writeToFile(image, OUT .. "/" .. name .. ".png")
        end

        local function drawCardArt(highlighted)
            local firstCards = { 1, 2, 3, 4 }
            for slot, position in ipairs(firstCards) do
                local lift = (highlighted and slot == #firstCards) and -8 or 0
                Assets.drawCard(Deck.mnemonicaStack[position], 34 + (slot - 1) * 30, 78 + lift, 1)
            end
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
            Layout.drawLargeText("Mnemonica", 256, 62)
            gfx.setFont(Layout.boldFont)
            gfx.drawTextAligned("stack memorizer", 256, 88, kTextAlignment.center)
            gfx.setFont()
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end

        save("card", 350, 155, function() drawCardArt(false) end)
        save("card-highlighted", 350, 155, function() drawCardArt(true) end)
        save("icon", 32, 32, function()
            -- The ace of spades' centre pip fills the icon
            gfx.setClipRect(1, 1, 30, 30)
            Assets.drawCard("AS", 16, 16, 1)
            gfx.clearClipRect()
        end)
        frames(2)
    end

    scenarios.perfect = function()
        frames(10)
        completeQuiz(1, 0, "n2c-perfect")
        SummaryScene.selectedOption = 1
        frames(2)
        press(pd.kButtonDown, 2)
        shot("n2c-perfect-main-menu-selected")
        press(pd.kButtonA, 4)
        shot("n2c-perfect-after-main-menu")
        expect(SceneManager.isCurrent(MenuScene), "Main Menu is reachable after a perfect score")
    end

    local co = coroutine.create(function()
        log("scenario " .. SCENARIO .. " start")
        scenarios[SCENARIO]()
        shot("zz-done")
        log("scenario " .. SCENARIO .. " done")
    end)

    local dead = false
    function playdate.update()
        if dead then return end
        frameCount = frameCount + 1
        if coroutine.status(co) ~= "dead" then
            local ok, err = coroutine.resume(co)
            if not ok then
                log("SCRIPT ERROR: " .. tostring(err))
                dead = true
                return
            end
        end
        local ok, err = xpcall(realUpdate, (debug and debug.traceback) or function(e) return e end)
        if not ok then
            log("GAME CRASH: " .. tostring(err))
            pd.simulator.writeToFile(gfx.getWorkingImage(), OUT .. "/" .. SCENARIO .. "-CRASH.png")
            dead = true
            return
        end
        if pendingShot then
            pd.simulator.writeToFile(gfx.getWorkingImage(), OUT .. "/" .. pendingShot .. ".png")
            pendingShot = nil
        end
    end
end
