class GameInterface {
    GameInterface() {

    }

    void RenderMain() {
        State::CheckStillInServer();
        if (State::IsRunning) {
            RenderRunning();
        } else if (State::IsError) {
            RenderError();
        } else if (State::IsNotRunning) {
            RenderNotRunning();
        } else if (State::IsLoading) {
            RenderLoading();
        } else if (State::IsInitializing) {
            RenderInitializing();
        } else if (State::IsFinished) {
            RenderFinished();
        } else {
            UI::Text("\\$f80UNKNOWN STATE!");
        }
    }

    void RenderRunning() {
        UI::AlignTextToFramePadding();
        UI::Text("Current Map: " + State::lastLoadedId);
        UI::SetNextItemWidth(200);
        S_LastTmxID = UI::InputInt("Next TMX ID", S_LastTmxID + 1) - 1;
        // UI::SetNextItemWidth(130);
        // S_LastTmxID = UI::InputInt("Next Map", S_LastTmxID + 1) - 1;
        auto cp = UI::GetCursorPos();
        if (UI::Button("Next")) {
            startnew(State::LoadNextTmxMap);
        }
        UI::SetCursorPos(cp + vec2(210, 0));
        if (UI::Button("To Lobby")) {
            startnew(State::BackToLobby);
        }
        if (State::mapTimeLimitWithExt > 0) {
            UI::Separator();
            if (UI::Button("Extend Time Limit")) {
                startnew(State::ExtendTimeLimit);
            }
            UI::SameLine();
            UI::Dummy(vec2(20, 0));
            UI::SameLine();
            if (UI::Button("Remove Time Limit")) {
                startnew(State::RemoveTimeLimit);
            }
        }
        if (Chat::HasInfo) {
            UI::Separator();
            DrawChatMoveOns();
            DrawChatVotes();
        }

#if DEPENDENCY_MLFEEDRACEDATA
        UI::Separator();
        DrawPlayerProgress();
#endif
    }

    void DrawPlayerProgress() {
        if (UI::CollapsingHeader("Current Runs")) {
#if DEPENDENCY_MLFEEDRACEDATA
            UI::Indent();

            auto rd = MLFeed::GetRaceData_V4();
            UI::ListClipper clip(rd.SortedPlayers_Race.Length);
            if (UI::BeginTable("player-curr-runs", 4, UI::TableFlags::SizingStretchProp | UI::TableFlags::ScrollY)) {
                UI::TableSetupColumn("name", UI::TableColumnFlags::WidthStretch);
                UI::TableSetupColumn("cp", UI::TableColumnFlags::WidthStretch);
                UI::TableSetupColumn("time", UI::TableColumnFlags::WidthStretch);
                UI::TableSetupColumn("delta", UI::TableColumnFlags::WidthStretch);
                // UI::TableHeadersRow();

                while (clip.Step()) {
                    for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                        auto p = rd.SortedPlayers_Race[i];
                        UI::PushID(i);

                        UI::TableNextRow();

                        UI::TableNextColumn();
                        UI::Text(p.Name);
                        UI::TableNextColumn();
                        UI::Text(tostring(p.CpCount));
                        UI::TableNextColumn();
                        UI::Text(Time::Format(p.LastCpOrRespawnTime));
                        UI::TableNextColumn();
                        auto best = p.BestRaceTimes;
                        if (best !is null && p.CpCount <= int(best.Length)) {
                            bool isBehind = false;
                            auto cpBest = p.CpCount == 0 ? 0 : int(best[p.CpCount - 1]);
                            auto lastCpTimeVirtual = p.LastCpOrRespawnTime;
                            // account for current race time via next cp
                            if (p.CpCount < int(best.Length) && p.CurrentRaceTime > int(best[p.CpCount])) {
                                isBehind = true;
                                lastCpTimeVirtual = p.CurrentRaceTime;
                                cpBest = best[p.CpCount];
                            }
                            string time = (p.IsFinished ? (lastCpTimeVirtual <= cpBest ? "\\$5f5" : "\\$f53") : (lastCpTimeVirtual <= cpBest && !isBehind) ? "\\$48f-" : "\\$f84+")
                                + Time::Format(p.IsFinished ? p.LastCpTime : Math::Abs(lastCpTimeVirtual - cpBest))
                                + (isBehind ? " (*)" : "");
                            UI::Text(time);
                        } else {
                            UI::Text("\\$888-:--.---");
                        }

                        UI::PopID();
                    }
                }

                UI::EndTable();
            }
            UI::Unindent();
#else
            // shouldn't show up, but w/e
            UI::Text("MLFeed required.");
#endif
        }
    }

    void DrawChatMoveOns() {
        if (!Chat::HasMoveOns) return;
        auto cp = GetApp().CurrentPlayground;
        auto nbPlayers = cp is null ? 0 : cp.Players.Length;
        auto moveOns = Chat::moveOns.GetSize();
        auto waits = Chat::waits.GetSize();
        auto initPos = UI::GetCursorPos();
        if (moveOns == 0) {
            UI::Text("\\$888Move On: 0 / " + nbPlayers);
        } else {
            UI::Text("\\$3f3Move On: " + moveOns + " / " + nbPlayers);
        }
        UI::SetCursorPos(initPos + vec2(150, 0));
        if (waits == 0) {
            UI::Text("\\$888Wait: 0 / " + nbPlayers);
        } else {
            UI::Text("\\$f33Wait: " + waits + " / " + nbPlayers);
        }
    }

    void DrawChatVotes() {
        if (!Chat::HasVotes) return;
        auto initPos = UI::GetCursorPos();
        if (Chat::goodVotes == 0) {
            UI::Text("\\$888" + Icons::ThumbsUp + ": 0");
        } else {
            UI::Text("\\$4b4" + Icons::ThumbsUp + ": " + Chat::goodVotes);
        }
        UI::SetCursorPos(initPos + vec2(150, 0));
        if (Chat::badVotes == 0) {
            UI::Text("\\$888" + Icons::ThumbsDown + ": 0");
        } else {
            UI::Text("\\$b44" + Icons::ThumbsDown + ": " + Chat::badVotes);
        }
    }

    void RenderNotRunning() {
        UI::Text("\\$f80Should never show!");
    }
    void RenderLoading() {
        UI::Text("Loading...");
        UI::TextWrapped(State::status);
    }
    void RenderInitializing() {
        UI::Text("Initializing...");
        UI::TextWrapped(State::status);
    }
    void RenderFinished() {
        UI::Text("Finished!");
        UI::TextWrapped(State::status);
        UI::Button("Todo start over");
    }
    void RenderError() {
        SubHeading("Error!");
        UI::TextWrapped(State::status);
        UI::Button("Todo retry");
        if (UI::Button("Reset Plugin")) {
            State::HardReset();
        }
    }
}
