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
        startnew(WatchForPodium);
    }

    bool podiumWatchRunning = false;
    void WatchForPodium() {
        if (podiumWatchRunning) return;
        podiumWatchRunning = true;
        while (currState != GameState::NotRunning) {
            auto app = GetApp();
            auto cp = cast<CSmArenaClient>(app.CurrentPlayground);
            if (cp !is null && cp.GameTerminals.Length > 0 && cp.GameTerminals[0].UISequence_Current == SGamePlaygroundUIConfig::EUISequence::Podium) {
                OnPodiumSequence();
                // standard podium is 7s
                sleep(15000);
            }
            yield();
        }
        podiumWatchRunning = false;
    }

    void OnPodiumSequence() {
#if DEPENDENCY_MLFEEDRACEDATA
        auto rd = MLFeed::GetRaceData_V4();
        if (rd.SortedPlayers_TimeAttack.Length == 0) return;
        auto bestPlayer = cast<MLFeed::PlayerCpInfo_V4>(rd.SortedPlayers_TimeAttack[0]);
        string msg = "gz " + bestPlayer.Name + " (" + Time::Format(bestPlayer.BestTime) + " - " + GetMedalStringForTime(bestPlayer.BestTime) + ")";
        if (bestPlayer.WebServicesUserId == "a2f0675a-8d25-4db7-9be5-d2ce8902b8cc") { // tyler mayhem
            msg = "Tyler_Mayhem is really cool";
        } else if (bestPlayer.WebServicesUserId == "73fbc796-2a6f-472f-a130-818ab5ee4618") { // lakanta
            msg = "gz Lakanta! Hopefully not last. lakant2Speed lakant2Speed lakant2Speed";
        }
        Chat::SendGoodMessage(msg);
#endif
    }

    // void AwaitNotPodium() {
    //     CGamePlayground@ cp;
    //     while ((@cp = GetApp().CurrentPlayground) !is null) {
    //         if (cp.GameTerminals.Length == 0) return;
    //         if (cp.GameTerminals[0].UISequence_Current)
    //         yield();
    //     }
    // }

    void ResumeGame() {
        clubId = S_ClubID;
        roomId = S_RoomID;
        lastLoadedId = lastTmxId = S_LastTmxID;
        loadNextId = S_LastTmxID;
        currState = GameState::Running;
        auto cp = cast<CSmArenaClient>(GetApp().CurrentPlayground);
        if (cp !is null) startnew(AwaitRulesStart);
        startnew(WatchForPodium);
    }

    void HardReset() {
        currState = GameState::NotRunning;
    }

    // should be called once per frame when necessary
    void CheckStillInServer() {
        if (!_IsStillInServer()) {
            trace("Detected not in server, resetting game state");
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

    void UpdateNextMap() {
        status = "Loading next TMX map...";
        auto resp = MapMonitor::GetNextMapByTMXTrackID(S_LastTmxID);
        lastLoadedId = loadNextId = resp['next'];
        loadNextUid = resp['next_uid'];
        Chat::SendGoodMessage("Next Map ID: " + loadNextId);
    }

    uint lastLoadedId = S_LastTmxID;
    uint loadNextId = S_LastTmxID;
    string loadNextUid;
    void LoadNextTmxMap() {
        currState = GameState::Loading;
        try {
            Chat::SendWarningMessage("Loading Next Map...");
            UpdateNextMap();
            if (!CheckUploadedToNadeo()) {
                Chat::SendWarningMessage("Map not uploaded to Nadeo! Skipping past " + loadNextId);
                LoadNextTmxMap();
                return;
            }
            startnew(InitializeRoom);
        } catch {
            status = "Something went wrong getting the next map! " + getExceptionInfo();
            currState = GameState::Error;
        }
    }

    void SetNextTmxMap() {
        currState = GameState::Loading;
        try {
            Chat::SendWarningMessage("Preparing Next Map...");
            UpdateNextMap();
            if (!CheckUploadedToNadeo()) {
                Chat::SendWarningMessage("Map not uploaded to Nadeo! Skipping past " + loadNextId);
                SetNextTmxMap();
                return;
            }

            auto pgNow = int64(PlaygroundNow());
            auto rulesStart = int64(GetRulesStartTime());
            auto rulesEnd = int64(GetRulesEndTime());
            auto timelimit = (rulesEnd - rulesStart) / 1000;
            // auto timeInMap = pgNow - rulesStart;
            auto timeLeft = (rulesEnd - pgNow);
            auto noTimeLimit = rulesEnd > 2000000000;
            if (timeLeft > 9000) {
                auto pre = Time::Now;
                sleep(timeLeft - 9000);
                timeLeft = timeLeft - (Time::Now - pre);
            }
            timeLeft = Math::Max(6000, timeLeft) - 4500;
            SetNextRoomTA(noTimeLimit ? -1 : timelimit, timeLeft / 1000);
        } catch {
            status = "Something went wrong getting the next map! " + getExceptionInfo();
            currState = GameState::Error;
        }

    }

    void BackToLobby() {
        currState = GameState::Loading;
        try {
            status = "Loading lobby map: " + S_LobbyMapUID;
            startnew(RunBackToLobbyMap);
        } catch {
            status = "Something went wrong returning to lobby map! " + getExceptionInfo();
            currState = GameState::Error;
        }

    }

    bool CheckUploadedToNadeo() {
        auto map = Core::GetMapFromUid(loadNextUid);
        if (map is null) return false;
        // todo: implement caching of map details?
        return true;
    }

    void AutoMoveOn() {
        if (GetApp().CurrentPlayground is null || currState == GameState::Loading) return;
        currState = GameState::Loading;
        Chat::SendWarningMessage("Setting Next Map to load in " + S_AutoMoveOnInSeconds + " seconds.");
        UpdateNextMap();
        if (!CheckUploadedToNadeo()) {
            Chat::SendWarningMessage("Map not uploaded to Nadeo! Skipping past " + loadNextId);
            AutoMoveOn();
            return;
        }
        auto now = PlaygroundNow();
        auto currDuration = (now - GetRulesStartTime()) / 1000;
        trace('AutoMoveOn, Current Map Duration: ' + currDuration);
        auto setTimeout = currDuration + S_AutoMoveOnInSeconds;
        mapTimeLimitWithExt = setTimeout;
        SetNextRoomTA(setTimeout, S_AutoMoveOnInSeconds);
    }

    void InitializeRoom() {
        SetNextRoomTA();
    }

    int lastSetNextMap;
    int mapTimeLimitWithExt = 300;
    void SetNextRoomTA(uint timelimit = 1, uint waitSeconds = 1) {
        int myLastSetNextMap = Time::Now;
        lastSetNextMap = myLastSetNextMap;
        status = "Loading Map " + loadNextId + " / " + loadNextUid;
        auto builder = BRM::CreateRoomBuilder(clubId, roomId)
            .SetTimeLimit(timelimit)
            .SetChatTime(0)
            .SetMaps({loadNextUid})
            .SetLoadingScreenUrl(S_LoadingScreenImageUrl)
            .SetModeSetting("S_DelayBeforeNextMap", "1")
            .SetMode(BRM::GameMode::TimeAttack);

        auto resp = builder.SaveRoom();
        uint waitTime = 5 + waitSeconds;
        status += "\nSaved Room maps + time limit... Waiting " + waitTime + " s";
        log_trace('Room request returned: ' + Json::Write(resp));
        if (waitSeconds > 1) currState = GameState::Running;
        sleep(1000 * waitTime);
        // exit if another set next room has been triggered in the mean time
        if (lastSetNextMap != myLastSetNextMap) return;
        currState = GameState::Loading;
        int limit = S_DefaultTimeLimit;
        mapTimeLimitWithExt = limit;
        builder.SetTimeLimit(limit);
        status = "Adjusting room time limit to " + limit;
        builder.SaveRoom();
        status = "Room finalized, awaiting map change...";
        AwaitMapUidLoad(loadNextUid);
        status = "Done";
        S_LastTmxID = loadNextId;
        Meta::SaveSettings();
        yield();
        currState = GameState::Running;
    }

    void RemoveTimeLimit() {
        ModifyTimeLimit(-1);
    }
    void ExtendTimeLimit() {
        ModifyTimeLimit(S_DefaultTimeLimit < 0 ? 300 : S_DefaultTimeLimit);
    }
    void ModifyTimeLimit(int extraTime) {
        if (mapTimeLimitWithExt < 0) return;
        lastSetNextMap = Time::Now;
        currState = GameState::Loading;
        if (extraTime < 0) {
            mapTimeLimitWithExt = -1;
        } else {
            mapTimeLimitWithExt = (PlaygroundNow() - GetRulesStartTime()) / 1000 + 1 + extraTime;
        }
        status = "Extending time limit to " + mapTimeLimitWithExt + " seconds...";
        auto builder = BRM::CreateRoomBuilder(clubId, roomId)
            .LoadCurrentSettingsAsync()
            .SetTimeLimit(mapTimeLimitWithExt);
        builder.SaveRoom();
        status = "Extended time limit.";
        currState = GameState::Running;
    }

    void RunBackToLobbyMap() {
        lastSetNextMap = Time::Now;
        status = "Loading Map " + S_LobbyMapUID;
        auto builder = BRM::CreateRoomBuilder(clubId, roomId)
            .SetTimeLimit(S_TimeLimitOnEndMap)
            .SetChatTime(0)
            .SetMaps({S_LobbyMapUID})
            .SetLoadingScreenUrl(S_LobbyLoadingScreenImageUrl)
            .SetModeSetting("S_DelayBeforeNextMap", "1")
            .SetMode(BRM::GameMode::TimeAttack);
        auto resp = builder.SaveRoom();
        status += "\nSaved Room maps + time limit... Waiting 5s";
        log_trace('Room request returned: ' + Json::Write(resp));
        sleep(Math::Max(5000, S_TimeLimitOnEndMap * 1000));
        int limit = -1;
        builder.SetTimeLimit(limit);
        status = "Adjusting room time limit to " + limit;
        builder.SaveRoom();
        status = "Room finalized, awaiting map change...";
        AwaitMapUidLoad(S_LobbyMapUID);
        status = "Done";
        currState = GameState::NotRunning;
        return;
    }

    void AwaitMapUidLoad(const string &in uid) {
        auto app = GetApp();
        while (true) {
            yield();
            // we disconnected
            if (app.Network.ClientManiaAppPlayground is null) return;
            // wait for a map
            if (app.RootMap is null) continue;
            // check uid
            if (app.RootMap.EdChallengeId != uid) continue;
            // loaded correct map
            break;
        }
        trace('loaded next map');
    }
}

    // void SetNextRoomRounds() {
    //     status = "Loading Map " + loadNextId + " / " + loadNextUid;
    //     auto builder = BRM::CreateRoomBuilder(clubId, roomId)
    //         .SetTimeLimit(1).SetChatTime(0).SetMaps({loadNextUid})
    //         .SetLoadingScreenUrl(S_LoadingScreenImageUrl)
    //         .SetMode(BRM::GameMode::Teams)
    //         .SetModeSetting("S_PointsRepartition", "12,8,5,3,2,1,1")
    //         .SetModeSetting("S_FinishTimeout", "10")
    //         .SetModeSetting("S_PointsLimit", "1")
    //         .SetModeSetting("S_RoundsPerMap", "1")
    //         .SetModeSetting("S_DelayBeforeNextMap", "1")
    //         // .SetModeSetting("S_RespawnBehaviour", "5")
    //         .SetModeSetting("S_SynchronizePlayersAtRoundStart", "false")
    //         // .SetModeSetting("S_CumulatePoints", "true")
    //         ;
    //     auto resp = builder.SaveRoom();
    //     status += "\nSaved Room maps + time limit... Waiting for next map";
    //     log_trace('Room request returned: ' + Json::Write(resp));
    //     AwaitMapUidLoad(loadNextUid);
    //     sleep(5000);
    //     int limit = -1;
    //     builder.SetTimeLimit(limit)
    //         .SetModeSetting("S_PointsLimit", "100")
    //         .SetModeSetting("S_RoundsPerMap", "-1")
    //         ;
    //     status = "Adjusting room time limit to " + limit;
    //     builder.SaveRoom();
    //     status = "Room finalized, awaiting map change...";
    //     AwaitMapUidLoad(loadNextUid);
    //     status = "Done";
    //     currState = GameState::Running;
    //     S_LastTmxID = loadNextId;
    //     Meta::SaveSettings();
    //     return;
    // }
