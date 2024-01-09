namespace ScoreEditor {
    bool windowVisible = false;

    void Render() {
        if (!windowVisible) return;
        if (!State::IsRunning) return;

        vec2 size = vec2(780, 300);
        UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::FirstUseEver);
        UI::PushStyleColor(UI::Col::FrameBg, vec4(.2, .2, .2, .5));
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(4, 4));
        if (UI::Begin("Saved Scores Editor", windowVisible)) {
            if (UI::BeginTable("edit-medals", 2)) {
                UI::TableSetupColumn("name", UI::TableColumnFlags::WidthFixed, 100);
                UI::ListClipper clip(State::SortedPlayerMedals.Length);
                while (clip.Step()) {
                    for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                        UI::TableNextRow();
                        UI::TableNextColumn();

                        auto item = State::SortedPlayerMedals[i];
                        UI::PushID(item.login);

                        UI::AlignTextToFramePadding();
                        UI::Text(item.name);

                        UI::TableNextColumn();
                        UI::PushItemWidth(90);

                        for (uint c = 0; c < item.lifetimeMedalCounts.Length; c++) {
                            UI::SameLine();
                            UI::PushStyleColor(UI::Col::Text, medalColors[c]);
                            item.lifetimeMedalCounts[c] = UI::InputInt("###"+i+"medal-"+c, item.lifetimeMedalCounts[c]);
                            UI::PopStyleColor();
                        }

                        UI::PopItemWidth();
                        UI::PopID();
                    }
                }
                UI::EndTable();
            }
        }
        UI::End();
        UI::PopStyleVar();
        UI::PopStyleColor();
    }
}
