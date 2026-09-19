
-- ===== SCREENSHOT HARNESS (appended to a build copy of main.lua; never shipped) =====
do
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
    pd.isCrankDocked = function() return docked end
    gameState.soundEnabled = false

    local function log(msg)
        print("[harness] " .. msg)
        local f = pd.file.open("harness-log.txt", pd.file.kFileAppend)
        if f then f:write(msg .. "\n"); f:close() end
    end

    local function frames(n) for _ = 1, (n or 1) do coroutine.yield() end end
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
        for i, v in ipairs(list) do if v == value then return i end end
    end

    -- Answer the current question. correct=true picks the right answer.
    local function answer(correct, shotName)
        local pos = gameState:getCurrentPosition()
        if gameState:getQuizMode() == GameState.MODES.QUIZ_CARD_TO_NUMBER then
            SharedState.selectedNumber = correct and pos or (pos % 52) + 1
        else
            local right = indexOf(Deck.uspccOrder, Deck.mnemonicaStack[pos])
            SharedState.selectedCard = correct and right or (right % 52) + 1
        end
        frames(1)
        press(pd.kButtonA, 3)
        if shotName then shot(shotName) end
        press(pd.kButtonA, 2)
    end

    local function menuTo(index)
        MenuScene.selection = index
        frames(2)
    end

    local function quizTour(prefix)
        frames(30)
        shot(prefix .. "-q-rest")
        setCrank(7); frames(2); shot(prefix .. "-q-anim-mid")
        frames(40); shot(prefix .. "-q-crank7-settled")
        setCrank(180); frames(3); shot(prefix .. "-q-crank180-mid")
        frames(45); shot(prefix .. "-q-crank180-settled")
        setCrank(355); frames(45); shot(prefix .. "-q-crank355-wrap")
        press(pd.kButtonRight, 0); press(pd.kButtonRight, 1); shot(prefix .. "-q-dpad-jump-mid")
        frames(45); shot(prefix .. "-q-dpad-jump-settled")
        docked = true; frames(3); shot(prefix .. "-q-docked"); docked = false
        frames(2)
        answer(true, prefix .. "-fb-correct")
        answer(false, prefix .. "-fb-wrong")
    end

    local scenarios = {}

    -- Tour of every screen reachable without finishing a quiz.
    scenarios.tour = function()
        frames(10)
        docked = true; frames(3); shot("menu-docked"); docked = false
        for i = 1, 6 do menuTo(i); shot("menu-sel" .. i) end

        menuTo(1); press(pd.kButtonA, 2); quizTour("n2c"); press(pd.kButtonB, 3)
        menuTo(2); press(pd.kButtonA, 2); quizTour("c2n"); press(pd.kButtonB, 3)

        menuTo(3); press(pd.kButtonA, 5); shot("study-1")
        press(pd.kButtonRight, 3); shot("study-2")
        press(pd.kButtonDown, 3); press(pd.kButtonDown, 3); shot("study-22")
        setCrank(200); frames(10); shot("study-crank200")
        docked = true; frames(3); shot("study-docked"); docked = false
        press(pd.kButtonB, 3)

        menuTo(4); press(pd.kButtonA, 5); shot("simon-showing")
        press(pd.kButtonA, 3); shot("simon-waiting")
        press(pd.kButtonA, 30); shot("simon-input")
        docked = true; frames(3); shot("simon-input-docked"); docked = false
        press(pd.kButtonA, 5); shot("simon-feedback")
        press(pd.kButtonA, 5); shot("simon-after-feedback")
        press(pd.kButtonB, 5); shot("simon-after-b")
        if gameState.currentMode ~= GameState.MODES.MENU then press(pd.kButtonB, 5) end

        menuTo(5); press(pd.kButtonA, 5); shot("highscores"); press(pd.kButtonB, 3)

        menuTo(6); press(pd.kButtonA, 5)
        for i = 1, 6 do SettingsScene.selection = i; frames(2); shot("settings-sel" .. i) end
        SettingsScene.selection = 5; frames(1); press(pd.kButtonA, 5); shot("credits")
        press(pd.kButtonB, 3); press(pd.kButtonB, 3)
        shot("menu-final")
    end

    -- Finish a whole quiz with `wrong` mistakes, then walk summary + mistake review.
    local function completeQuiz(menuIndex, wrong, prefix)
        menuTo(menuIndex); press(pd.kButtonA, 3)
        for q = 1, 52 do
            answer(q > wrong)
        end
        frames(5); shot(prefix .. "-summary")
        for i = 2, 4 do
            press(pd.kButtonDown, 2); shot(prefix .. "-summary-opt" .. i)
        end
    end

    scenarios.complete = function()
        frames(10)
        completeQuiz(1, 5, "n2c-5wrong")
        -- walk the options: find mistakes list and review
        SummaryScene.selectedOption = 2; frames(2); press(pd.kButtonA, 4); shot("opt2-result")
        press(pd.kButtonDown, 2); press(pd.kButtonDown, 2); shot("opt2-after-down")
        press(pd.kButtonB, 4); shot("opt2-after-b")
        SummaryScene.selectedOption = 3; frames(2); press(pd.kButtonA, 4); shot("opt3-result")
        for i = 1, 8 do
            press(pd.kButtonA, 4); shot("opt3-after-a" .. i)
        end
    end

    scenarios.complete_many = function()
        frames(10)
        completeQuiz(2, 30, "c2n-30wrong")
        SummaryScene.selectedOption = 2; frames(2); press(pd.kButtonA, 4); shot("mistakes-list")
        for i = 1, 25 do press(pd.kButtonDown, 1) end
        shot("mistakes-list-scrolled")
        press(pd.kButtonB, 4)
        -- second perfect run to see new-high-score + zero-mistake layout
        SummaryScene.selectedOption = 1; frames(2); press(pd.kButtonA, 4); shot("after-opt1")
    end

    -- Summary -> mistakes list -> "Start Review Quiz": study phase, then the re-quiz.
    scenarios.review = function()
        frames(10)
        completeQuiz(1, 3, "n2c-3wrong")
        SummaryScene.selectedOption = 2; frames(2); press(pd.kButtonA, 4); shot("mistakes-list")
        press(pd.kButtonA, 4); shot("review-study-1")
        expect(gameState.currentMode == GameState.MODES.MISTAKE_REVIEW, "review mode started")
        press(pd.kButtonA, 4); shot("review-study-2")
        press(pd.kButtonB, 4); shot("review-study-back")
        press(pd.kButtonA, 4); press(pd.kButtonA, 4); shot("review-study-3")
        press(pd.kButtonA, 4); shot("review-quiz-question-1")
        expect(gameState.quizState == GameState.QUIZ_STATES.QUESTION, "re-quiz started after last study card")
        expect(gameState.currentSession.totalQuestions == 3, "re-quiz asks only the 3 mistakes")
        answer(true, "review-quiz-feedback-correct")
        answer(false, "review-quiz-feedback-wrong")
        answer(true)
        frames(4); shot("review-complete")
        expect(gameState.quizState == GameState.QUIZ_STATES.COMPLETE, "re-quiz completes")
        expect(gameState.currentSession.statistics.score == 2, "re-quiz scored 2 of 3")
        press(pd.kButtonA, 4); shot("back-to-summary")
        expect(gameState.currentMode == GameState.MODES.QUIZ_NUMBER_TO_CARD, "returns to original summary")
        expect(gameState.currentSession.totalQuestions == 52, "original session restored")
    end

    scenarios.perfect = function()
        frames(10)
        completeQuiz(1, 0, "n2c-perfect")
        menuTo(5)
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
            if not ok then log("SCRIPT ERROR: " .. tostring(err)); dead = true; return end
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
