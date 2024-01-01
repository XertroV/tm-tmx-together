namespace Live {
    /* use Personal_Best for seasonUid for global leaderboards; <https://webservices.openplanet.dev/live/leaderboards/top> */
    Json::Value@ GetMapRecords(const string &in seasonUid, const string &in mapUid, bool onlyWorld = true, uint length=5, uint offset=0) {
        // Personal_Best
        string qParams = onlyWorld ? "?onlyWorld=true" : "";
        if (onlyWorld) qParams += "&" + LengthAndOffset(length, offset);
        return CallLiveApiPath("/api/token/leaderboard/group/" + seasonUid + "/map/" + mapUid + "/top" + qParams);
    }

    /* use Personal_Best for seasonUid for global leaderboards; <https://webservices.openplanet.dev/live/leaderboards/top> */
    Json::Value@ GetMapRecordsMeat(const string &in seasonUid, const string &in mapUid, bool onlyWorld = true, uint length=5, uint offset=0) {
        auto resp = GetMapRecords(seasonUid, mapUid, onlyWorld, length, offset);
        return resp['tops'][0]['top'];
    }
}
