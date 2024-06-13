
uint g_LastLoadingScreen = 0;

[Setting category="Score Board" name="Show Scores for X seconds after loading screen" min=0 max=10]
float S_SBTimeoutSec = 3.0;

bool g_ForceShowLeaderboard = false;

interface ScoreboardElement {
    // Draw using nvg
    void DrawCompact(uint rank, vec2 &in pos, float nameWidth, float medalSpacing, float fontSize, float alpha = 1.0, uint[]@ mc = null, bool lifetimeMapCount = false);
    void DrawCompactLifeTime(uint rank, vec2 &in pos, float nameWidth, float medalSpacing, float fontSize, float alpha = 1.0);
    bool IsRanked();
}

interface ScoreboardIter {
    ScoreboardElement@ Next();
    bool Done();
}

class ScoreboardHeading : ScoreboardElement {
    string name;
    ScoreboardHeading(const string &in name = "") {
        this.name = name;
    }

    void DrawCompact(uint rank, vec2 &in pos, float nameWidth, float medalSpacing, float fontSize, float alpha = 1.0, uint[]@ mc = null, bool lifetimeMapCount = false) {
        DrawAltHeading(name, pos, nameWidth, medalSpacing, fontSize, alpha);
    }

    void DrawCompactLifeTime(uint rank, vec2 &in pos, float nameWidth, float medalSpacing, float fontSize, float alpha = 1.0) {
        DrawAltHeading(name, pos, nameWidth, medalSpacing, fontSize, alpha);
    }

    bool IsRanked() {
        return false;
    }
}

// this is +1 because we draw nb. played maps too
float f_nbMedalsToDraw = 4.;
// set to mc.Length to draw all medals
uint nbMedalsToDraw = 3;

void DrawAltHeading(const string &in title, vec2 &in pos, float nameWidth, float medalSpacing, float fontSize, float alpha = 1.0) {
    nvg::BeginPath();
    nvg::FontSize(fontSize);
    nvg::TextAlign(nvg::Align::Left | nvg::Align::Top);

    nvg::FillColor(vec4(0, 0, 0, 0.85 * alpha));
    vec2 bounds = vec2(nameWidth + medalSpacing * f_nbMedalsToDraw, pmcPad.y * 2. + fontSize);
    nvg::Rect(pos - vec2(0, 2), bounds + pmcPad * 2.);
    nvg::Fill();
    nvg::FillColor(vec4(.8, .8, .8, 1) * vec4(1, 1, 1, alpha));
    nvg::Text(pos + pmcPad + vec2(0, fontSize * .15), title);
    nvg::ClosePath();
}

namespace Scoreboard {
    int nbRows = 13;
    int nbCols = 4;

