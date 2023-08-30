class SetupScreen {
    SetupScreen() {

    }

    string mdInstructions =
        "Join the correct room and then: \n"
        "1. Click Autodetect\n"
        "  a. Alternatively: Enter the ClubID and RoomID for the server\n"
        "2. Set the 'Next TMX Map' to the map you want to load.\n"
        // "3. Set mode options for how you want to advance to the next track.\n"
        ;

    uint wasJoining = 0;

    void Render() {
        SubHeading("Configure TMX Together:");
        if (UI::CollapsingHeader("Instructions")) {
            UI::Indent();
            UI::AlignTextToFramePadding();
            UI::TextWrapped(mdInstructions);
            UI::Unindent();
            UI::Separator();
        }
        S_ClubID = UI::InputInt("Club ID", S_ClubID);
        S_RoomID = UI::InputInt("Room ID", S_RoomID);
        bool inServer = BRM::IsInAServer(GetApp());
        bool badRoom = false;

        if (inServer) {
            auto si = BRM::GetCurrentServerInfo(GetApp(), false);
            bool detected = si !is null && si.clubId == int(S_ClubID) && si.roomId == int(S_RoomID);
            badRoom = si !is null && (si.clubId != int(S_ClubID) || si.roomId != int(S_RoomID));
            if (!detected && !autodetectActive && UI::Button("Autodetect")) {
                startnew(CoroutineFunc(this.StartAutodetect));
            }
            if (detected) {
                UI::Text("\\$8f8You're in this room!");
            } else if (si is null) {
                UI::Text("\\$f80Waiting for room detection...");
            }
            if (autodetectActive || autodetectError) {
                UI::AlignTextToFramePadding();
                UI::TextWrapped(autodetectStatus);
            }
        } else {
            UI::AlignTextToFramePadding();
            UI::Text("\\$f80Please join the server.");
            if (!autodetectActive) {
                UI::SameLine();
                if (Time::Now - wasJoining < 5000) {
                    UI::Text("Joining...");
                } else if (UI::Button("Try joining")) {
                    startnew(CoroutineFunc(OnClickJoinServer));
                }
            } else {
                UI::Text("Joining... (can take up to 15s)");
                wasJoining = Time::Now;
            }
        }
        S_LastTmxID = UI::InputInt("Next TMX ID", S_LastTmxID + 1) - 1;

        // UI::TextWrapped("\\$aaaMode option: only 'host decides' when to move on atm. Other modes like 'first AT' or 'after X minutes' are possible too.");

        if (inServer) {
            if (badRoom) {
                UI::TextWrapped("\\$f80Warning: it does not appear you are in the correct room. In rare cases it's correct to proceed anyway.");
            }
            if (UI::Button("Begin")) {
                State::BeginGame();
            }
        }
    }

    void OnClickJoinServer() {
        try {
            autodetectActive = true;
            autodetectStatus = "Getting join link...";
            BRM::JoinServer(S_ClubID, S_RoomID);
        } catch {
            autodetectError = true;
            autodetectStatus = "Exception joining room: " + getExceptionInfo();
        }
        autodetectActive = false;
    }

    bool autodetectActive = false;
    bool autodetectError = false;
    string autodetectStatus;
    void StartAutodetect() {
        autodetectActive = true;
        autodetectError = false;
        autodetectStatus = "Detecting... ";
        auto cs = BRM::GetCurrentServerInfo(GetApp());
        if (cs is null) {
            AD_Err("Couldn't get current server info");
            return;
        }
        if (cs.clubId <= 0) {
            AD_Err("Could not detect club ID for this server (" + cs.name + " / " + cs.login + ")");
            return;
        }

        autodetectStatus = "Found Club ID: " + cs.clubId;

        auto myClubs = BRM::GetMyClubs();
        const Json::Value@ foundClub = null;

        for (uint i = 0; i < myClubs.Length; i++) {
            if (cs.clubId == int(myClubs[i]['id'])) {
                @foundClub = myClubs[i];
                break;
            }
        }

        if (foundClub is null) {
            AD_Err("Club not found in your list of clubs (refresh from Better Room Manager if you joined the club recently).");
            return;
        }

        if (!bool(foundClub['isAnyAdmin'])) {
            AD_Err("Club was found but your role isn't enough to edit rooms (refresh from Better Room Manager if this changed recently).");
            return;
        }

        autodetectStatus = "Checking for matching rooms...";

        if (cs.roomId <= 0) {
            AD_Err("Room not found in club");
            return;
        }

        S_ClubID = cs.clubId;
        S_RoomID = cs.roomId;

        autodetectStatus = "Done";
        autodetectActive = false;
    }

    void AD_Err(const string &in msg) {
        autodetectStatus = "Error: " + msg;
        autodetectError = true;
        autodetectActive = false;
    }
}
