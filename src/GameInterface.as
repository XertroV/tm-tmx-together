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

    }

    void DrawChatMoveOns() {
        if (!Chat::HasMoveOns) return;
        auto moveOns = Chat::moveOns.GetSize();
        auto waits = Chat::waits.GetSize();
        auto initPos = UI::GetCursorPos();
        if (moveOns == 0) {
            UI::Text("\\$888Move On: 0");
        } else {
            UI::Text("\\$3f3Move On: " + moveOns);
        }
        UI::SetCursorPos(initPos + vec2(150, 0));
        if (waits == 0) {
            UI::Text("\\$888Wait: 0");
        } else {
            UI::Text("\\$f33Wait: " + waits);
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
