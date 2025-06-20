bool UserHasPermissions = false;

#if DEPENDENCY_BETTERROOMMANAGER || DEV
bool HaveDeps = true;
#else
bool HaveDeps = false;
#endif

StatusMsgUI@ statusMsgs;
int nvgFont = 0;

bool LoadingMedalCounts = true;

void Main() {
    UserHasPermissions = Permissions::CreateClub();
    if (!HaveDeps) {
        NotifyError("Missing dependency! You must install *Better Room Manager*, too.");
        return;
    }
    if (!UserHasPermissions) {
        NotifyError("Missing permissions! You need club access.");
        return;
    }
    @statusMsgs = StatusMsgUI();
    nvgFont = nvg::LoadFont("DroidSans-Bold.ttf");
    // nvgFont = nvg::LoadFont("fonts/Montserrat-SemiBoldItalic.ttf", true, true);
    startnew(MainCoro);
    startnew(ClearTaskCoro);
    Meta::StartWithRunContext(Meta::RunContext::GameLoop, Chat::ChatCoro);
    startnew(LoadSavedCommands);

    if (!IO::FolderExists(IO::FromStorageFolder("users/"))) {
        IO::CreateFolder(IO::FromStorageFolder("users"));
    }

    yield();

    if (Time::Now < 20000)
        sleep(1000);
    sleep(0);

    Notify("Loading Player Medal Counts");
    LoadAllPlayerMedalCounts();

    LoadingMedalCounts = false;
    Notify("Done Loading Player Medal Counts. Checking for Session Data to restore.");
    yield();
    State::TryRestoringSessionData();
    Notify("Done restoring session data. TMX Together is now initialized.");
    LoadCustomFinishMessages();
}

string lastMap;
void MainCoro() {
    while (true) {
        yield();
        if (!ShowWindow) {
            sleep(250);
            continue;
        }
        auto map = GetApp().RootMap;
        if (map is null) {
            if (lastMap.Length > 0) {
                lastMap = "";
                OnMapChange();
            }
        } else if (lastMap != map.EdChallengeId) {
            lastMap = map.EdChallengeId;
            OnMapChange();
        }
    }
}

void OnMapChange() {
    State::ResetWR();
    Chat::ResetStateNewMap();
    if (lastMap.Length > 0)
        startnew(State::TryGettingWR);
}

// show the window immediately upon installation
[Setting hidden]
bool ShowWindow = true;

/** Render function called every frame intended only for menu items in `UI`. */
void RenderMenu() {
    if (UI::IsKeyDown(UI::Key::LeftAlt)) {
        RenderMenuDebug();
    } else if (UI::MenuItem(MenuTitle, "", ShowWindow)) {
        ShowWindow = !ShowWindow;
    }
}

void RenderMenuDebug() {
    if (UI::BeginMenu(MenuTitle)) {
        if (UI::MenuItem(MenuTitle, "", ShowWindow)) {
            ShowWindow = !ShowWindow;
        }
        if (UI::MenuItem("Debug: Next Map Cache", "", g_ShowNextMapDebug)) {
            g_ShowNextMapDebug = !g_ShowNextMapDebug;
        }
        UI::EndMenu();
    }
}

int MainWindowFlags = UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse;

float lastDt = 1.;
void Update(float dt) {
    lastDt = dt;
}

void Render() {
    if (!UI::IsOverlayShown() && !S_ShowIfOverlayHidden) return;
    if (!UI::IsGameUIVisible() && !S_ShowIfUIHidden) return;

    RenderTmxTagsSelectionWindow();
    ScoreEditor::Render();
    DrawPlayerMedalCounts();
    statusMsgs.RenderUpdate(lastDt);
    Debug_RenderNextMapWindow();

    if (!ShowWindow) return;


    vec2 size = vec2(450, 300);
    vec2 wpos = (vec2(Draw::GetWidth(), Draw::GetHeight()) - size) / 2.;
    UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::FirstUseEver);
    UI::SetNextWindowPos(int(wpos.x), int(wpos.y), UI::Cond::FirstUseEver);
    PushFontSize();
    UI::PushStyleColor(UI::Col::FrameBg, vec4(.2, .2, .2, .5));
    if (UI::Begin(MenuTitle, ShowWindow, MainWindowFlags)) {
        float minWidth = State::IsRunning ? 170 : 350;
        // if (windowSize.x < minWidth) {
        //     UI::SetWindowSize(vec2(minWidth, windowSize.y), UI::Cond::Always);
        // }
        auto pos = UI::GetCursorPos();
        UI::Dummy(vec2(minWidth, 0));
        UI::SetCursorPos(pos);
        if (!HaveDeps || !UserHasPermissions) {
            UI::TextWrapped("You need club access and/or install Better Room Manager. (One of these checks failed.)");
        } else {
            RenderMainUI();
        }
    }
    UI::End();
    UI::PopStyleColor();
    PopFontSize();
}


