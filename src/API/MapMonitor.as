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

    Json::Value@ GetNextMapByTMXTrackID(int TrackID, const string &in tags_csv = "") {
        string gs = "?extra=5";
        if (tags_csv.Length > 0) gs += "&tags=" + tags_csv;
        return CallMapMonitorApiPath('/tmx/' + TrackID + '/next' + gs);
    }

    Json::Value@ GetTmxTags() {
        return CallMapMonitorApiPath('/api/tags/gettags');
    }
}
