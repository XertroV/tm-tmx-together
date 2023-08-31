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
        UI::Text("Current Map: " + State::loadNextId);
        // UI::SetNextItemWidth(130);
        // S_LastTmxID = UI::InputInt("Next Map", S_LastTmxID + 1) - 1;
        auto cp = UI::GetCursorPos();
        if (UI::Button("Next")) {
            startnew(State::LoadNextTmxMap);
        }
        UI::SetCursorPos(cp + vec2(130, 0));
        if (UI::Button("To Lobby")) {
            startnew(State::BackToLobby);
        }
        if (State::mapTimeLimitWithExt > 0) {
            UI::Separator();
            if (UI::Button("Extend Time Limit")) {
                startnew(State::ExtendTimeLimit);
            }
            if (UI::Button("Remove Time Limit")) {
                startnew(State::RemoveTimeLimit);
            }
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
