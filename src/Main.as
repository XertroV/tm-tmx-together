bool UserHasPermissions = false;

#if DEPENDENCY_BETTERROOMMANAGER || DEV
bool HaveDeps = true;
#else
bool HaveDeps = false;
#endif

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
    startnew(MainCoro);
    startnew(ClearTaskCoro);
}

void MainCoro() {
    while (true) {
        yield();
    }
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

void Render() {
    if (!ShowWindow) return;
    if (!UI::IsOverlayShown() && !S_ShowIfOverlayHidden) return;
    if (!UI::IsGameUIVisible() && !S_ShowIfUIHidden) return;
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
