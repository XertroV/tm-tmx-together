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

    Json::Value@ GetNextMapByTMXTrackID(int TrackID, const string &in tags_csv = "", int nbExtra = -1) {
        string gs = nbExtra <= 0 ? "?extra=5" : ("?extra=" + nbExtra);
        if (tags_csv.Length > 0) gs += "&tags=" + tags_csv;
        return CallMapMonitorApiPath('/tmx/' + TrackID + '/next' + gs);
    }

    Json::Value@ GetTmxTags() {
        return CallMapMonitorApiPath('/api/tags/gettags');
    }

    dictionary@ loadingIds = dictionary();
    dictionary@ nextCache = dictionary();

    class GetNextPayload {
        string tags_csv;
        int TrackID;
        GetNextPayload(const string &in tags_csv, int TrackID) {
            this.tags_csv = tags_csv;
            this.TrackID = TrackID;
        }
    }

    string lastTagsCsv = "";
    void IfTagsChangedClearCache(const string &in tags_csv) {
        if (lastTagsCsv == tags_csv) return;
        lastTagsCsv = tags_csv;
        nextCache.DeleteAll();
        loadingIds.DeleteAll();
    }

    Json::Value@ GetNextCached(const string &in mapUid) {
        if (nextCache.Exists(mapUid)) {
            return cast<Json::Value>(nextCache[mapUid]);
        }
        return null;
    }

    // can call from UI
    void SignalGetNextMap_Cached(int TrackID, const string &in tags_csv = "") {
        IfTagsChangedClearCache(tags_csv);
        auto k = tostring(TrackID);
        if (loadingIds.Exists(k)) return;
        if (nextCache.Exists(k)) return;
        startnew(CoroutineFuncUserdata(PrepopulateNextMap_Async), GetNextPayload(tags_csv, TrackID));
        startnew(CoroutineFuncUserdata(EnsurePrepopulatedInAdvance), GetNextPayload(tags_csv, TrackID));
    }

    [Setting hidden]
    int minBufferedMaps = 7;

    int lastPrepopCheck_MapId = -1;
    void EnsurePrepopulatedInAdvance(ref@ payload) {
        minBufferedMaps = Math::Max(minBufferedMaps, 3);
        auto pl = cast<GetNextPayload>(payload);
        if (lastPrepopCheck_MapId == pl.TrackID) return;
        log_trace("PrepopulateNextMap_Async: " + pl.TrackID);
        lastPrepopCheck_MapId = pl.TrackID;
        auto maps_NbBuffered_LastId = CountMapsBufferedFrom(pl.TrackID);
        if (maps_NbBuffered_LastId.x > minBufferedMaps) return;
        log_trace("PrepopulateNextMap_Async: sleeping for a bit");
        sleep(2000 + Math::Rand(3000, 7000));
        maps_NbBuffered_LastId = CountMapsBufferedFrom(pl.TrackID);
        log_trace("PrepopulateNextMap_Async: maps_NbBuffered_LastId = " + maps_NbBuffered_LastId.ToString());
        if (maps_NbBuffered_LastId.x > minBufferedMaps) return;
        log_trace("Not enough maps buffered after " + pl.TrackID + ": " + maps_NbBuffered_LastId.x + " / " + minBufferedMaps + ". Getting more...");
        AwaitNextMap_Cached(maps_NbBuffered_LastId.y, pl.tags_csv, Math::Min(minBufferedMaps, 20), true);
        startnew(CoroutineFuncUserdata(EnsurePrepopulatedInAdvance), pl);
    }

    // returns (nbBuffered, )
    int2 CountMapsBufferedFrom(int TrackID) {
        int2 nbBuffered_and_MapId = int2(0, TrackID);
        string k = tostring(TrackID);
        while (nextCache.Exists(k)) {
            nbBuffered_and_MapId.x += 1;
            auto next = GetNextCached(k);
            TrackID = next["next"];
            nbBuffered_and_MapId.y = TrackID;
            k = tostring(TrackID);
        }
        return nbBuffered_and_MapId;
    }

    void PrepopulateNextMap_Async(ref@ payload) {
        auto pl = cast<GetNextPayload>(payload);
        AwaitNextMap_Cached(pl.TrackID, pl.tags_csv);
    }

    Json::Value@ AwaitNextMap_Cached(int TrackID, const string &in tags_csv = "", int getNbExtra = 5, bool forceRefresh = false) {
        IfTagsChangedClearCache(tags_csv);
        string k = tostring(TrackID);
        while (loadingIds.Exists(k)) yield();
        if (nextCache.Exists(k) && !forceRefresh) {
            return cast<Json::Value>(nextCache[k]);
        }

        bool failed = false;
        loadingIds[k] = true;
        Json::Value@ nextMap;
        try {
            @nextMap = GetNextMapByTMXTrackID(TrackID, tags_csv, getNbExtra);
            if (nextMap is null) throw("Null response from Map Monitor Next API");
            if (nextMap.GetType() != Json::Type::Object) throw("Invalid response from Map Monitor API: Not an object");
            if (!nextMap.HasKey("next")) throw("Invalid response from Map Monitor API: Missing 'next' key");
            if (nextMap.Get("next").GetType() != Json::Type::Number) throw("Invalid response from Map Monitor API: 'next' is not a number");
        } catch {
            NotifyWarning("Error fetching next map: " + getExceptionInfo());
            failed = true;
        }
        loadingIds.Delete(k);
        if (failed || nextMap is null) return null;

        int nbExtra = nextMap.Get("extra_nb", 0);
        nextMap["ttl"] = nbExtra;
        nextMap["prev"] = TrackID;
        @nextCache[k] = nextMap;
        dev_trace("NextMap.next type: " + tostring(nextMap["next"].GetType()));
        TrackID = nextMap["next"];
        k = tostring(TrackID);
        State::SignalCache_UploadAndSmallCheck(nextMap["next_uid"]);

        if (nextMap.HasKey("extra") && nbExtra > 0) {
            auto extraMaps = nextMap["extra"];
            for (int i = 0; i < nbExtra; i++) {
                auto extraMap = extraMaps[i];
                if (extraMap !is null) {
                    extraMap["ttl"] = (nbExtra - 1 - i);
                    extraMap["prev"] = TrackID;
                    @nextCache[k] = extraMap;
                    TrackID = extraMap["next"];
                    k = tostring(TrackID);
                    State::SignalCache_UploadAndSmallCheck(extraMap["next_uid"]);
                }
            }
        }
        return nextMap;
    }
}
