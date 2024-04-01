[SettingsTab name="Finish Msgs" icon="Flag"]
void RenderSettings_FinishMsgs() {
    if (FinishMsgs is null) {
        UI::Text("Didn't expect finish messages to be null.");
        if (UI::Button("Load Finish Messages")) {
            LoadCustomFinishMessages();
        }
        return;
    }
    if (FinishMsgs.GetType() != Json::Type::Array) {
        UI::Text("Finish messages was not an array.");
        return;
    }

    UI::TextWrapped("Add custom finish messages for when someone is the winning player. If they have more than 1 message, one will be chosen at random.");
    UI::TextWrapped("\\$cccNote: a backup file is saved in the plugin storage folder -- it is overwritten when you start the game. So if you accidentally delete anything, you should try to recover it from there.");
    if (UI::Button("Open Plugin Storage Folder")) {
        OpenExplorerPath(IO::FromStorageFolder(""));
    }
    if (UI::Button("Add Default Entries (For Lakanta)")) {
        AddDefaultEntriesForLakanta();
    }
    UI::AlignTextToFramePadding();
    UI::Text("Total Players with Custom Msgs: " + FinishMsgs.Length);
    UI::SameLine();
    if (UI::Button(Icons::Plus + "##-add-new-payrecustommsg")) {
        FinishMsgs.Add(Json::Object());
        WriteCustomFinishMessages();
    }
    UI::Separator();
    bool changed = false;
    int[] toRem;
    for (uint i = 0; i < FinishMsgs.Length; i++) {
        auto @row = FinishMsgs[i];
        changed = DrawCustomFinishMessageRow(row, i, toRem) || changed;
        UI::Separator();
    }
    for (int i = toRem.Length - 1; i >= 0 ; i--) {
        FinishMsgs.Remove(toRem[i]);
    }
    if (changed) {
        WriteCustomFinishMessages();
    }
}

/*
    [
        {
            wsid: string,
            name: string,
            messages: [
                string
            ]
        }
    ]
*/

bool DrawCustomFinishMessageRow(Json::Value@ row, uint i, int[]@ toRem) {
    bool changed = false;
    UI::PushID(tostring(i) + "dcfmr");
    if (UI::Button(Icons::Times + "##-rem-rowmsg-" + i)) {
        toRem.InsertLast(i);
        changed = true;
    }
    UI::SameLine();
    bool idChanged;
    UI::SetNextItemWidth(200.0);
    row["wsid"] = UI::InputText("WSID", row.Get("wsid", ""), idChanged);
    if (idChanged) {
        auto pmt = State::FindPlayerMedalCountFor(WSIDToLogin(row["wsid"]));
        if (pmt is null) row["name"] = "<Player Not Found>";
        else row["name"] = pmt.name;
    }
    UI::SameLine();
    UI::Text("\\$cccPlayer Name: " + string(row.Get("name", "")));
    bool msgsChanged = DrawCustomFinishMessageRowMessages(row);
    UI::PopID();
    return changed || msgsChanged;
}


bool DrawCustomFinishMessageRowMessages(Json::Value@ row) {
    bool anyChanged = false;
    if (row["messages"].GetType() != Json::Type::Array) {
        row["messages"] = Json::Array();
    }
    Json::Value@ msgs = row["messages"];
    uint[] toRem;
    UI::AlignTextToFramePadding();
    UI::Text(Text::Format("Messages: (%d)", msgs.Length));
    UI::SameLine();
    if (UI::Button(Icons::Plus + "##-add-msg")) {
        msgs.Add("");
        anyChanged = true;
    }
    UI::Indent();
    for (uint i = 0; i < msgs.Length; i++) {
        UI::PushID(tostring(i) + "dcfmrmsg");
        bool msgChanged;
        UI::SetNextItemWidth(200.0);
        msgs[i] = UI::InputText("##msg-" + i, msgs[i], msgChanged);
        UI::SameLine();
        if (UI::Button(Icons::TrashO + "##-rem-msg-" + i)) {
            msgChanged = true;
            toRem.InsertLast(i);
        }
        if (msgChanged) {
            anyChanged = true;
        }
        UI::PopID();
    }
    UI::Unindent();
    for (int i = toRem.Length - 1; i >= 0 ; i--) {
        msgs.Remove(toRem[i]);
    }
    return anyChanged;
}


const string FINISH_MSGS_PATH = IO::FromStorageFolder("custom-finish-messages.json");
const string FINISH_MSGS_BACKUP_PATH = IO::FromStorageFolder("custom-finish-messages_backup.json");
const string FINISH_MSGS_BACKUP2_PATH = IO::FromStorageFolder("custom-finish-messages_backup2.json");
Json::Value@ FinishMsgs;

void LoadCustomFinishMessages() {
    if (IO::FileExists(FINISH_MSGS_BACKUP_PATH)) {
        IO::Move(FINISH_MSGS_BACKUP_PATH, FINISH_MSGS_BACKUP2_PATH);
    }
    yield();
    if (!IO::FileExists(FINISH_MSGS_PATH)) {
        Json::ToFile(FINISH_MSGS_PATH, Json::Array());
    }
    yield();
    @FinishMsgs = Json::FromFile(FINISH_MSGS_PATH);
    if (FinishMsgs.GetType() != Json::Type::Array) {
        NotifyWarning("Loaded finish messages but was not an array");
        @FinishMsgs = Json::Array();
    }
    yield();
    Json::ToFile(FINISH_MSGS_BACKUP_PATH, FinishMsgs);
}

void WriteCustomFinishMessages() {
    Json::ToFile(FINISH_MSGS_PATH, FinishMsgs);
    // trace('Wrote custom finish messages');
}

string GetWSIDToCustomMessage(const string &in wsid) {
    if (FinishMsgs is null) {
        return "";
    }
    for (uint i = 0; i < FinishMsgs.Length; i++) {
        auto @row = FinishMsgs[i];
        if (wsid == row["wsid"]) {
            auto @msgs = row["messages"];
            if (msgs.GetType() == Json::Type::Array && msgs.Length > 0) {
                return msgs[Math::Rand(0, msgs.Length)];
            }
        }
    }
    return "";
}

void AddDefaultEntriesForLakanta() {
    if (FinishMsgs is null) {
        NotifyWarning("Unexpected null finish msgs");
        return;
    }
    FinishMsgs.Add(MakeFinishMsgRow(Lakanta_WSID, {"$7f7 gz Lakanta! Hopefully not last. lakant2Speed lakant2Speed lakant2Speed"}));
    FinishMsgs.Add(MakeFinishMsgRow(Tyler_WSID, {"$f19 Tyler_Mayhem is really cool"}));
    FinishMsgs.Add(MakeFinishMsgRow(XertroV_WSID, {"$aaa$i Shirley not rigged."}));
    FinishMsgs.Add(MakeFinishMsgRow(Noimad_WSID, {"$S$229 BEDGE"}));
    FinishMsgs.Add(MakeFinishMsgRow(Kora_WSID, {"$z$s Was there a cut?", "I actually don't have a message for this xdd"}));
}

Json::Value@ MakeFinishMsgRow(const string &in wsid, const array<string> &in msgs) {
    Json::Value@ row = Json::Object();
    row["wsid"] = wsid;
    auto pmt = State::FindPlayerMedalCountFor(WSIDToLogin(wsid));
    if (pmt is null) row["name"] = "<Player Not Found>";
    else row["name"] = pmt.name;
    Json::Value@ msgArr = Json::Array();
    for (uint i = 0; i < msgs.Length; i++) {
        msgArr.Add(msgs[i]);
    }
    row["messages"] = msgArr;
    return row;
}
