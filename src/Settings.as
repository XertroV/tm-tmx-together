[Setting category="General" name="Show when the Openplanet interface is hidden"]
bool S_ShowIfOverlayHidden = true;

[Setting category="General" name="Show when the game UI is hidden"]
bool S_ShowIfUIHidden = true;

[Setting category="General" name="Club ID"]
uint S_ClubID = 0;

[Setting category="General" name="Room ID"]
uint S_RoomID = 0;

[Setting category="General" name="Last TMX ID"]
uint S_LastTmxID = 0;

// todo: need to track time spent in map to set this accurately.
// [Setting category="General" name="Set TimeLimit on Ending Map (s)" min=1 max=120]
int S_TimeLimitOnEndMap = 1;

[Setting category="General" name="Default TimeLimit each Map (s); -1 for infinite"]
int S_DefaultTimeLimit = 300;

[Setting category="General" name="Lobby Map UID"]
string S_LobbyMapUID = "9ZmfOvlHBXddVLngtdfnRGaIunc";

[Setting category="General" name="Loading Screen Image URL"]
string S_LoadingScreenImageUrl = "https://i.imgur.com/xEqv5fr.png";

[Setting category="General" name="Lobby Loading Screen Image URL"]
string S_LobbyLoadingScreenImageUrl = "https://i.imgur.com/xEqv5fr.png";

[Setting category="General" name="Font Size"]
FontSize S_FontSize = FontSize::S16;

enum FontSize {
    S16 = 0, S16_Bold = 1, S20, S26
}

[Setting category="General" name="Log Level"]
#if SIG_DEVELOPER
LogLevel S_LogLevel = LogLevel::Trace;
#else
LogLevel S_LogLevel = LogLevel::Info;
#endif

[Setting category="General" name="Automatically Move On When Everyone Votes 1"]
bool S_AutoMoveOnWhenAll1s = true;

[Setting category="General" name="Automatically Move On In (seconds)" min=0 max=240]
uint S_AutoMoveOnInSeconds = 120;

[Setting category="General" name="Where possible, move on in AT time + 10 seconds (overrides above)"]
bool S_AutoMoveOnBasedOnAT = false;


[Setting category="Status Messages" name="Show Vote Msgs on Screen"]
bool S_ShowVotesOnScreen = true;

[Setting category="Status Messages" name="Send Chat Update Messages"]
bool S_SendChatUpdateMsgs = true;





#if DEV
bool dev_showScoreboard = false;

[SettingsTab name="Debug" order="99"]
void Render_Settings_DevTab() {
    if (UI::Button("Load ALL player medal counts")) {
        LoadAllPlayerMedalCounts();
    }

    if (UI::Button("Load just GOAT player medal counts")) {
        LoadGOATPlayerMedalCounts();
    }

    dev_showScoreboard = UI::Checkbox("Show scoreboard", dev_showScoreboard);
    if (dev_showScoreboard) g_LastLoadingScreen = Time::Now - 2900;
}
#endif
