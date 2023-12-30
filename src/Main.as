bool UserHasPermissions = false;

#if DEPENDENCY_BETTERROOMMANAGER || DEV
bool HaveDeps = true;
#else
bool HaveDeps = false;
#endif

StatusMsgUI@ statusMsgs;
int nvgFont = 0;

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
    startnew(MainCoro);
    startnew(ClearTaskCoro);
    startnew(Chat::ChatCoro).WithRunContext(Meta::RunContext::GameLoop);
    startnew(LoadSavedCommands);

    if (!IO::FolderExists(IO::FromStorageFolder("users/"))) {
        IO::CreateFolder(IO::FromStorageFolder("users"));
    }
}

string lastMap;
void MainCoro() {
    while (true) {
        yield();
        if (!ShowWindow) continue;
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
    Chat::ResetState();
}

void Notify(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg);
    log_trace("Notified: " + msg);
}

void NotifyError(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Error", msg, vec4(.9, .3, .1, .3), 15000);
}

void NotifyWarning(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Warning", msg, vec4(.9, .6, .2, .3), 15000);
}

const string PluginIcon = Icons::ListOl;
const string MenuTitle = "\\$000" + PluginIcon + "\\$z " + Meta::ExecutingPlugin().Name;

// show the window immediately upon installation
[Setting hidden]
bool ShowWindow = true;

/** Render function called every frame intended only for menu items in `UI`. */
void RenderMenu() {
    if (UI::MenuItem(MenuTitle, "", ShowWindow)) {
        ShowWindow = !ShowWindow;
    }
}

int MainWindowFlags = UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse;

float lastDt = 1.;
void Update(float dt) {
    lastDt = dt;
}

void Render() {
    if (!ShowWindow) return;
    if (!UI::IsOverlayShown() && !S_ShowIfOverlayHidden) return;
    if (!UI::IsGameUIVisible() && !S_ShowIfUIHidden) return;

    DrawPlayerMedalCounts();
    statusMsgs.RenderUpdate(lastDt);

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



void AddSimpleTooltip(const string &in msg) {
    if (UI::IsItemHovered()) {
        UI::BeginTooltip();
        UI::Text(msg);
        UI::EndTooltip();
    }
}



void OnDestroyed() { _Unload(); }
void OnDisabled() { _Unload(); }
void _Unload() {
    Chat::Unload();
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

string GetMapUid() {
    auto map = GetApp().RootMap;
    return map is null ? "" : map.EdChallengeId;
}

string GetMapName() {
    auto map = GetApp().RootMap;
    return map is null ? "" : string(map.MapName);
}

enum Medal {
    WR = 0, Author = 1, Gold, Silver, Bronze, NoMedal
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
