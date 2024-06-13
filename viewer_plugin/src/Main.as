int nvgFont = 0;

void Main() {
	nvgFont = nvg::LoadFont("DroidSans-Bold.ttf", true, true);
#if DEV
	// g_ForceShowLeaderboard = true;
#endif
}

void Render() {
#if DEVx
#elif DEPENDENCY_TMX_TOGETHER
	// if tmx together is running, don't render SB
	if (TmxTogetherState::IsRunning) {
		return;
	}
#endif
	auto si = GetServerInfo();
	if (si is null) return;
	if (!IsActiveForServer(si)) return;

	if (!S_ShowIfUIHidden && !UI::IsGameUIVisible()) return;
	if (!S_ShowIfOverlayHidden && !UI::IsOverlayShown()) return;

    auto app = GetApp();
    bool isLoading = app.LoadProgress.State != NGameLoadProgress::EState::Disabled
        || app.Switcher.ModuleStack.Length == 0;
    if (!isLoading) {
        if (Time::Now > g_LastLoadingScreen + uint(S_SBTimeoutSec * 1000) && !g_ForceShowLeaderboard) return;
    } else if (!g_ForceShowLeaderboard) {
        g_LastLoadingScreen = Time::Now;
    }
    nvg::FontFace(nvgFont);
	_DrawScoreboard();
}

void _DrawScoreboard() {
	Scoreboard::DrawScoreboard(ArrayIter(scoreboard));
}

class ArrayIter : ScoreboardIter {
	ScoreboardElement@[]@ arr;
	uint ix = 0;

	ArrayIter(ScoreboardElement@[]@ arr) {
		@this.arr = arr;
	}

	ScoreboardElement@ Next() {
		if (ix >= arr.Length) return null;
		return arr[ix++];
	}

	bool Done() {
		return ix >= arr.Length;
	}
}

string lastServerLogin;
string lastServerName;
bool _isActive = false;
int _newsActivityId = -1;
int _activeClubId = -1;
bool IsActiveForServer(CTrackManiaNetworkServerInfo@ si) {
	if (lastServerLogin == si.ServerLogin) return _isActive;
	lastServerLogin = si.ServerLogin;
	lastServerName = si.ServerName;
	_isActive = false;
	_newsActivityId = -1;
	_activeClubId = -1;
	if (lastServerLogin.Length == 0) return false;
	startnew(CheckIfServerIsTmxTogether);
	return false;
}

void CheckIfServerIsTmxTogether() {
	auto login = lastServerLogin;
	// // auto whoami = Live::ClubRoomWhoAmI(login);
	// // trace("whoami: " + Json::Write(whoami));
	// if (whoami is null) return;
	// int clubId = whoami.Get("id", -1);
	auto si = BRM::GetCurrentServerInfo(GetApp(), true);
	int clubId = si.clubId;
	if (clubId < 1) return;
	_activeClubId = clubId;
	trace("TMXT scoreboard checking for server: " + login + " in club: " + clubId);
	// now we check for the news article
	auto activities = Live::GetClubActivities(clubId);
	if (activities is null) return;
	@activities = activities['activityList'];
	Json::Value@ activity;
	trace('checking activities for news');
	for (uint i = 0; i < activities.Length; i++) {
		@activity = activities[i];
		if (string(activity["activityType"]) != "news") continue;
		string name = string(activity["name"]);
		if (!name.StartsWith("LB:")) continue;
		if (name.SubStr(3) != lastServerName.SubStr(0, 17)) {
#if DEV
			trace("TMXT scoreboard news name mismatch: " + name + " != " + lastServerName);
#endif
			continue;
		}
		// found it
		_newsActivityId = int(activity["id"]);
		break;
	}
	if (_newsActivityId < 1) {
		trace("TMXT scoreboard no news found for server: " + login);
		return;
	}
	_isActive = true;
	trace("TMXT scoreboard activating for server: " + login);
	RefreshScoreboardFromNews();
	startnew(WaitForPodiumSeqToRefresh);
}

void ClearScoreboard() {
	scoreboard.RemoveRange(0, scoreboard.Length);
}

ScoreboardElement@[] scoreboard;
string scoreboardTitle = "Scores";

