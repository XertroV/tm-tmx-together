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
