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

// 2024 updated to "7 336 960 octets total size"
const uint MAP_LIMIT_OCTETS = 7336960;

namespace TmxTogetherState {
    bool get_IsNotRunning() { return State::IsNotRunning; }
    bool get_IsRunning() { return State::IsRunning; }
    bool get_IsInitializing() { return State::IsInitializing; }
    bool get_IsLoading() { return State::IsLoading; }
    bool get_IsFinished() { return State::IsFinished; }
    bool get_IsError() { return State::IsError; }
}

namespace State {
    GameState currState = GameState::NotRunning;
    // tracks lifetime streak counters (lobby win streak, WR streak)
    const string streaksFile = IO::FromStorageFolder("streaks.json");
    const string sessionSaveFile = IO::FromStorageFolder("session.json");
    const string sessionOldSaveFile = IO::FromStorageFolder("session-old.json");

    uint clubId;
    uint roomId;
    uint lastTmxId;
    int newsActivityId = -1;
    string ServerName;
    string NewsName;

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
        newsActivityId = -1;
        SetServerName();
        startnew(GetOrCreateClubNewsActivity);
        startnew(LoadNextTmxMap);
        StartCoros();
        MapMonitor::SignalGetNextMap_Cached(S_LastTmxID, S_TmxTagsSelectionCsv);
    }

    void SetServerName() {
        auto si = GetServerInfo();
        if (si !is null) {
            ServerName = si.ServerName;
            NewsName = ("LB:" + ServerName).SubStr(0, 20);
        }
    }

    void ResumeGame() {
        clubId = S_ClubID;
        roomId = S_RoomID;
        lastLoadedId = lastTmxId = S_LastTmxID;
        loadNextId = S_LastTmxID;
        currState = GameState::Running;
        newsActivityId = -1;
        SetServerName();
        startnew(GetOrCreateClubNewsActivity);
        auto cp = cast<CSmArenaClient>(GetApp().CurrentPlayground);
        if (cp !is null) startnew(AwaitRulesStart);
        StartCoros();
        MapMonitor::SignalGetNextMap_Cached(S_LastTmxID, S_TmxTagsSelectionCsv);
    }

    void HardReset() {
        currState = GameState::NotRunning;
        startnew(LoadAllPlayerMedalCounts);
    }

    void StartCoros() {
        startnew(WatchForPodium);
        startnew(WatchForWR);
        startnew(WatchForNewPlayers);
    }

    void GetOrCreateClubNewsActivity() {
        while (IsRunning && !S_MaintainClubNewsActivity) {
            yield(7);
        }
        log_trace('GetOrCreateClubNewsActivity - Server Name: ' + ServerName);
        if (!S_MaintainClubNewsActivity) return;
        if (ServerName.Length == 0) return;
        auto activities = Live::GetClubActivities(clubId)["activityList"];
        Json::Value@ activity;
        for (uint i = 0; i < activities.Length; i++) {
            @activity = activities[i];
            if (string(activity["activityType"]) != "news") continue;
            string name = string(activity["name"]);
            if (name != NewsName) continue;
            // found it
            newsActivityId = int(activity["id"]);
            log_trace("Found news activity for server: " + NewsName + ", id: " + newsActivityId);
            return;
        }
        // if we're here, it doesn't exist in first 100 things in club
        log_trace("Creating news activity for server: " + NewsName);
        auto resp = Live::CreateNews(clubId, NewsName, "", "# Scoreboard\n# Uninitialized");
        log_trace("CreateNews response: " + Json::Write(resp));
        newsActivityId = int(resp["id"]);
        log_trace("Created news activity: " + newsActivityId);
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
                sleep(0);
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
            // sleep(500);
            yield();
            if (!S_AutoMoveOnForWR) continue;
            auto app = GetApp();
            if (app.RootMap is null) continue;
            // if (triggeredAuto120 && wrMapUid == lastMap) continue;
            auto rd = MLFeed::GetRaceData_V4();
            auto @players = rd.SortedPlayers_TimeAttack;
            if (players.Length == 0) continue;
            if (!IsSequencePlayingOrFinished()) continue;
            auto bestPlayer = cast<MLFeed::PlayerCpInfo_V4>(players[0]);
            bool playerGotWR = bestPlayer.IsFinished
                && bestPlayer.LastCpTime < rd.Rules_MillisSinceStart
                && IsPlayerTimeWR(bestPlayer.LastCpTime, bestPlayer.WebServicesUserId)
                && rd.Rules_StartTime < 2000000000;
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
                sleep(0);
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
        bool isWR = bestPlayer.BestRaceTimes.Length == rd.CPsToFinish && IsPlayerTimeWR(bestPlayer.BestTime, bestPlayer.WebServicesUserId);
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
        yield();
        CachePlayerMedals(rd);
        yield();
        // Streaks_OnPodium(bestPlayer);
        yield();
        SaveMedalsToClubNews();
    }