void PushFontSize() {
    if (S_FontSize == FontSize::S16_Bold) {
        UI::PushFont(subheadingFont);
    } else if (S_FontSize == FontSize::S20) {
        UI::PushFont(headingFont);
    } else if (S_FontSize == FontSize::S26) {
        UI::PushFont(titleFont);
    }
}

void PopFontSize() {
    if (S_FontSize > FontSize::S16) {
        UI::PopFont();
    }
}



void RenderMainUI() {
    if (State::IsNotRunning) {
        RenderSetupScreen();
    } else {
        RenderGameScreen();
    }
}

SetupScreen@ setupScreen = SetupScreen();

void RenderSetupScreen() {
    setupScreen.Render();
}

GameInterface@ gameInterface = GameInterface();

void RenderGameScreen() {
    gameInterface.RenderMain();
}




void OnDestroyed() { _Unload(); }
// void OnDisabled() { _Unload(); }
void _Unload() {
    Chat::Unload();
    if (!State::IsNotRunning) {
        State::PersistTemporarySession();
    }
}



int GetNbPlayers() {
    auto cp = GetApp().CurrentPlayground;
    return cp is null ? 0 : cp.Players.Length;
}

uint lastPgStartTime = 0;

void AwaitRulesStart() {
    auto app = GetApp();
    while (true) {
        yield();
        auto cp = cast<CSmArenaClient>(app.CurrentPlayground);
        if (cp is null) continue;
        if (cp.GameTerminals.Length == 0) continue;
        if (cp.GameTerminals[0].UISequence_Current != SGamePlaygroundUIConfig::EUISequence::Playing) continue;
        auto player = cast<CSmPlayer>(cp.GameTerminals[0].ControlledPlayer);
        if (player is null) continue;
        auto pgNow = PlaygroundNow();
        if (player.StartTime < 0 || player.StartTime > int(pgNow)) continue;
        if (cp.Arena.Rules.RulesStateStartTime < pgNow) {
            lastPgStartTime = cp.Arena.Rules.RulesStateStartTime;
            trace("set last pg start time: " + lastPgStartTime);
            break;
        }
    }
}

// measured in ms

uint PlaygroundNow() {
    auto app = GetApp();
    auto pg = app.Network.PlaygroundClientScriptAPI;
    if (pg is null) return uint(-1);
    return uint(pg.GameTime);
}

// measured in ms
uint GetRulesStartTime() {
    auto app = GetApp();
    auto cp = cast<CSmArenaClient>(app.CurrentPlayground);
    if (cp is null || cp.Arena is null || cp.Arena.Rules is null) return uint(-1);
    return uint(cp.Arena.Rules.RulesStateStartTime);
}

// measured in ms
uint GetRulesEndTime() {
    auto app = GetApp();
    auto cp = cast<CSmArenaClient>(app.CurrentPlayground);
    if (cp is null || cp.Arena is null || cp.Arena.Rules is null) return uint(-1);
    return uint(cp.Arena.Rules.RulesStateEndTime);
}

SGamePlaygroundUIConfig::EUISequence CurrentUISequence() {
    try {
        auto cp = cast<CSmArenaClient>(GetApp().CurrentPlayground);
        return cp.GameTerminals[0].UISequence_Current;
    } catch {}
    return SGamePlaygroundUIConfig::EUISequence::None;
}

bool IsSequencePlayingOrFinished() {
    auto seq = CurrentUISequence();
    return seq == SGamePlaygroundUIConfig::EUISequence::Playing || seq == SGamePlaygroundUIConfig::EUISequence::Finish;
}

bool IsSequencePlaying() {
    return CurrentUISequence() == SGamePlaygroundUIConfig::EUISequence::Playing;
}

int GetSecondsLeft() {
    return (int64(GetRulesEndTime()) - int64(GetRulesStartTime())) / 1000;
}

string GetMapUid() {
    auto map = GetApp().RootMap;
    return map is null ? "" : map.EdChallengeId;
}

string GetMapName() {
    auto map = GetApp().RootMap;
    return map is null ? "" : string(map.MapName);
}

string GetMedalStringForTime(uint time) {
    auto map = GetApp().RootMap;
    if (map is null) return "No Map";
    if (time <= map.TMObjective_AuthorTime) return "AT";
    if (time <= map.TMObjective_GoldTime) return "Gold";
    if (time <= map.TMObjective_SilverTime) return "Silver";
    if (time <= map.TMObjective_BronzeTime) return "Bronze";
    return "No Medal";
}
Medal GetMedalForTime(uint time) {
    auto map = GetApp().RootMap;
    if (map is null) return Medal::NoMedal;
    if (time <= map.TMObjective_AuthorTime) return Medal::Author;
    if (time <= map.TMObjective_GoldTime) return Medal::Gold;
    if (time <= map.TMObjective_SilverTime) return Medal::Silver;
    if (time <= map.TMObjective_BronzeTime) return Medal::Bronze;
    return Medal::NoMedal;
}

void dev_warn(const string &in msg) {
#if DEV
	log_warn(msg);
#endif
}

void dev_trace(const string &in msg) {
#if DEV
	trace(msg);
#endif
}
