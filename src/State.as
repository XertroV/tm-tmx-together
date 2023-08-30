enum GameState {
    NotRunning,
    Initializing,
    Loading,
    Running,
    Finished,
    Error,
}

// Who can trigger the next map -- ::Anyone requires
enum NextMapCondSource {
    Host_Only,
    Anyone,
}

enum NextMapChoice {
    Next_Track_ID,
    MapPack_Next,
    MapPack_Random,
    TMX_Random,
    Unbeaten_ATs_Random,
}

enum NextMapCondTrigger {
    None,
    Medal_AT,
    Medal_Gold,
    Medal_Silver,
    Medal_Bronze,
    Time_Limit,
}

namespace State {
    GameState currState = GameState::NotRunning;

    uint clubId;
    uint roomId;
    uint lastTmxId;

    string status;

    bool get_IsNotRunning() { return currState == GameState::NotRunning; }
    bool get_IsRunning() { return currState == GameState::Running; }
    bool get_IsInitializing() { return currState == GameState::Initializing; }
    bool get_IsLoading() { return currState == GameState::Loading; }
    bool get_IsFinished() { return currState == GameState::Finished; }
    bool get_IsError() { return currState == GameState::Error; }

    void BeginGame() {
        clubId = S_ClubID;
        roomId = S_RoomID;
        lastTmxId = S_LastTmxID;
        currState = GameState::Initializing;
        startnew(LoadNextTmxMap);
    }

    // should be called once per frame when necessary
    void CheckStillInServer() {
        if (!_IsStillInServer()) {
            currState = GameState::NotRunning;
        }
    }

    bool _IsStillInServer() {
        auto app = GetApp();
        if (!BRM::IsInAServer(app)) return false;
        if (app.PlaygroundScript !is null) return false;
        if (app.Editor !is null) return false;
        auto si = BRM::GetCurrentServerInfo(app, false);
        if (si is null) return false;
        return int(clubId) == si.clubId && int(roomId) == si.roomId;
    }

    uint loadNextId;
    string loadNextUid;
    void LoadNextTmxMap() {
        currState = GameState::Loading;
        try {
            status = "Loading next TMX map...";
            auto resp = MapMonitor::GetNextMapByTMXTrackID(S_LastTmxID);
            loadNextId = resp['next'];
            loadNextUid = resp['next_uid'];
            if (!CheckUploadedToNadeo()) {
                LoadNextTmxMap();
                return;
            }
            startnew(InitializeRoom);
        } catch {
            status = "Something went wrong getting the next map! " + getExceptionInfo();
            currState = GameState::Error;
        }
    }

    bool CheckUploadedToNadeo() {
        auto map = Core::GetMapFromUid(loadNextUid);
        if (map is null) return false;
        // todo: implement caching of map details?
        return true;
    }

    void InitializeRoom() {
        SetNextRoom();
    }

    void SetNextRoom() {
        status = "Loading Map " + loadNextId + " / " + loadNextUid;
        auto builder = BRM::CreateRoomBuilder(clubId, roomId)
            .SetTimeLimit(1).SetChatTime(1).SetMaps({loadNextUid})
            .SetMode(BRM::GameMode::TimeAttack);
        auto resp = builder.SaveRoom();
        status += "\nSaved Room maps + time limit... Waiting 5s";
        log_trace('Room request returned: ' + Json::Write(resp));
        sleep(5000);
        int limit = -1;
        builder.SetTimeLimit(limit);
        status = "Adjusting room time limit to " + limit;
        builder.SaveRoom();
        status = "Room finalized, awaiting map change...";
        AwaitMapUidLoad();
        status = "Done";
        currState = GameState::Running;
        S_LastTmxID = loadNextId;
        Meta::SaveSettings();
        return;
    }

    void AwaitMapUidLoad() {
        auto app = GetApp();
        while (true) {
            yield();
            // we disconnected
            if (app.Network.ClientManiaAppPlayground is null) return;
            // wait for a map
            if (app.RootMap is null) continue;
            // check uid
            if (app.RootMap.EdChallengeId != loadNextUid) continue;
            // loaded correct map
            break;
        }
    }
}
