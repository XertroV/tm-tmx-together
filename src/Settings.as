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

[Setting category="General" name="Log Level"]
#if SIG_DEVELOPER
LogLevel S_LogLevel = LogLevel::Trace;
#else
LogLevel S_LogLevel = LogLevel::Info;
#endif
