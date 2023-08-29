enum GameState {
    NotRunning,
    Initializing,
    Loading,
    Running,
    Finished,
    Error,
}

enum GameMode {
    HostDecides,
    FirstAT,
}

namespace State {
    GameState currState = GameState::NotRunning;

    uint clubId;
    uint roomId;
    uint lastTmxId;

    string status;

    bool IsNotRunning {
        get {
            return currState == GameState::NotRunning;
        }
    }

    void BeginGame() {
        clubId = S_ClubID;
        roomId = S_RoomID;
        lastTmxId = S_LastTmxID;
        currState = GameState::Initializing;
        startnew(LoadNextTmxMap);
    }

    uint loadNextId;
    string loadNextUid;
    void LoadNextTmxMap() {
        try {
            status = "Loading next TMX map...";
            auto resp = MapMonitor::GetNextMapByTMXTrackID(S_LastTmxID);
            loadNextId = resp['next'];
            loadNextUid = resp['next_uid'];
            startnew(InitializeRoom);
        } catch {
            status = "Something went wrong getting the next map! " + getExceptionInfo();
            currState = GameState::Error;
        }
    }

    void InitializeRoom() {
        BRM::CreateRoomBuilder(clubId, roomId)
            .GoToNextMapAndThenSetTimeLimit(loadNextUid, -1);
    }
}