#else
    void OnPodiumSequence() {}
#endif

    void SaveMedalsToClubNews() {
        if (newsActivityId < 1) {
            warn("No news activity id set, cannot save medals to club news.");
            return;
        }
        string[] body = {"# Session Top\n"};
        auto nb = Math::Min(SortedPlayerMedals.Length, 12);
        for (int i = 0; i < nb; i++) {
            auto pmc = SortedPlayerMedals[i];
            body.InsertLast(pmc.ToScoreboardLineString(i + 1, false));
        }
        body.InsertLast("# GOAT Players\n");
        nb = Math::Min(GOATPlayerMedals.Length, 40);
        for (int i = 0; i < nb; i++) {
            auto pmc = GOATPlayerMedals[i];
            body.InsertLast(pmc.ToScoreboardLineString(i + 1, true));
        }
        Live::SetNewsDetails(clubId, newsActivityId, NewsName, "", string::Join(body, ""));
    }

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

    void DeletePMC(PlayerMedalCount@ pmc) {
        PlayerMedalCounts.Delete(pmc.login);
        auto ix = SortedPlayerMedals.FindByRef(pmc);
        if (ix >= 0) SortedPlayerMedals.RemoveAt(ix);
        ix = GOATPlayerMedals.FindByRef(pmc);
        if (ix >= 0) GOATPlayerMedals.RemoveAt(ix);
        ix = NewestPlayerMedals.FindByRef(pmc);
        if (ix >= 0) NewestPlayerMedals.RemoveAt(ix);
        if (IO::FileExists(pmc.filename)) {
            IO::Move(pmc.filename, pmc.filename + ".deleted");
        }
    }

    PlayerMedalCount@[] SortedPlayerMedals;
    PlayerMedalCount@[] NewestPlayerMedals;
    PlayerMedalCount@[] GOATPlayerMedals;

    void UpdateSortedPlayerMedals() {
        if (SortedPlayerMedals.Length == 0) return;
        pmcQuicksort(SortedPlayerMedals, function(PlayerMedalCount@ &in a, PlayerMedalCount@ &in b) {
            if (a.NbWRs != b.NbWRs) return a.NbWRs > b.NbWRs ? -1 : 1;
            if (a.NbATs != b.NbATs) return a.NbATs > b.NbATs ? -1 : 1;
            if (a.NbGolds != b.NbGolds) return a.NbGolds > b.NbGolds ? -1 : 1;
            if (a.NbSilvers != b.NbSilvers) return a.NbSilvers > b.NbSilvers ? -1 : 1;
            if (a.NbBronzes != b.NbBronzes) return a.NbBronzes > b.NbBronzes ? -1 : 1;
            if (a.NbNoMedals != b.NbNoMedals) return a.NbNoMedals > b.NbNoMedals ? -1 : 1;
            if (a.mapCount != b.mapCount) return a.mapCount > b.mapCount ? -1 : 1;
            return 0;
        });
        pmcQuicksort(GOATPlayerMedals, function(PlayerMedalCount@ &in a, PlayerMedalCount@ &in b) {
            if (a.NbLifeWRs != b.NbLifeWRs) return a.NbLifeWRs > b.NbLifeWRs ? -1 : 1;
            if (a.NbLifeATs != b.NbLifeATs) return a.NbLifeATs > b.NbLifeATs ? -1 : 1;
            if (a.NbLifeGolds != b.NbLifeGolds) return a.NbLifeGolds > b.NbLifeGolds ? -1 : 1;
            if (a.NbLifeSilvers != b.NbLifeSilvers) return a.NbLifeSilvers > b.NbLifeSilvers ? -1 : 1;
            if (a.NbLifeBronzes != b.NbLifeBronzes) return a.NbLifeBronzes > b.NbLifeBronzes ? -1 : 1;
            if (a.NbLifeNoMedals != b.NbLifeNoMedals) return a.NbLifeNoMedals > b.NbLifeNoMedals ? -1 : 1;
            if (a.mapCount != b.mapCount) return a.mapCount > b.mapCount ? -1 : 1;
            return 0;
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


    // should be called once per frame when necessary
    void CheckStillInServer() {
#if DEV
        // return;
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
        status = "Loading next TMX map... (API or Cache)";
        MapMonitor::SignalGetNextMap_Cached(S_LastTmxID, S_TmxTagsSelectionCsv);
        auto resp = MapMonitor::AwaitNextMap_Cached(S_LastTmxID, S_TmxTagsSelectionCsv);
        lastLoadedId = loadNextId = resp['next'];
        loadNextUid = resp['next_uid'];
        log_trace("Set next map: " + loadNextId + " (" + loadNextUid + ")");
        if (resp.HasKey("extra_nb")) {
            nextMapsExtra.Resize(uint(resp["extra_nb"]));
            auto extra = resp["extra"];
            for (uint i = 0; i < extra.Length; i++) {
                nextMapsExtra[i] = string(extra[i]['next_uid']);
            }
            log_trace("Extra next maps: " + string::Join(nextMapsExtra, ", "));
        } else {
            nextMapsExtra.Resize(0);
        }
        Chat::SendGoodMessage("Next Map ID: " + loadNextId + GetMMNextRespTagsFmt(resp)); // + " \\$888and the following " + nextMapsExtra.Length);
    }

    string GetMMNextRespTagsFmt(Json::Value@ resp) {
        string tags = "";
        try {
            if (resp.HasKey("tag_names")) {
                auto t = resp["tag_names"];
                if (t.GetType() == Json::Type::Array) {
                    tags = " (";
                    for (uint i = 0; i < t.Length; i++) {
                        tags += (i == 0 ? "" : ", ") + string(t[i]);
                    }
                    tags += ")";
                }
            }
        } catch {
            warn("Failed to format tags from MM response: " + getExceptionInfo());
        }
        return tags;
    }

    uint lastLoadedId = S_LastTmxID;
    uint loadNextId = S_LastTmxID;
    string loadNextUid;
    string[] nextMapsExtra;
    void LoadNextTmxMap() {
        currState = GameState::Loading;
        try {
            Chat::SendWarningMessage("Loading Next Map...");
            UpdateNextMap();
            if (!CheckUploadedToNadeoAndSmall()) {
                yield();
                Chat::SendWarningMessage("Map not uploaded to Nadeo or too big! Skipping past " + loadNextId);
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
        MapMonitor::SignalGetNextMap_Cached(S_LastTmxID, S_TmxTagsSelectionCsv);
        currState = GameState::Loading;
        try {
            Chat::SendWarningMessage("Preparing Next Map...");
            UpdateNextMap();
            if (!CheckUploadedToNadeoAndSmall()) {
                Chat::SendWarningMessage("Map not uploaded to Nadeo or too big! Cannot load " + loadNextId + ". Trying next in 5s.");
                sleep(2000);
                sleep(0);
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
                sleep(0);
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

    bool CheckUploadedToNadeo(const string &in mapUid = "") {
        status = "Checking uploaded to Nadeo...";
        auto map = Core::GetMapFromUid(mapUid.Length == 0 ? loadNextUid : mapUid);
        if (map is null) return false;
        log_debug("Map ("+map.Uid+") is Uploaded: " + map.FileUrl);
        // todo: implement caching of map details?
        return true;
    }

    // check if map is uploaded to Nadeo and is less than ~7366 KB
    bool CheckUploadedToNadeoAndSmall() {
        status = "Checking uploaded to Nadeo and size...";
        return Await_UploadAndSmallCheck(loadNextUid);
    }

    dictionary@ uasCheckLoading = dictionary();
    dictionary@ uasCheckOkay = dictionary();
    dictionary@ uasCheckNotOkay = dictionary();

    bool Await_UploadAndSmallCheck(const string &in uid) {
        while (uasCheckLoading.Exists(uid)) yield();
        if (uasCheckOkay.Exists(uid)) return true;
        if (uasCheckNotOkay.Exists(uid)) return false;

        uasCheckLoading[uid] = true;
        auto isOkay = false;
        try {
            isOkay = _RunCheck_UploadAndSmall(uid);
        } catch {
            NotifyError("Something went wrong checking map upload and size: " + getExceptionInfo());
            uasCheckLoading.Delete(uid);
            return false;
        }
        uasCheckLoading.Delete(uid);

        // populate either dict depending on isOkay
        if (isOkay) uasCheckOkay[uid] = true;
        else uasCheckNotOkay[uid] = true;
        return isOkay;
    }

    void SignalCache_UploadAndSmallCheck(const string &in uid) {
        if (uasCheckLoading.Exists(uid)) return;
        if (uasCheckOkay.Exists(uid)) return;
        if (uasCheckNotOkay.Exists(uid)) return;
        startnew(Cache_UploadAndSmallCheck, uid);
    }
    // startnew me
    void Cache_UploadAndSmallCheck(const string &in uid) {
        if (uasCheckLoading.Exists(uid)) return;
        if (uasCheckOkay.Exists(uid)) return;
        if (uasCheckNotOkay.Exists(uid)) return;
        Await_UploadAndSmallCheck(uid);
    }

    bool _RunCheck_UploadAndSmall(const string &in uid) {
        auto map = Core::GetMapFromUid(uid);
        if (map is null) return false;
        log_debug("Map ("+map.Uid+") is Uploaded: " + map.FileUrl);
        string fileUrl = map.FileUrl;
        if (uid != map.Uid) {
            warn("Upload check got different map uid: expected: " + uid + " / got: " + map.Uid);
        }
        @map = null;
        // check file less than ~7366 KB
        auto fileSize = Http::GetFileSize(fileUrl);
        status = "Checking uploaded to Nadeo and size... (" + fileSize + " bytes)";
        if (fileSize < 0) {
            log_error("Failed to get file size for map: " + uid);
            return false;
        }
        if (fileSize > MAP_LIMIT_OCTETS) {
            NotifyError("Map file size too large: " + (fileSize/1024) + " KB!\nMaximum is 7366 KB");
            return false;
        }
        log_debug("Map file size: " + fileSize + " bytes (uid: " + uid + ")");
        return true;
    }

    // // for nextMapsExtra
    // void CheckExtraUploadedToNadeoOrRemove(const string &in uid) {
    //     if (!CheckUploadedToNadeo(uid)) {
    //         log_trace("Extra map not uploaded to Nadeo, removing from list: " + uid);
    //         auto ix = nextMapsExtra.Find(uid);
    //         if (ix >= 0) nextMapsExtra.RemoveAt(ix);
    //     }
    // }

    // array<awaitable@>@ CheckAllExtraUploadedToNadeoOrRemove() {
    //     array<awaitable@>@ routines = {};
    //     for (uint i = 0; i < nextMapsExtra.Length; i++) {
    //         routines.InsertLast(startnew(CheckExtraUploadedToNadeoOrRemove, nextMapsExtra[i]));
    //     }
    //     return routines;
    // }

    // bool CheckAllUploadedToNadeo() {
    //     auto @coros = CheckAllExtraUploadedToNadeoOrRemove();
    //     auto ret = CheckUploadedToNadeo();
    //     await(coros);
    //     return ret;
    // }

    void AutoMoveOn() {
        AutoMoveOn(-1);
    }

    // if moveOnIn < 0, use default S_AutoMoveOnInSeconds or S_AutoMoveOnBasedOnAT
    void AutoMoveOn(int64 moveOnIn) {
        if (GetApp().CurrentPlayground is null || currState == GameState::Loading) return;
        currState = GameState::Loading;
        bool isDefault = moveOnIn < 0;
        if (isDefault) moveOnIn = S_AutoMoveOnInSeconds;
        if (isDefault && S_AutoMoveOnBasedOnAT) {
            try {
                moveOnIn = (GetApp().RootMap.ChallengeParameters.AuthorScore / 1000 + 11);
            } catch {
                NotifyWarning("Failed to get AT time for move on, defaulting to " + moveOnIn + ' seconds');
            }
        }
        // this happens normally
        Chat::SendWarningMessage("Setting Next Map to load in " + moveOnIn + " seconds.");
        // this hangs sometimes
        UpdateNextMap();
        // first thing in CheckUploadedToNadeoAndSmall is updating the loading status
        if (!CheckUploadedToNadeoAndSmall()) {
            Chat::SendWarningMessage("Map not uploaded to Nadeo or too big! Skipping past " + loadNextId);
            S_LastTmxID = loadNextId;
            currState = GameState::Running;
            sleep(2000);
            sleep(0);
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

    // setting map list doesn't reset position in map list; complex to figure out
    string[]@ GetNextMapsList() {
        string[]@ maps = {loadNextUid};
        // for (uint i = 0; i < nextMapsExtra.Length; i++) {
        //     maps.InsertLast(nextMapsExtra[i]);
        // }
        return maps;
    }

    int lastSetNextMap;
    int mapTimeLimitWithExt = 300;
    void SetNextRoomTA(uint timelimit = 1, uint waitSeconds = 1) {
        log_info("SetNextRoom TA: timelimit = " + timelimit + ", wait secs = " + waitSeconds);
        int myLastSetNextMap = Time::Now;
        lastSetNextMap = myLastSetNextMap;
        status = "Loading Map " + loadNextId + " / " + loadNextUid;
        auto next_maps = GetNextMapsList();
        auto builder = BRM::CreateRoomBuilder(clubId, roomId)
            .SetTimeLimit(timelimit)
            .SetChatTime(0)
            .SetMaps(next_maps)
            .SetLoadingScreenUrl(ChooseNextLoadingScreenUrl())
            .SetModeSetting("S_DelayBeforeNextMap", "1")
            .SetMode(BRM::GameMode::TimeAttack);

        auto resp = builder.SaveRoom();
        uint waitTime = 0 + waitSeconds;
        status += "\nSaved Room maps + time limit... Waiting " + waitTime + " s";
        log_trace('Room request returned: ' + Json::Write(resp));
        if (waitSeconds > 1) currState = GameState::Running;
        sleep(1000 * waitTime);
        sleep(0);
        // exit if another set next room has been triggered in the mean time
        if (lastSetNextMap != myLastSetNextMap) return;
        currState = GameState::Loading;
        status = "Waiting for round to end...";
        while (IsSequencePlayingOrFinished() && lastSetNextMap == myLastSetNextMap) yield();
        currState = GameState::Running;
        if (lastSetNextMap != myLastSetNextMap) return;
        currState = GameState::Loading;
        int limit = S_DefaultTimeLimit;
        mapTimeLimitWithExt = limit;
        builder.SetTimeLimit(limit);
        status = "Adjusting room time limit to " + limit;
        builder.SaveRoom();
        status = "Room finalized, awaiting map change...";
        AwaitMapUidLoad(next_maps);
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
        sleep(0);
        int limit = -1;
        builder.SetTimeLimit(limit);
        status = "Adjusting room time limit to " + limit;
        builder.SaveRoom();
        status = "Room finalized, awaiting map change...";
        AwaitMapUidLoad({S_LobbyMapUID});
        status = "Done";
        currState = GameState::NotRunning;
        return;
    }

    void AwaitMapUidLoad(const string[] &in uids) {
        auto app = GetApp();
        while (true) {
            yield();
            // we disconnected
            if (app.Network.ClientManiaAppPlayground is null) return;
            // wait for a map
            if (app.RootMap is null) continue;
            // check uid
            if (uids.Find(app.RootMap.EdChallengeId) < 0) continue;
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
    //         .SetLoadingScreenUrl(ChooseNextLoadingScreenUrl())
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




funcdef int PmcLessF(PlayerMedalCount@ &in m1, PlayerMedalCount@ &in m2);
void pmcQuicksort(PlayerMedalCount@[]@ arr, PmcLessF@ f, int left = 0, int right = -1) {
    if (right < 0) right = arr.Length - 1;
    if (arr.Length == 0) return;
    int i = left;
    int j = right;
    PlayerMedalCount@ pivot = arr[(left + right) / 2];

    while (i <= j) {
        while (f(arr[i], pivot) < 0) i++;
        while (f(arr[j], pivot) > 0) j--;
        if (i <= j) {
            PlayerMedalCount@ temp = arr[i];
            @arr[i] = arr[j];
            @arr[j] = temp;
            i++;
            j--;
        }
    }

    if (left < j) pmcQuicksort(arr, f, left, j);
    if (i < right) pmcQuicksort(arr, f, i, right);
}


/// Some dev stuff


void LoadAllPlayerMedalCounts() {
    LoadingMedalCounts = true;
    auto usersFolder = IO::FromStorageFolder("users/");
    auto files = IO::IndexFolder(usersFolder, false);
    Notify("Loading " + files.Length + " player medal counts.");
    uint notify_every = Math::Max(files.Length / 5, 10);
    uint loaded = 0;
    for (uint i = 0; i < files.Length; i++) {
        if (!files[i].EndsWith(".json")) continue;
        State::LoadPMC(files[i]);
        loaded++;
        if (loaded % notify_every == 0) {
            Notify("Loaded " + (loaded) + " / " + files.Length);
        }
        if (loaded % 30 == 0)
            yield();
    }
    yield();
    State::UpdateSortedPlayerMedals();
    LoadingMedalCounts = false;
}

void LoadGOATPlayerMedalCounts() {
    // todo if we need to
    LoadAllPlayerMedalCounts();
}

string ChooseNextLoadingScreenUrl() {
    if (!S_LoadingScreenImageUrl.Contains(',')) {
        return S_LoadingScreenImageUrl;
    }
    auto parts = S_LoadingScreenImageUrl.Split(",");
    for (uint i = 0; i < parts.Length; i++) {
        parts[i] = parts[i].Trim();
        if (parts[i].Length == 0) {
            parts.RemoveAt(i);
            i--;
        }
    }
    if (parts.Length == 0) return S_LoadingScreenImageUrl;
    return parts[Math::Rand(0, parts.Length)];
}
