

vec2 pmcPad = vec2(15., 5.);

// max player len in data was 15; round up to 16 so it's divisible by tab width
const uint MAX_PLAYER_NAME_LEN_SB = 16;
// number of characters a tab takes up in news (approx, 4 underscores, but also `auto ` is tab width)
const uint TAB_WIDTH = 4;
const string TABS_X4 = "\t\t\t\t";

string TabFormatMedalCount(uint count) {
    return tostring(count) + (count < 10000 ? "\t\t" : "\t");
}

enum Medal {
    WR = 0, Author = 1, Gold, Silver, Bronze, NoMedal
}

class PlayerMedalCount : ScoreboardElement {
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
    string nameWithTabs;

    PlayerMedalCount(const string &in name, const string &in login) {
        this.name = name;
        this.login = login;
        firstSeen = Time::Stamp;
        lastSeen = firstSeen;
        SetFilepathFromLogin();
        FromJsonFile();
        SetNameWithTabs();
    }

    // This constructer is here to load from a json file, the IO::FileMode makes this obvious but isn't used otherwise
    PlayerMedalCount(IO::FileMode _modeCheck, const string &in login) {
        if (login.Contains(".")) throw("dont pass file path");
        this.login = login;
        SetFilepathFromLogin();
        auto j = FromJsonFile();
        if (j is null) throw("could not load saved PMC for " + login);
        this.name = j['name'];
        SetNameWithTabs();
    }

    void SetNameWithTabs() {
        auto nameLen = name.Length;
        nameWithTabs = name + TABS_X4.SubStr(0, (MAX_PLAYER_NAME_LEN_SB - nameLen + TAB_WIDTH - 1) / TAB_WIDTH);
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
            SetNameWithTabs();
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

    uint get_NbLifeMedalsTotal() {
        return lifetimeMedalCounts[0] + lifetimeMedalCounts[1] + lifetimeMedalCounts[2] + lifetimeMedalCounts[3] + lifetimeMedalCounts[4];
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

    string ToScoreboardLineString(uint rank, bool lifetime = false) {
        auto @mcs = lifetime ? lifetimeMedalCounts : medalCounts;
        auto count = lifetime ? mapCount : mapCountSession;
        return string::Join({
            Text::Format("%2d.\t", rank),
            nameWithTabs,
            TabFormatMedalCount(mcs[0]),
            TabFormatMedalCount(mcs[1]),
            TabFormatMedalCount(mcs[2]),
            TabFormatMedalCount(count),
            "\n"}, "");
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
        string nameLabel = tostring(rank) + ". " + name;
        auto maxNameWidth = nameWidth - pmcPad.x;

        auto textOffset = vec2(0, fontSize * .15);
        nvg::BeginPath();
        nvg::FontSize(fontSize);
        nvg::TextAlign(nvg::Align::Left | nvg::Align::Top);
        auto textBounds = nvg::TextBounds(nameLabel);

        float xScale = textBounds.x > maxNameWidth ? Math::Max(0.1, maxNameWidth / textBounds.x) : 1;

        nvg::FillColor(vec4(0, 0, 0, 0.7 * alpha));
        vec2 bounds = vec2(nameWidth + medalSpacing * f_nbMedalsToDraw, pmcPad.y * 2. + fontSize);
        nvg::Rect(pos - vec2(0, 2), bounds + pmcPad * 2.);
        nvg::Fill();
        nvg::FillColor(col * vec4(1, 1, 1, alpha));

        nvg::Scale(vec2(xScale, 1));
        nvg::Text((pos + pmcPad + textOffset) * vec2(1. / xScale, 1.), nameLabel);
        nvg::Scale(vec2(1. / xScale, 1));

        auto medalStart = pos + pmcPad + vec2(nameWidth, 0);

        float fs, hOff;
        for (uint i = 0; i < nbMedalsToDraw; i++) {
            auto c = mc[i];
            fs = c < 100 ? fontSize * 0.95 : c < 1000 ? fontSize * .72 : fontSize * .60;
            hOff = c < 100 ? 0. : c < 1000 ? fontSize * .1 : fontSize * .2;
            nvg::FontSize(fs);
            nvg::FillColor(medalColors[i] * vec4(1, 1, 1, alpha));
            nvg::Text(medalStart + vec2(medalSpacing * float(i), hOff) + textOffset, tostring(mc[i]));
        }
        fs = mapCount < 100 ? fontSize * 0.95 : mapCount < 1000 ? fontSize * .72 : fontSize * .60;
        hOff = mapCount < 100 ? 0. : mapCount < 1000 ? fontSize * .1 : fontSize * .2;
        nvg::FontSize(fs);
        nvg::FillColor(col * vec4(1, 1, 1, alpha));
        nvg::Text(medalStart + vec2(medalSpacing * float(nbMedalsToDraw), hOff) + textOffset, tostring(lifetimeMapCount ? mapCount : mapCountSession));
        nvg::ClosePath();
    }

    void DrawCompactLifeTime(uint rank, vec2 &in pos, float nameWidth, float medalSpacing, float fontSize, float alpha = 1.0) {
        DrawCompact(rank, pos, nameWidth, medalSpacing, fontSize, alpha, lifetimeMedalCounts, true);
    }

    bool IsRanked() {
        return true;
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