void RefreshScoreboardFromNews() {
	auto clubId = _activeClubId;
	auto newsId = _newsActivityId;
	auto deets = Live::GetNewsDetails(clubId, newsId);
	string body = deets['body'];
	log_trace("TMXT scoreboard news body:\n" + body);
	// scoreboardTitle = "Scores";
	// if (body.StartsWith("# ")) {
	// 	auto ix = body.IndexOf('\n');
	// 	if (ix > 0) {
	// 		scoreboardTitle = body.SubStr(2, ix - 2);
	// 	}
	// }
	ClearScoreboard();
	UpdateScoreboard(body);
}

void UpdateScoreboard(const string &in body) {
	auto lines = body.Split("\n");
	Score@ score;
	for (uint i = 0; i < lines.Length; i++) {
		auto line = lines[i];
		if (line.Length < 2) continue;
		if (line[0] == '#'[0] && line[1] == ' '[0]) {
			scoreboard.InsertLast(ScoreboardHeading(line.SubStr(2)));
			continue;
		}
		@score = ParseScoreLine(line);
		if (score is null) continue;
		scoreboard.InsertLast(score);
	}
}

class Score : PlayerMedalCount {
	int rank;
	Score(int rank, const string &in name, int wrs, int ats, int golds, int mapsPlayed) {
		super(name, "unk");
		this.rank = rank;
		this.lifetimeMedalCounts[0] = wrs;
		this.lifetimeMedalCounts[1] = ats;
		this.lifetimeMedalCounts[2] = golds;
		this.mapCount = mapsPlayed;
		this.medalCounts[0] = wrs;
		this.medalCounts[1] = ats;
		this.medalCounts[2] = golds;
		this.mapCountSession = mapsPlayed;
	}

	void SetFilepathFromLogin() override {
		filename = "?!*; INVALID :><&";
	}
	Json::Value@ FromJsonFile() override { return null; }
	Json::Value@ FromJson(Json::Value@ j) override { return null; }
	void AddMedal(Medal m) override {}
	void LoadFromSessionSummary(Json::Value@ j) override {}
	Json::Value@ SessionSummaryForSaving() override { return null; }
	void ToJsonFile() override {}
}

Score@ ParseScoreLine(const string &in line) {
	try {
		if (line.Length < 2) return null;
		auto ix = line.IndexOf('.');
		if (ix < 0) return null;
		// log_trace("rank: " + line.SubStr(0, ix));
		auto rank = Text::ParseInt(line.SubStr(0, ix));
		string rest = line.SubStr(ix + 1).Trim();
		ix = rest.IndexOf('\t');
		auto name = rest.SubStr(0, ix);
		rest = rest.SubStr(ix + 1).Trim();
		ix = rest.IndexOf('\t');
		// log_trace("rest (wrs, ats, golds): " + rest);
		auto wrs = Text::ParseInt(rest.SubStr(0, ix));
		// log_trace("wrs: " + wrs);
		rest = rest.SubStr(ix + 1).Trim();
		ix = rest.IndexOf('\t');
		// log_trace("rest (ats, golds): " + rest);
		auto ats = Text::ParseInt(rest.SubStr(0, ix));
		// log_trace("ats: " + ats);
		rest = rest.SubStr(ix + 1).Trim();
		ix = rest.IndexOf('\t');
		// log_trace("rest (golds, count): " + rest);
		auto golds = Text::ParseInt(rest.SubStr(0, ix));
		// log_trace("golds: " + golds);
		rest = rest.SubStr(ix + 1).Trim();
		auto mapsPlayed = Text::ParseInt(rest);
		return Score(rank, name, wrs, ats, golds, mapsPlayed);
	} catch {
		trace("failed to parse score line: " + line + " (exception: "+getExceptionInfo()+")");
	}
	return null;
}


void WaitForPodiumSeqToRefresh() {
	uint lastMapId = 0;
	auto app = GetApp();
	while (_isActive) {
		if (app.RootMap is null || app.CurrentPlayground is null) {
			sleep(200);
			continue;
		}

		if (app.CurrentPlayground.UIConfigs[0].UISequence != CGamePlaygroundUIConfig::EUISequence::Podium) {
			sleep(100);
			continue;
		}
		// we must now be in the podium sequence
		lastMapId = app.RootMap.Id.Value;
		// wait a few seconds for news to be updated
		sleep(4900);
		startnew(RefreshScoreboardFromNews);
		// podium seq usually 6s so give it time to play out a bit
		sleep(1100);
		// wait for map to change
		while (app.RootMap !is null && app.RootMap.Id.Value == lastMapId) {
			yield();
		}
	}
}
