const string MM_API_PROD_ROOT = "https://map-monitor.xk.io";
const string MM_API_DEV_ROOT = "http://localhost:8000";

#if DEV
[Setting category="[DEV] Debug" name="Local Dev Server"]
bool S_LocalDev = false;
#else
bool S_LocalDev = false;
#endif

const string MM_API_ROOT {
    get {
        if (S_LocalDev) return MM_API_DEV_ROOT;
        else return MM_API_PROD_ROOT;
    }
}

namespace MapMonitor {
    Json::Value@ GetNbPlayersForMap(const string &in mapUid) {
        return CallMapMonitorApiPath('/map/' + mapUid + '/nb_players/refresh');
    }

    Json::Value@ GetNextMapByTMXTrackID(int TrackID, uint[]@ tags = {}) {
        string ts = tags.Length > 0 ? "?tags=" + tags[0] : "";
        for (uint i = 1; i < tags.Length; i++) {
            ts += "," + tags[i];
        }
        return CallMapMonitorApiPath('/tmx/' + TrackID + '/next' + ts);
    }

    Json::Value@ GetTmxTags() {
        return CallMapMonitorApiPath('/api/tags/gettags');
    }
}
