[Setting hidden]
bool g_ShowNextMapDebug = false;

void Debug_RenderNextMapWindow() {
    if (!g_ShowNextMapDebug) return;
    UI::SetNextWindowSize(400, 400, UI::Cond::FirstUseEver);
    if (UI::Begin("TMXT - Next Map (Debug)", g_ShowNextMapDebug)) {
        DebugNextMap::Debug_RenderNextMapWindow_Main();
    }
    UI::End();
}

namespace DebugNextMap {
    string m_mapId;

    void Debug_RenderNextMapWindow_Main() {
        auto @cache = MapMonitor::nextCache;
        UI::TextWrapped("Type in a map ID to look up which map comes after it. The next map should almost always be cached.");
        m_mapId = UI::InputText("Lookup Map ID", m_mapId, UI::InputTextFlags::CharsDecimal).Trim();
        int _mapId;
        if (m_mapId.Length == 0) {
            UI::Text("No Map ID");
            auto nbInCache = cache.GetSize();
            UI::Text("Maps in cache: " + nbInCache);
            if (nbInCache > 0) {
                auto keys = cache.GetKeys();
                UI::Text("First Key (not always least): " + keys[0]);
                UI::Text("Last Key (not always greatest): " + keys[keys.Length - 1]);
                if (UI::Button("Clear Cache (0th)")) {
                    cache.Delete(keys[0]);
                }
                if (UI::Button("Clear Cache (Last)")) {
                    cache.Delete(keys[keys.Length - 1]);
                }
                if (UI::Button("Clear Cache (All)")) {
                    cache.DeleteAll();
                }
            }
        } else if (!Text::TryParseInt(m_mapId, _mapId)) {
            UI::Text("Map ID Parse Error");
        } else if (cache.Exists(m_mapId)) {
            auto map = cast<Json::Value>(cache[m_mapId]);
            if (map !is null) {
                UI::Text("Next: " + int(map["next"]) + " ( TTL=" + int(map["ttl"]) + " )");
                UI::Text("> Map: " + string(map["name"]));
                UI::Text("> Author: " + string(map["author"]));
                UI::Text("> Tags: " + Json::Write(map["tag_names"]));
                UI::Text("> Type: " + string(map["type"]));
                UI::Text("> UID: " + string(map["next_uid"]));
                UI::Text("> Prev: " + int(map.Get("prev", -1)));
                if (UI::Button("Next##dbg_nxt")) {
                    m_mapId = tostring(int(map["next"]));
                }
            }
        } else if (MapMonitor::loadingIds.Exists(m_mapId)) {
            UI::Text("Loading...");
            UI::SeparatorText("Debug Tools");
            if (UI::Button("Clear Loading Status")) {
                MapMonitor::loadingIds.Delete(m_mapId);
            }
        } else {
            if (UI::Button("Get Next Map Info for " + m_mapId)) {
                MapMonitor::SignalGetNextMap_Cached(_mapId);
            }
        }
    }

}
