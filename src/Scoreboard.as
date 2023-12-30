
void DrawPMCHeadings(vec2 &in pos, float nameWidth, float medalSpacing, float fontSize, float alpha = 1.0, bool compressed = false) {
    nvg::BeginPath();
    nvg::FontSize(fontSize);
    nvg::TextAlign(nvg::Align::Left | nvg::Align::Top);

    nvg::FillColor(vec4(0, 0, 0, 0.7 * alpha));
    float nbCols = 7.;
    vec2 bounds = vec2(nameWidth + medalSpacing * nbCols, pmcPad.y * 2. + fontSize);
    nvg::Rect(pos - vec2(0, 2), bounds + pmcPad * 2.);
    nvg::Fill();
    nvg::FillColor(vec4(.8, .8, .8, 1) * vec4(1, 1, 1, alpha));
    nvg::Text(pos + pmcPad, "Player");
    auto medalStart = pos + pmcPad + vec2(nameWidth, 0);
    nvg::Text(medalStart + vec2(medalSpacing * 0., 0), "WR");
    nvg::Text(medalStart + vec2(medalSpacing * 1., 0), "AT");
    nvg::Text(medalStart + vec2(medalSpacing * 2., 0), "Gold");
    nvg::Text(medalStart + vec2(medalSpacing * 3., 0), "Silver");
    nvg::Text(medalStart + vec2(medalSpacing * 4., 0), "Bronze");
    nvg::Text(medalStart + vec2(medalSpacing * 5., 0), "No Medal");
    nvg::Text(medalStart + vec2(medalSpacing * 6., 0), "Total");
    nvg::ClosePath();
}

void DrawPlayerMedalCounts() {
    if (State::IsNotRunning) return;
    auto app = GetApp();
    if (app.LoadProgress.State == NGameLoadProgress::EState::Disabled) return;
    // draw only when we're over the loading screen.
    // auto keys = State::PlayerMedalCounts.GetKeys();

    auto @pmcs = State::SortedPlayerMedals;

    if (pmcs.Length > 10) {
        DrawAltPlayerMedalCounts();
        return;
    }

    float h = Draw::GetHeight();
    float w = Draw::GetWidth();
    // 1 extra for heading
    auto nbPlayers = pmcs.Length + 1;
    auto propYPad = 0.15;
    float playerPropHeight = (1.0 - propYPad * 2.) / Math::Max(20., float(nbPlayers));
    float linePxHeight = playerPropHeight * h;
    float fontSize = (linePxHeight - pmcPad.y * 2.);
    linePxHeight *= 1.2;
    float fullWidth = h * 1.2;
    float xStart = (w - fullWidth) / 2.;
    float fullHeight = h * (playerPropHeight * float(nbPlayers));
    float yStart = (h - fullHeight) / 2.;
    vec2 nextPos = vec2(xStart, yStart);
    float playerPropWidth = 1. / 4.;
    float nameWidth = fullWidth * playerPropWidth;
    float medalSpacing = fullWidth * (1. - playerPropWidth) / 6.; // * 2. / 3. / 6.

    DrawPMCHeadings(nextPos, nameWidth, medalSpacing, fontSize);
    nextPos.y += linePxHeight;

    for (uint i = 0; i < pmcs.Length; i++) {
        PlayerMedalCount@ pmc = cast<PlayerMedalCount>(pmcs[i]);
        if (pmc is null) continue;
        pmc.Draw(nextPos, nameWidth, medalSpacing, fontSize);
        nextPos.y += linePxHeight;
    }
}


// New scoreboard

void DrawAltPlayerMedalCounts() {
    auto @pmcs = State::SortedPlayerMedals;

    float h = Draw::GetHeight();
    float w = Draw::GetWidth();
    // 1 extra for heading
    auto nbPlayers = pmcs.Length + 1;
    auto propYPad = 0.15;
    float playerPropHeight = (1.0 - propYPad * 2.) / Math::Max(20., float(nbPlayers));
    float linePxHeight = playerPropHeight * h;
    float fontSize = (linePxHeight - pmcPad.y * 2.);
    linePxHeight *= 1.2;
    float fullWidth = h * 1.2;
    float xStart = (w - fullWidth) / 2.;
    float fullHeight = h * (playerPropHeight * float(nbPlayers));
    float yStart = (h - fullHeight) / 2.;
    vec2 nextPos = vec2(xStart, yStart);
    float playerPropWidth = 1. / 4.;
    float nameWidth = fullWidth * playerPropWidth;
    float medalSpacing = fullWidth * (1. - playerPropWidth) / 6.; // * 2. / 3. / 6.
}
