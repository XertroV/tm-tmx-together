Json::Value@ commands;
const string commandsFile = IO::FromStorageFolder("chat-commands.json");

void LoadSavedCommands() {
    if (!IO::FileExists(commandsFile)) InitializeDefaultCommands();
    else @commands = Json::FromFile(commandsFile);
    if (commands is null || commands.GetType() != Json::Type::Array) InitializeDefaultCommands();
}

void InitializeDefaultCommands() {
    @commands = Json::Array();
    AddBuiltinCommands();
    AddNewCommandMsgObj('!about', "Welcome to TMX Together, where we play each TMX map in order. Chat '1' to vote to move on, and '2' to say you want to hunt more. '++', '+', '-', '--' to rate the map. '!help' will list commands.");
    AddNewCommandMsgObj('!twitch', "$l[https://www.twitch.tv/lakantanz]$s$a7e Watch Lakanta live!$l");
    AddNewCommandMsgObj('!wtf', "This is $iTMX Together,$i hosted by $sLakanta$s. Type $s$o!help$s$o for a list of commands. You can also $l[https://www.twitch.tv/lakantanz]$s$a7e Watch Lakanta live on Twitch!$l");
    AddNewCommandMsgObj('!map', "Current map: $l[{map_link}]{map_tmx_id}$l - {map_name} - {map_tmio_link}");
    startnew(SaveCommands);
}

// todo: add default !help command

void AddNewCommandMsgObj(const string &in name, const string &in msg) {
    auto obj = Json::Object();
    obj['msg'] = msg;
    obj['type'] = 'msg';
    obj['name'] = name;
    if (CommandExists(name)) {
        NotifyError("Command exists: " + name);
        return;
    }
    commands.Add(obj);
}

void AddNewCommandBuiltIn(const string &in name) {
    auto obj = Json::Object();
    obj['type'] = 'builtin';
    obj['name'] = name;
    if (CommandExists(name)) {
        NotifyError("Command exists: " + name);
        return;
    }
    commands.Add(obj);
}


bool CommandExists(const string &in name) {
    for (uint i = 0; i < commands.Length; i++) {
        if (name == commands[i]['name']) return true;
    }
    return false;
}


void AddBuiltinCommands() {
    AddNewCommandBuiltIn('!votes');
    AddNewCommandBuiltIn('!help');
    AddNewCommandBuiltIn('!score');
    AddNewCommandBuiltIn('!myscore');
}


[SettingsTab name="Commands" order='5']
void Render_Settings_Commands() {
    if (UI::Button("Backup Commands")) {
        startnew(BackupCommands);
    }
    UI::SameLine();
    if (UI::Button("Reset Commands")) {
        ResetCommands();
    }
    UI::Separator();
    if (UI::Button("Add New Command")) {
        AddNewCommand();
    }
    UI::SameLine();
    if (UI::Button("Add Builtin Commands")) {
        AddBuiltinCommands();
    }

    UI::AlignTextToFramePadding();
    UI::Text("Current Commands:");
    for (uint i = 0; i < commands.Length; i++) {
        DrawCommandSettings(i);
    }
}


void BackupCommands() {
    Json::ToFile(commandsFile + "_" + Time::Stamp, commands);
    OpenExplorerPath(IO::FromStorageFolder(""));
}


void ResetCommands() {
    InitializeDefaultCommands();
}


void DrawCommandSettings(uint i) {
    auto cmd = commands[i];
    string name = cmd['name'];
    UI::PushID("cmd" + i);

    if (UI::CollapsingHeader(name + "###cmdsection" + i)) {
        bool changed1 = false, changed2 = false;
        if (UI::Button("Delete##cmd"+i)) {
            startnew(DeleteCommand, i);
        }
        if ('builtin' == cmd['type']) {
            UI::Text("\\$888Builtin Command: " + name);
        } else if ('msg' == cmd['type']) {
            cmd['name'] = UI::InputText("Name##"+i, name, changed1);
            cmd['msg'] = UI::InputTextMultiline("Message##"+i, string(cmd['msg']), changed2);
        }
        if (changed1 || changed2) {
            startnew(SaveCommands);
        }
    }

    UI::PopID();
}


void DeleteCommand(uint64 i) {
    try {
        commands.Remove(i);
    } catch {
        NotifyError("Could not delete command :(. Error: " + getExceptionInfo());
    }
    startnew(SaveCommands);
}

void AddNewCommand() {
    AddNewCommandMsgObj("!new", "todo: fill me in");
}

void SaveCommands() {
    Json::ToFile(commandsFile, commands);
}

Json::Value@ FindCommand(const string &in name) {
    for (uint i = 0; i < commands.Length; i++) {
        if (name == commands[i]['name']) return commands[i];
    }
    return null;
}

void RunCommand(const string &in name) {
    if (!CommandExists(name)) return;
    auto cmd = FindCommand(name);
    bool isBuiltin = "builtin" == cmd['type'];
    bool isMsg = "msg" == cmd['type'];
    if (isBuiltin) RunBultinCommand(name);
    else if (isMsg) RunMsgCommand(cmd);
}

void RunMsgCommand(Json::Value@ cmd) {
    string msg = cmd['msg'];
    Chat::SendMessage(msg
        .Replace("{map_tmx_id}", tostring(State::lastLoadedId))
        .Replace("{map_link}", "https://trackmania.exchange/maps/" + State::lastLoadedId)
        .Replace("{map_name}", "$<" + GetMapName() + "$>")
        .Replace("{map_tmio}", "https://trackmania.io/#/leaderboard/" + GetMapUid())
        .Replace("{map_tmio_link}", "$l[https://trackmania.io/#/leaderboard/" + GetMapUid() + "]TM.IO$l")
    );
}

void RunBultinCommand(const string &in name) {
    if (name == "!votes") RunVotesBuiltinCmd();
    else if (name == "!help") RunHelpBuiltinCmd();
    else if (name == "!score") RunScoreBuiltinCmd();
    else if (name == "!myscore") RunMyScoreBuiltinCmd();
}

void RunHelpBuiltinCmd() {
    string cmds = "Commands: ";
    for (uint i = 0; i < commands.Length; i++) {
        if (i > 0) cmds += ", ";
        cmds += commands[i]['name'];
    }
    Chat::SendMessage(cmds);
}

void RunVotesBuiltinCmd() {
    Chat::SendMessage(Chat::CurrentVotesStr());
}

void RunScoreBuiltinCmd() {
    Chat::SendMessage(State::BestMedalsSummaryStr());
}

void RunMyScoreBuiltinCmd() {
    auto pmc = State::GetPlayerMedalCountFor(LoginToWSID(Chat::currentMsgSenderLogin));
    string ret = "";
    if (pmc is null) ret += Chat::currentMsgSenderName + ": No finishes found";
    else ret += pmc.GetSummaryStr();
    Chat::SendMessage(ret);
}
