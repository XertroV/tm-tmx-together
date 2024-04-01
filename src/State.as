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
    const string sessionSaveFile = IO::FromStorageFolder("session.json");
    const string sessionOldSaveFile = IO::FromStorageFolder("session-old.json");

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
        StartCoros();
    }

    void StartCoros() {
        startnew(WatchForPodium);
        startnew(WatchForWR);
        startnew(WatchForNewPlayers);
    }

    bool newPlayerWatchRunning = false;
    uint lastNbPlayers = 0;
    void WatchForNewPlayers() {
        if (newPlayerWatchRunning) return;
        newPlayerWatchRunning = true;
        while (currState != GameState::NotRunning) {
            auto rd = MLFeed::GetRaceData_V4();
            auto newNbPlayers = rd.SortedPlayers_TimeAttack.Length;
            if (newNbPlayers != lastNbPlayers) {
                CheckForNewPlayers();
                lastNbPlayers = newNbPlayers;
            }
            yield();
        }
        newPlayerWatchRunning = false;
    }

    void CheckForNewPlayers() {
        auto rd = MLFeed::GetRaceData_V4();
        auto @taPlayers = rd.SortedPlayers_TimeAttack;
        for (int i = int(taPlayers.Length) - 1; i >= int(lastNbPlayers); i--) {
            auto p = cast<MLFeed::PlayerCpInfo_V4>(taPlayers[i]);
            if (!IsPMCLoaded(p.Login) || (ENABLE_DEV_WELCOME && p.Name == "XertroV")) {
                OnNewPlayer(p);
                break;
            }
        }
    }

    void OnNewPlayer(const MLFeed::PlayerCpInfo_V4@ p) {
        AddNewPMC(p.Name, p.Login);
        Chat::SendMessage(S_WelcomeMessage.Replace("{player_name}", p.Name));
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

    bool wrWatchRunning = false;
    void WatchForWR() {
        if (wrWatchRunning) return;
        wrWatchRunning = true;
        string wrMapUid;
        while (currState != GameState::NotRunning) {
            sleep(500);
            if (!S_AutoMoveOnForWR) continue;
            auto app = GetApp();
            if (app.RootMap is null) continue;
            // if (triggeredAuto120 && wrMapUid == lastMap) continue;
            auto rd = MLFeed::GetRaceData_V4();
            auto @players = rd.SortedPlayers_TimeAttack;
            if (players.Length == 0) continue;
            if (!IsSequencePlayingOrFinished()) continue;
            auto bestPlayer = cast<MLFeed::PlayerCpInfo_V4>(players[0]);
            bool playerGotWR = IsPlayerTimeWR(bestPlayer.BestTime, bestPlayer.WebServicesUserId)
                && bestPlayer.BestTime < (rd.Rules_GameTime - rd.Rules_StartTime)
                && rd.Rules_StartTime < 200000000;
            if (playerGotWR) {
                Notify("detected player WR: " + bestPlayer.Name + ", " + bestPlayer.BestTime + ", wr: " + wrTime);
                wrMapUid = lastMap;
                Chat::SendMessage("$s$o$f5b"+Icons::Star+" WR by " + bestPlayer.Name + "! BWOAH");
                yield();
                auto timeLeft = GetSecondsLeft();
                Notify("WR timeleft check: if " + timeLeft + " > " + S_AutoMoveOnInSeconds + " then move on.");
                if (timeLeft > int(S_AutoMoveOnInSeconds)) {
                    if (currState == GameState::Loading) {
                        Notify("Waiting for loading to finish before auto moving on.");
                        while (currState == GameState::Loading) yield();
                    }
                    startnew(State::AutoMoveOn);
                }
                while (wrMapUid == lastMap) yield();
                sleep(15000);
            }
        }
        wrWatchRunning = false;
    }

    dictionary PlayerMedalCounts;

#if DEPENDENCY_MLFEEDRACEDATA
    void OnPodiumSequence() {
        auto rd = MLFeed::GetRaceData_V4();
        if (rd.SortedPlayers_TimeAttack.Length == 0) return;
        auto bestPlayer = cast<MLFeed::PlayerCpInfo_V4>(rd.SortedPlayers_TimeAttack[0]);
        bool isWR = IsPlayerTimeWR(bestPlayer.BestTime, bestPlayer.WebServicesUserId);
        auto medalStr = isWR ? "$<$f19$oWorld Record!!!$>" : GetMedalStringForTime(bestPlayer.BestTime);
        string msg = "gz " + bestPlayer.Name + " (" + Time::Format(bestPlayer.BestTime) + " - " + medalStr + ")";
        string m = GetWSIDToCustomMessage(bestPlayer.WebServicesUserId);
        if (m.Length > 0) {
            msg += " " + m;
        } else if (bestPlayer.WebServicesUserId == Tyler_WSID) { // tyler mayhem
            msg += (" $f19 Tyler_Mayhem is really cool");
        } else if (bestPlayer.WebServicesUserId == Lakanta_WSID) { // lakanta
            msg += (" $7f7 gz Lakanta! Hopefully not last. lakant2Speed lakant2Speed lakant2Speed");
        } else if (bestPlayer.WebServicesUserId == XertroV_WSID) { // xertrov
            msg += " $aaa$iShirley not rigged.";
        } else if (bestPlayer.WebServicesUserId == Noimad_WSID) {
            msg += " $S$229BEDGE";
        } else if (bestPlayer.WebServicesUserId == Kora_WSID) {
            msg += " $zWas there a cut?";
        }
        Chat::SendGoodMessage(msg);
        CachePlayerMedals(rd);
    }
#else
    void OnPodiumSequence() {}
#endif

    bool IsPMCLoaded(const string &in login) {
        return PlayerMedalCounts.Exists(login);
    }

    PlayerMedalCount@ GetPlayerMedalCountFor(const string &in name, const string &in login) {
        if (PlayerMedalCounts.Exists(login)) {
            return cast<PlayerMedalCount>(PlayerMedalCounts[login]);
        }
        return AddNewPMC(name, login);
    }

    // can return null
    PlayerMedalCount@ FindPlayerMedalCountFor(const string &in login) {
        if (PlayerMedalCounts.Exists(login)) {
            return cast<PlayerMedalCount>(PlayerMedalCounts[login]);
        }
        return null;
    }

    void CachePlayerMedals(const MLFeed::HookRaceStatsEventsBase_V4@ rd) {
        for (uint i = 0; i < rd.SortedPlayers_TimeAttack.Length; i++) {
            auto player = cast<MLFeed::PlayerCpInfo_V4>(rd.SortedPlayers_TimeAttack[i]);
            if (!PlayerMedalCounts.Exists(player.Login)) {
                AddNewPMC(player.Name, player.Login);
            }
            auto pmc = cast<PlayerMedalCount>(PlayerMedalCounts[player.Login]);
            if (pmc is null) continue;
            // todo: check if WR, if so, add to medal 0
            auto playerTime = player.BestTime;
            if (i == 0 && IsPlayerTimeWR(playerTime, player.WebServicesUserId) && !wrError) {
                pmc.AddMedal(Medal::WR);
            } else {
                pmc.AddMedal(GetMedalForTime(uint(player.bestTime)));
            }
        }
        startnew(UpdateSortedPlayerMedals);
    }

    // only checks if better than WR for curr map
    bool IsPlayerTimeWR(int playerTime, const string &in wsid = "default-no-match-existing") {
        bool isTimeLt = playerTime < wrTime || (playerTime == wrTime && wrAcct == wsid);
        return playerTime > 0 && (isTimeLt || wrTime < 0) && wrUid == lastMap && wrHasLoaded;
    }

    PlayerMedalCount@ AddNewPMC(const string &in name, const string &in login) {
        if (PlayerMedalCounts.Exists(login)) return GetPlayerMedalCountFor(name, login);
        auto pmc = PlayerMedalCount(name, login);
        return _Internal_AddPMC(pmc);
    }

    PlayerMedalCount@ LoadPMC(const string &in filepath) {
        auto j = Json::FromFile(filepath);
        if (j is null) throw("no such file: " + filepath);
        try {
            string login = j['login'];
            if (IsPMCLoaded(login)) return cast<PlayerMedalCount>(PlayerMedalCounts[login]);
            auto pmc = PlayerMedalCount(IO::FileMode::Read, login);
            return _Internal_AddPMC(pmc);
        } catch {
            status = "Exception: " + getExceptionInfo() + " \n Loading: " + filepath;
            NotifyError(status);
            currState = GameState::Error;
        }
        return null;
    }

    PlayerMedalCount@ _Internal_AddPMC(PlayerMedalCount@ pmc) {
        @PlayerMedalCounts[pmc.login] = pmc;
        SortedPlayerMedals.InsertLast(pmc);
        GOATPlayerMedals.InsertLast(pmc);
        NewestPlayerMedals.InsertAt(0, pmc);
        return pmc;
    }

    PlayerMedalCount@[] SortedPlayerMedals;
    PlayerMedalCount@[] NewestPlayerMedals;
    PlayerMedalCount@[] GOATPlayerMedals;

    void UpdateSortedPlayerMedals() {
        if (SortedPlayerMedals.Length == 0) return;
        SortedPlayerMedals.SortNonConst(function(PlayerMedalCount@ &in a, PlayerMedalCount@ &in b) {
            if (a.NbWRs != b.NbWRs) return a.NbWRs > b.NbWRs;
            if (a.NbATs != b.NbATs) return a.NbATs > b.NbATs;
            if (a.NbGolds != b.NbGolds) return a.NbGolds > b.NbGolds;
            if (a.NbSilvers != b.NbSilvers) return a.NbSilvers > b.NbSilvers;
            if (a.NbBronzes != b.NbBronzes) return a.NbBronzes > b.NbBronzes;
            if (a.NbNoMedals != b.NbNoMedals) return a.NbNoMedals > b.NbNoMedals;
            if (a.mapCount != b.mapCount) return a.mapCount > b.mapCount;
            return true;
        });
        GOATPlayerMedals.SortNonConst(function(PlayerMedalCount@ &in a, PlayerMedalCount@ &in b) {
            if (a.NbLifeWRs != b.NbLifeWRs) return a.NbLifeWRs > b.NbLifeWRs;
            if (a.NbLifeATs != b.NbLifeATs) return a.NbLifeATs > b.NbLifeATs;
            if (a.NbLifeGolds != b.NbLifeGolds) return a.NbLifeGolds > b.NbLifeGolds;
            if (a.NbLifeSilvers != b.NbLifeSilvers) return a.NbLifeSilvers > b.NbLifeSilvers;
            if (a.NbLifeBronzes != b.NbLifeBronzes) return a.NbLifeBronzes > b.NbLifeBronzes;
            if (a.NbLifeNoMedals != b.NbLifeNoMedals) return a.NbLifeNoMedals > b.NbLifeNoMedals;
            if (a.mapCount != b.mapCount) return a.mapCount > b.mapCount;
            return true;
        });
    }

    string BestMedalsSummaryStr() {
        int nb = Math::Min(5, SortedPlayerMedals.Length);
        string ret = "Top 5: ";
        for (int i = 0; i < nb; i++) {
            if (i > 0) ret += ", ";
            ret += tostring(i + 1) + ". " + SortedPlayerMedals[i].GetSummaryStr();
        }
        return ret;
    }
    string GoatSummaryStr() {
        int nb = Math::Min(5, GOATPlayerMedals.Length);
        string ret = "GOATs: ";
        for (int i = 0; i < nb; i++) {
            if (i > 0) ret += ", ";
            ret += tostring(i + 1) + ". " + GOATPlayerMedals[i].GetLifetimeSummaryStr(true);
        }
        return ret;
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
        StartCoros();
    }

    void HardReset() {
        currState = GameState::NotRunning;
        startnew(LoadAllPlayerMedalCounts);
    }

    // should be called once per frame when necessary
    void CheckStillInServer() {
#if DEV
        return;
#endif
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
                yield();
                Chat::SendWarningMessage("Map not uploaded to Nadeo! Skipping past " + loadNextId);
                S_LastTmxID = loadNextId;
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
                Chat::SendWarningMessage("Map not uploaded to Nadeo! Cannot load " + loadNextId + ". Trying next in 5s.");
                sleep(5000);
                S_LastTmxID = loadNextId;
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
        status = "Checking uploaded to Nadeo...";
        auto map = Core::GetMapFromUid(loadNextUid);
        if (map is null) return false;
        // todo: implement caching of map details?
        return true;
    }

    void AutoMoveOn() {
        if (GetApp().CurrentPlayground is null || currState == GameState::Loading) return;
        currState = GameState::Loading;
        auto moveOnIn = S_AutoMoveOnInSeconds;
        if (S_AutoMoveOnBasedOnAT) {
            try {
                moveOnIn = (GetApp().RootMap.ChallengeParameters.AuthorScore / 1000 + 11);
            } catch {
                NotifyWarning("Failed to get AT time for move on, defaulting to " + moveOnIn + ' seconds');
            }
        }
        Chat::SendWarningMessage("Setting Next Map to load in " + moveOnIn + " seconds.");
        UpdateNextMap();
        if (!CheckUploadedToNadeo()) {
            Chat::SendWarningMessage("Map not uploaded to Nadeo! Skipping past " + loadNextId);
            S_LastTmxID = loadNextId;
            currState = GameState::Running;
            sleep(5000);
            AutoMoveOn();
            return;
        }
        auto now = PlaygroundNow();
        auto currDuration = (now - GetRulesStartTime()) / 1000;
        trace('AutoMoveOn, Current Map Duration: ' + currDuration);
        auto setTimeout = currDuration + moveOnIn;
        mapTimeLimitWithExt = setTimeout;
        SetNextRoomTA(setTimeout, moveOnIn);
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

    uint lastExtendLimit = 0;
    void RemoveTimeLimit() {
        lastExtendLimit = Time::Now;
        ModifyTimeLimit(-1);
    }
    void ExtendTimeLimit() {
        lastExtendLimit = Time::Now;
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

    string wrUid;
    string wrAcct;
    int wrTime;
    bool wrError = false;
    bool wrHasLoaded = false;

    void TryGettingWR() {
        // try getting the WR for this map
        ResetWR();
        try {
            auto j = Live::GetMapRecordsMeat("Personal_Best", lastMap);
            if (j.Length > 0) {
                wrTime = j[0]['score'];
                wrAcct = j[0]['accountId'];
                trace("WR time: " + wrTime);
            } else {
                trace("No WR time");
            }
            wrHasLoaded = true;
            wrUid = lastMap;
        } catch {
            NotifyError("Exception updating WR for this map: " + getExceptionInfo());
            wrError = true;
        }
    }

    void ResetWR() {
        wrUid = "nil";
        wrAcct = "";
        wrTime = -1;
        wrError = false;
        wrHasLoaded = false;
    }

    void PersistTemporarySession() {
        // save session data to file
        auto j = Json::Object();
        auto list = Json::Array();
        for (uint i = 0; i < SortedPlayerMedals.Length; i++) {
            auto p = SortedPlayerMedals[i];
            if (p.mapCountSession == 0) continue;
            list.Add(SortedPlayerMedals[i].SessionSummaryForSaving());
        }
        if (list.Length == 0) {
            // there was nothing to save. exit to avoid overwriting file during dev.
            return;
        }
        j['scores'] = list;
        j['ts'] = Time::Stamp;
        j['mapId'] = S_LastTmxID;
        Json::ToFile(sessionSaveFile, j);
    }

    void TryRestoringSessionData() {
        if (IO::FileExists(sessionSaveFile)) {
            trace('trying to restore from session (save file exists)');
            auto j = Json::FromFile(sessionSaveFile);
            try {
                int64 saveTs = j['ts'];
                int mapId = j['mapId'];
                auto scores = j['scores'];
                if (saveTs + 300 > Time::Stamp) {
                    for (uint i = 0; i < scores.Length; i++) {
                        auto item = scores[i];
                        string name = item['name'];
                        string login = item['login'];
                        auto pmc = GetPlayerMedalCountFor(name, login);
                        pmc.LoadFromSessionSummary(item);
                    }
                } else {
                    NotifyWarning("Found session save file but not restoring as it was created more than 5 minutes ago.");
                }
                if (IO::FileExists(sessionOldSaveFile)) IO::Delete(sessionOldSaveFile);
                IO::Move(sessionSaveFile, sessionOldSaveFile);
            } catch {
                NotifyError("Exception while restoring session save file: " + getExceptionInfo());
            }
        }
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


auto pmcPad = vec2(15., 5.);

class PlayerMedalCount {
    string name;
    string login;
    uint[] medalCounts = {0, 0, 0, 0, 0, 0};
    uint[] lifetimeMedalCounts = {0, 0, 0, 0, 0, 0};
    uint mapCount = 0;
    uint mapCountSession = 0;
    vec4 col = vec4(1);
    uint firstSeen;
    uint lastSeen;
    string filename;

    PlayerMedalCount(const string &in name, const string &in login) {
        this.name = name;
        this.login = login;
        firstSeen = Time::Stamp;
        lastSeen = firstSeen;
        SetFilepathFromLogin();
        FromJsonFile();
    }

    // This constructer is here to load from a json file, the IO::FileMode makes this obvious but isn't used otherwise
    PlayerMedalCount(IO::FileMode _modeCheck, const string &in login) {
        if (login.Contains(".")) throw("dont pass file path");
        this.login = login;
        SetFilepathFromLogin();
        auto j = FromJsonFile();
        if (j is null) throw("could not load saved PMC for " + login);
        this.name = j['name'];
    }

    void SetFilepathFromLogin() {
        this.filename = IO::FromStorageFolder("users/" + login + ".json");
    }

    Json::Value@ ToJson() {
        auto ret = Json::Object();
        ret['name'] = name;
        ret['login'] = login;
        ret['medals'] = lifetimeMedalCounts.ToJson();
        ret['mapCount'] = mapCount;
        ret['firstSeen'] = firstSeen;
        ret['lastSeen'] = lastSeen;
        return ret;
    }

    void ToJsonFile() {
        Json::ToFile(filename, ToJson());
    }

    Json::Value@ FromJson(Json::Value@ j) {
        if (j.GetType() != Json::Type::Object) throw('not a json obj');
        mapCount = j['mapCount'];
        lastSeen = j['lastSeen'];
        firstSeen = j['firstSeen'];
        mapCount = j['mapCount'];
        auto mc = j['medals'];
        for (uint i = 0; i < mc.Length; i++) {
            if (i >= lifetimeMedalCounts.Length) lifetimeMedalCounts.InsertLast(mc[i]);
            else lifetimeMedalCounts[i] = mc[i];
        }
        if (bool(j.Get('customName', false))) {
            name = j['name'];
        }
        return j;
    }

    Json::Value@ FromJsonFile() {
        if (!IO::FileExists(filename)) {
            return null;
        }
        auto j = Json::FromFile(filename);
        return FromJson(j);
    }

    Json::Value@ SessionSummaryForSaving() {
        auto j = Json::Object();
        j['name'] = name;
        j['login'] = login;
        j['medals'] = this.medalCounts.ToJson();
        j['maps'] = mapCountSession;
        return j;
    }

    void LoadFromSessionSummary(Json::Value@ j) {
        mapCountSession = j['maps'];
        for (uint i = 0; i < j['medals'].Length; i++) {
            medalCounts[i] = j['medals'][i];
        }
    }

    uint get_NbWRs() {
        return medalCounts[0];
    }
    uint get_NbATs() {
        return medalCounts[1];
    }
    uint get_NbGolds() {
        return medalCounts[2];
    }
    uint get_NbSilvers() {
        return medalCounts[3];
    }
    uint get_NbBronzes() {
        return medalCounts[4];
    }
    uint get_NbNoMedals() {
        return medalCounts[5];
    }

    uint get_NbLifeWRs() {
        return lifetimeMedalCounts[0];
    }
    uint get_NbLifeATs() {
        return lifetimeMedalCounts[1];
    }
    uint get_NbLifeGolds() {
        return lifetimeMedalCounts[2];
    }
    uint get_NbLifeSilvers() {
        return lifetimeMedalCounts[3];
    }
    uint get_NbLifeBronzes() {
        return lifetimeMedalCounts[4];
    }
    uint get_NbLifeNoMedals() {
        return lifetimeMedalCounts[5];
    }

    void AddMedal(Medal m) {
        mapCount++;
        mapCountSession++;
        medalCounts[int(m)]++;
        lifetimeMedalCounts[int(m)]++;
        lastSeen = Time::Stamp;
        startnew(CoroutineFunc(ToJsonFile));
    }

    string GetSummaryStr() {
        return GenerateSummaryStr(medalCounts);
    }
    string GetLifetimeSummaryStr(bool useName) {
        return GenerateSummaryStr(lifetimeMedalCounts, useName ? name + ":" : "All Time:");
    }

    string GenerateSummaryStr(uint[]@ mc, const string &in nameReplacement = "") {
        return "{name} ( $<$o$<$f19{wr}$> / $<$8f4{at}$> / $<$fd0{gold}$> / $<$abb{silver}$> / $<$c73{bronze}$> / $<$fff{noMedal}$>$> )"
            .Replace("{name}", nameReplacement.Length == 0 ? name : nameReplacement)
            .Replace("{wr}", tostring(mc[0]))
            .Replace("{at}", tostring(mc[1]))
            .Replace("{gold}", tostring(mc[2]))
            .Replace("{silver}", tostring(mc[3]))
            .Replace("{bronze}", tostring(mc[4]))
            .Replace("{noMedal}", tostring(mc[5]))
        ;
    }

    void Draw(vec2 &in pos, float nameWidth, float medalSpacing, float fontSize, float alpha = 1.0) {
        nvg::BeginPath();
        nvg::FontSize(fontSize);
        nvg::TextAlign(nvg::Align::Left | nvg::Align::Top);

        nvg::FillColor(vec4(0, 0, 0, 0.7 * alpha));
        vec2 bounds = vec2(nameWidth + medalSpacing * (medalCounts.Length + 1), pmcPad.y * 2. + fontSize);
        nvg::Rect(pos - vec2(0, 2), bounds + pmcPad * 2.);
        nvg::Fill();
        nvg::FillColor(col * vec4(1, 1, 1, alpha));
        nvg::Text(pos + pmcPad, name);
        auto medalStart = pos + pmcPad + vec2(nameWidth, 0);
        for (uint i = 0; i < medalCounts.Length; i++) {
            nvg::Text(medalStart + vec2(medalSpacing * float(i), 0), tostring(medalCounts[i]));
        }
        nvg::Text(medalStart + vec2(medalSpacing * float(medalCounts.Length), 0), tostring(mapCount));
        nvg::ClosePath();
    }

    void DrawCompact(uint rank, vec2 &in pos, float nameWidth, float medalSpacing, float fontSize, float alpha = 1.0, uint[]@ mc = null, bool lifetimeMapCount = false) {
        if (mc is null) @mc = medalCounts;

        auto textOffset = vec2(0, fontSize * .15);
        nvg::BeginPath();
        nvg::FontSize(fontSize);
        nvg::TextAlign(nvg::Align::Left | nvg::Align::Top);
        auto textBounds = nvg::TextBounds(name);

        float xScale = textBounds.x > nameWidth ? Math::Max(0.1, nameWidth / textBounds.x) : 1;

        nvg::FillColor(vec4(0, 0, 0, 0.7 * alpha));
        vec2 bounds = vec2(nameWidth + medalSpacing * (nbMedalsToDraw + 1), pmcPad.y * 2. + fontSize);
        nvg::Rect(pos - vec2(0, 2), bounds + pmcPad * 2.);
        nvg::Fill();
        nvg::FillColor(col * vec4(1, 1, 1, alpha));

        nvg::Scale(vec2(xScale, 1));
        nvg::Text((pos + pmcPad + textOffset) * vec2(1. / xScale, 1.), tostring(rank) + ". " + name);
        nvg::Scale(vec2(1. / xScale, 1));

        auto medalStart = pos + pmcPad + vec2(nameWidth, 0);

        for (uint i = 0; i < nbMedalsToDraw; i++) {
            auto c = mc[i];
            auto fs = c < 100 ? fontSize : c < 1000 ? fontSize * .8 : fontSize * .6;
            auto hOff = c < 100 ? 0. : c < 1000 ? fontSize * .1 : fontSize * .2;
            nvg::FontSize(fs);
            nvg::FillColor(medalColors[i] * vec4(1, 1, 1, alpha));
            nvg::Text(medalStart + vec2(medalSpacing * float(i), hOff) + textOffset, tostring(mc[i]));
        }
        auto hOff = mapCount < 1000 ? 0 : fontSize * .15;
        auto fs = mapCount < 1000 ? fontSize : fontSize * .7;
        nvg::FontSize(fs);
        nvg::FillColor(col * vec4(1, 1, 1, alpha));
        nvg::Text(medalStart + vec2(medalSpacing * float(nbMedalsToDraw), hOff) + textOffset, tostring(lifetimeMapCount ? mapCount : mapCountSession));
        nvg::ClosePath();
    }

    void DrawCompactLifeTime(uint rank, vec2 &in pos, float nameWidth, float medalSpacing, float fontSize, float alpha = 1.0) {
        DrawCompact(rank, pos, nameWidth, medalSpacing, fontSize, alpha, lifetimeMedalCounts, true);
    }
}

vec4[] medalColors = {
    vec4(240. / 255., 19. / 255., 90. / 255., 1),
    vec4(0.204f, 0.842f, 0.052f, 1.000f),
    vec4(0.942f, 0.854f, 0.033f, 1.000f),
    vec4(0.626f, 0.705f, 0.761f, 1.000f),
    vec4(0.687f, 0.423f, 0.122f, 1.000f),
    vec4(1, 1, 1, 1),
    vec4(1, 1, 1, 1),
    vec4(1, 1, 1, 1),
};






/// Some dev stuff


void LoadAllPlayerMedalCounts() {
    auto usersFolder = IO::FromStorageFolder("users/");
    auto files = IO::IndexFolder(usersFolder, false);
    Notify("Loading " + files.Length + " player medal counts.");
    for (uint i = 0; i < files.Length; i++) {
        if (!files[i].EndsWith(".json")) continue;
        State::LoadPMC(files[i]);
        if (i % 100 == 0) {
            Notify("Loaded " + (i + 1) + " / " + files.Length);
        }
        yield();
    }
    yield();
    State::UpdateSortedPlayerMedals();
}

void LoadGOATPlayerMedalCounts() {
    // todo if we need to
    LoadAllPlayerMedalCounts();
}
