TmxTag@[] TMX_TAGS = {};
dictionary TMX_TAG_LOOKUP = dictionary();

Meta::PluginCoroutine@ _TmxTagsGetCoro = startnew(InitTmxTagsCoro);

void InitTmxTagsCoro() {
    yield();
    auto resp = MapMonitor::GetTmxTags();
    if (resp is null) {
        NotifyError("Failed to get TMX tags");
        return;
    }
    for (uint i = 0; i < resp.Length; i++) {
        auto tag_j = resp[i];
        TMX_TAGS.InsertLast(TmxTag(tag_j['Name'], tag_j['ID']));
        auto @tag = TMX_TAGS[TMX_TAGS.Length - 1];
        @TMX_TAG_LOOKUP[tag.name] = tag;
    }
    yield();
    LoadTmxTagsSelectionFromCsv();
}

class TmxTag {
    string name;
    uint id;
    TmxTag(const string &in name, uint id) {
        this.name = name;
        this.id = id;
    }

    uint ix {
        get {
            return id - 1;
        }
    }

    // Draw a checkbox for this tag, and return whether it was changed.
    // Pass in a list of booleans, one for each tag, to keep track of which tags are selected.
    bool DrawCheckbox(bool[]@ selectedTags) {
        bool ret = false;
        bool disable = selectedTags is null;
        UI::BeginDisabled(disable);
        if (disable) {
            UI::Checkbox(name, false);
        } else {
            if (selectedTags.Length <= TMX_TAGS.Length) {
                selectedTags.Resize(TMX_TAGS.Length);
            }
            bool before = selectedTags[ix];
            selectedTags[ix] = UI::Checkbox(tostring(id) + ". " + name, selectedTags[ix]);
            ret = before != selectedTags[ix];
        }
        UI::EndDisabled();
        return ret;
    }
}

[Setting hidden]
string S_TmxTagsSelectionCsv = "";

string S_TmxTagsSelectionNamesCsv = "";

bool g_TmxTagWindowOpen = false;

bool[] f_SelectedTmxTags = array<bool>(100, false);

void RenderTmxTagsSelectionWindow() {
    if (!g_TmxTagWindowOpen) return;
    UI::SetNextWindowSize(500, 790, UI::Cond::FirstUseEver);
    if (UI::Begin("Select TMX Tags", g_TmxTagWindowOpen)) {
        DrawCurrentSelectedTmxTags();

        UI::SeparatorText("Select TMX Tags");
        if (UI::Button("Clear All")) {
            for (uint i = 0; i < TMX_TAGS.Length; i++) {
                f_SelectedTmxTags[i] = false;
            }
            UpdateTmxTagsSelectionCsv();
        }

        bool changed = false;
        uint changeEvery = TMX_TAGS.Length / 3;
        UI::Columns(3);

        for (uint i = 0; i < TMX_TAGS.Length; i++) {
            changed = TMX_TAGS[i].DrawCheckbox(f_SelectedTmxTags) || changed;
            if ((i + 1) % changeEvery == 0) {
                UI::NextColumn();
            }
        }
        UI::Columns(1);

        if (changed) {
            UpdateTmxTagsSelectionCsv();
        }
    }
    UI::End();
}

void DrawCurrentSelectedTmxTags() {
    UI::SeparatorText("Current Selected TMX Tags");
    if (S_TmxTagsSelectionCsv.Length == 0) {
        UI::TextWrapped("Any tags");
    } else {
        UI::TextWrapped("Maps with any of:");
    }

    UI::Indent();
    if (S_TmxTagsSelectionCsv.Length == 0) {
        UI::Text("\\$i(still excludes maps that won't work like royal, shootmania, etc).");
    } else {
        UI::Text(S_TmxTagsSelectionNamesCsv + " (" + S_TmxTagsSelectionCsv + ")");
    }
    UI::Unindent();
}

void UpdateTmxTagsSelectionCsv(bool save = true) {
    string csv = "";
    string namesCsv = "";
    for (uint i = 0; i < TMX_TAGS.Length; i++) {
        if (f_SelectedTmxTags[i]) {
            csv += tostring(TMX_TAGS[i].id) + ",";
            namesCsv += TMX_TAGS[i].name + ", ";
        }
    }
    if (csv.Length > 0) {
        csv = csv.SubStr(0, csv.Length - 1);
        namesCsv = namesCsv.SubStr(0, namesCsv.Length - 2);
    }
    S_TmxTagsSelectionCsv = csv;
    S_TmxTagsSelectionNamesCsv = namesCsv;
    if (save) {
        Meta::SaveSettings();
    }
}

void LoadTmxTagsSelectionFromCsv() {
    auto tags = S_TmxTagsSelectionCsv.Split(",");
    for (uint i = 0; i < tags.Length; i++) {
        try {
            uint tagId = Text::ParseUInt(tags[i]);
            if (tagId == 0) {
                warn("Failed to parse TMX tag ID: " + tags[i]);
                continue;
            }
            for (uint j = 0; j < TMX_TAGS.Length; j++) {
                if (TMX_TAGS[j].id == tagId) {
                    f_SelectedTmxTags[TMX_TAGS[j].ix] = true;
                    break;
                }
            }
        } catch {
            warn("Failed to parse TMX tag ID: " + tags[i]);
        }
    }
    UpdateTmxTagsSelectionCsv(false);
}
