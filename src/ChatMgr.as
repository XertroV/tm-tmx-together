namespace Chat {
    void SendMessage(const string &in msg) {
        auto cp = GetApp().CurrentPlayground;
        if (cp is null || cp.Interface is null) return;
        cp.Interface.ChatEntry = msg;
    }

    NGameScriptChat_SHistory@ hist;
    void ChatCoro() {
        while (true) {
            yield();
            if (State::IsRunning)
                CheckChat();
        }
    }

    void CheckChat() {
        if (hist is null) InitHist();
        // print("" + hist.PendingEvents.Length);
        for (uint i = 0; i < hist.PendingEvents.Length; i++) {
            auto chatEvt = cast<NGameScriptChat_SEvent_NewEntry>(hist.PendingEvents[i]);
            if (chatEvt is null) continue;
            if (!chatEvt.Entry.IsSystemMessage) {
                CheckMsg(chatEvt);
            }
        }
    }

    void InitHist() {
        auto mgr = GetApp().ChatManagerScriptV2;
        if (mgr is null || mgr.Contextes.Length == 0) return;
        auto ctx = mgr.Contextes[0];
        @hist = ctx.History_Create("t", 20);
    }

    void Unload() {
        if (hist is null) return;
        auto mgr = GetApp().ChatManagerScriptV2;
        if (mgr is null || mgr.Contextes.Length == 0) return;
        auto ctx = mgr.Contextes[0];
        ctx.History_Destroy(hist);
    }

    dictionary moveOns;
    dictionary waits;
    dictionary votes;
    int goodVotes = 0;
    int badVotes = 0;

    void ResetState() {
        moveOns.DeleteAll();
        waits.DeleteAll();
        votes.DeleteAll();
        goodVotes = 0;
        badVotes = 0;
    }

    bool get_HasInfo() {
        return goodVotes != 0 || badVotes != 0 || moveOns.GetSize() > 0 || waits.GetSize() > 0;
    }
    bool get_HasVotes() {
        return goodVotes != 0 || badVotes != 0;
    }
    bool get_HasMoveOns() {
        return moveOns.GetSize() > 0 || waits.GetSize() > 0;
    }

    void CheckMsg(NGameScriptChat_SEvent_NewEntry@ e) {
        string text = string(wstring(e.Entry.Text)).Trim();
        if (text == "1") OnMoveOn(e);
        else if (text == "2") OnWait(e);
        else if (text == "+") OnVote(e, 1);
        else if (text == "-") OnVote(e, -1);
        else if (text == "++") OnVote(e, 2);
        else if (text == "--") OnVote(e, -2);
    }

    void OnMoveOn(NGameScriptChat_SEvent_NewEntry@ e) {
        auto login = string(e.Entry.SenderLogin);
        moveOns[login] = true;
        if (waits.Exists(login)) waits.Delete(login);
    }
    void OnWait(NGameScriptChat_SEvent_NewEntry@ e) {
        auto login = string(e.Entry.SenderLogin);
        waits[login] = true;
        if (moveOns.Exists(login)) moveOns.Delete(login);
    }
    void OnVote(NGameScriptChat_SEvent_NewEntry@ e, int amt) {
        auto login = string(e.Entry.SenderLogin);
        SubVotes(login);
        AddVotes(login, amt);
    }
    void AddVotes(const string &in login, int amt) {
        if (amt > 0) goodVotes += amt;
        else badVotes += amt;
        votes[login] = amt;
    }
    void SubVotes(const string &in login) {
        if (votes.Exists(login)) {
            int prevVote = int(votes[login]);
            if (prevVote > 0) goodVotes -= prevVote;
            else badVotes -= prevVote;
        }
    }
}
