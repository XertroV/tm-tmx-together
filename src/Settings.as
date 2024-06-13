[Setting category="General" name="Club ID"]
uint S_ClubID = 0;

[Setting category="General" name="Room ID"]
uint S_RoomID = 0;

[Setting category="General" name="Last TMX ID"]
uint S_LastTmxID = 0;

[Setting category="General" name="Maintain Club News Activity" description="Enables public scoreboard on loading screen if users install the Server-Game Scoreboard plugin"]
bool S_MaintainClubNewsActivity = true;

// todo: need to track time spent in map to set this accurately.
// [Setting category="General" name="Set TimeLimit on Ending Map (s)" min=1 max=120]
int S_TimeLimitOnEndMap = 1;

[Setting category="General" name="Default TimeLimit each Map (s); -1 for infinite"]
int S_DefaultTimeLimit = 300;

[Setting category="General" name="Lobby Map UID"]
string S_LobbyMapUID = "9ZmfOvlHBXddVLngtdfnRGaIunc";

// todo: add new loading screens from https://imgur.com/a/uGgA05z
[Setting category="General" name="Loading Screen Image URL"]
string S_LoadingScreenImageUrl = "https://i.imgur.com/R9zM2Uf.jpeg, https://i.imgur.com/GbFCdgb.jpeg, https://i.imgur.com/AoCTpkF.jpeg";

[Setting category="General" name="Lobby Loading Screen Image URL"]
string S_LobbyLoadingScreenImageUrl = "https://i.imgur.com/xEqv5fr.png";

[Setting category="General" name="Font Size"]
FontSize S_FontSize = FontSize::S16;

enum FontSize {
    S16 = 0, S16_Bold = 1, S20, S26
}


[Setting category="General" name="Automatically Move On When Everyone Votes 1"]
bool S_AutoMoveOnWhenAll1s = true;

[Setting category="General" name="Automatic move on timer seconds" min=0 max=240]
uint S_AutoMoveOnInSeconds = 120;

[Setting category="General" name="Where possible, move on in AT time + 10 seconds (overrides above)"]
bool S_AutoMoveOnBasedOnAT = false;

[Setting category="General" name="Automatically move on when someone gets WR"]
bool S_AutoMoveOnForWR = true;



[Setting category="Status Messages" name="Show Vote Msgs on Screen"]
bool S_ShowVotesOnScreen = true;

[Setting category="Status Messages" name="Send Chat Update Messages"]
bool S_SendChatUpdateMsgs = true;


[SettingsTab name="Utilities" order="10"]
void Render_S_Utils() {
    UI::BeginDisabled(LoadingMedalCounts);
    if (UI::Button("Purge Players with 0 medals")) {
        startnew(PurgePlayersWith0Medals);
    }
    UI::EndDisabled();
}


void PurgePlayersWith0Medals() {
    LoadingMedalCounts = true;
    PlayerMedalCount@ player;
    uint nbDelted = 0;
    for (int i = State::SortedPlayerMedals.Length - 1; i >= 0; i--) {
        @player = State::SortedPlayerMedals[i];
        if (player.NbLifeMedalsTotal == 0) {
            warn("removing: " + player.login + " / " + player.name);
            State::DeletePMC(player);
            sleep(0);
            nbDelted++;
        }
    }
    NotifyWarning("Deleted " + nbDelted + " players with 0 medals");
    LoadingMedalCounts = false;
}


#if DEV
bool dev_showScoreboard = false;

[SettingsTab name="Debug" order="99"]
void Render_Settings_DevTab() {
    if (UI::Button("Load ALL player medal counts")) {
        startnew(LoadAllPlayerMedalCounts);
    }

    if (UI::Button("Load just GOAT player medal counts")) {
        startnew(LoadGOATPlayerMedalCounts);
    }

    dev_showScoreboard = UI::Checkbox("Show scoreboard", dev_showScoreboard);
    if (dev_showScoreboard) g_LastLoadingScreen = Time::Now - 2900;

    if (UI::Button("Test GetWSIDToCustomMessage")) {
        Notify("Xert msg: " + GetWSIDToCustomMessage(XertroV_WSID));
    }

    UI::AlignTextToFramePadding();
    UI::Text("Curr State: " + tostring(State::currState));

    if (UI::Button("Set State Running")) {
        State::currState = GameState::Running;
    }

    if (UI::Button("Set State Not Running")) {
        State::currState = GameState::NotRunning;
    }
}
#endif