    void DrawScoreboard(ScoreboardIter@ scores) {
        float h = Draw::GetHeight();
        float w = Draw::GetWidth();
        float aspect = w / h;
        auto propYPad = 0.15;
        if (aspect < 1.5) {
            nbCols = 2;
        } else if (aspect < 1.99) {
            // assume 16x9
            nbCols = 3;
        } else {
            nbCols = 4;
        }

        float playerPropHeight = (1.0 - propYPad * 2.) / float(nbRows);
        float linePxHeight = playerPropHeight * h;
        float fontSize = (linePxHeight - pmcPad.y * 2.) / 1.3;
        float fullWidth = Math::Max(h * 1.2, w * 0.8);
    #if DEV
        // fullWidth /= 2.0;
    #endif
        float colWidth = fullWidth / float(nbCols) - pmcPad.x * 1.5;

        float xStart = (w - fullWidth - pmcPad.x * 1.5) / 2.;
        float fullHeight = h * (playerPropHeight * float(nbRows));
        float yStart = (h - fullHeight) / 2.;
        vec2 nextPos = vec2(xStart, yStart);
        float playerPropWidth = 0.6;
        float nameWidth = colWidth * playerPropWidth;
        float medalSpacing = colWidth * (1. - playerPropWidth) / f_nbMedalsToDraw;

        ScoreboardElement@ el;
        uint rank = 0;

        uint rowCount = 0;
        uint colCount = 0;

        float colWidthWPadding = colWidth + pmcPad.x * 3;

        while (colCount < nbCols) {
            while ((@el = scores.Next()) !is null) {
                if (el.IsRanked()) {
                    rank++;
                } else {
                    rank = 0;
                    if (rowCount > 0) {
                        rowCount = 0;
                        colCount++;
                        nextPos = vec2(xStart + colWidthWPadding * float(colCount), yStart);
                    }
                }
                el.DrawCompact(rank, nextPos, nameWidth, medalSpacing, fontSize);
                nextPos.y += linePxHeight;
                rowCount++;
                if (rowCount >= nbRows) {
                    break;
                }
            }
            rowCount = 0;
            colCount++;
            nextPos = vec2(xStart + colWidthWPadding * float(colCount), yStart);
        }

        // nbPlayers = Math::Min(nbPlayers, scores.Length);
        // for (int i = 0; i < nbPlayers; i++) {
        //     PlayerMedalCount@ pmc = cast<PlayerMedalCount>(scores[i]);
        //     if (pmc is null) continue;
        //     pmc.DrawCompact(i + 1, nextPos, nameWidth, medalSpacing, fontSize);
        //     nextPos.y += linePxHeight;
        // }

        // nextPos = vec2(xStart + colWidthWPadding, yStart);

        // // DrawAltHeading("New Players", nextPos, nameWidth, medalSpacing, fontSize);
        // // nextPos.y += linePxHeight;


        // // for (int i = 0; i < nbOtherRows; i++) {
        // //     PlayerMedalCount@ pmc = cast<PlayerMedalCount>(State::NewestPlayerMedals[i]);
        // //     if (pmc is null) continue;
        // //     pmc.DrawCompact(i + 1, nextPos, nameWidth, medalSpacing, fontSize);
        // //     nextPos.y += linePxHeight;
        // // }

        // auto nbGoats = State::GOATPlayerMedals.Length;

        // // nextPos.y += linePxHeight;
        // DrawAltHeading("GOAT Players", nextPos, nameWidth, medalSpacing, fontSize);
        // nextPos.y += linePxHeight;

        // for (int i = 0; i < nbPlayers; i++) {
        //     PlayerMedalCount@ pmc = cast<PlayerMedalCount>(State::GOATPlayerMedals[i]);
        //     if (pmc is null) continue;
        //     pmc.DrawCompactLifeTime(i + 1, nextPos, nameWidth, medalSpacing, fontSize);
        //     nextPos.y += linePxHeight;
        // }

        // // add 1 to players here because we don't draw a heading
        // auto priorGoatRows = nbPlayers;
        // nbPlayers += 1;

        // // col 3, more GOATs
        // nextPos = vec2(xStart + colWidthWPadding * 2., yStart);

        // for (int i = 0; i < nbPlayers; i++) {
        //     auto ix = priorGoatRows + i;
        //     if (ix >= nbGoats) break;
        //     PlayerMedalCount@ pmc = cast<PlayerMedalCount>(State::GOATPlayerMedals[ix]);
        //     if (pmc is null) continue;
        //     pmc.DrawCompactLifeTime(ix + 1, nextPos, nameWidth, medalSpacing, fontSize);
        //     nextPos.y += linePxHeight;
        // }

        // // col 4, more GOATs
        // nextPos = vec2(xStart + colWidthWPadding * 3., yStart);
        // priorGoatRows += nbPlayers;

        // for (int i = 0; i < nbPlayers; i++) {
        //     auto ix = priorGoatRows + i;
        //     if (ix >= nbGoats) break;
        //     PlayerMedalCount@ pmc = cast<PlayerMedalCount>(State::GOATPlayerMedals[ix]);
        //     if (pmc is null) continue;
        //     pmc.DrawCompactLifeTime(ix + 1, nextPos, nameWidth, medalSpacing, fontSize);
        //     nextPos.y += linePxHeight;
        // }
    }
}



CTrackManiaNetworkServerInfo@ GetServerInfo() {
	auto app = GetApp();
	auto si = cast<CTrackManiaNetworkServerInfo>(app.Network.ServerInfo);
	return si;
}
