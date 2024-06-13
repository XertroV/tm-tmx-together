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

    Json::Value@ ClubRoomWhoAmI(const string &in serverLogin) {
        return CallLiveApiPath("/api/club/room/"+serverLogin+"/whoami");
    }

    // https://webservices.openplanet.dev/live/clubs/activities
    Json::Value@ GetClubActivities(int clubId, uint length=100, uint offset=0, bool onlyActive = true) {
      	// https://live-services.trackmania.nadeo.live/api/token/club/{clubId}/activity?length={length}&offset={offset}
        return CallLiveApiPath("/api/token/club/"+clubId+"/activity?active="+tostring(onlyActive)+"&"+LengthAndOffset(length, offset));
    }

    // name max: 20 chars
    // headline max: 40 chars
    // body max: 2000 chars
    Json::Value@ SetNewsDetails(int clubId, int activityId, const string &in name, const string &in headline, const string &in body) {
        Json::Value@ data = Json::Object();
        data["name"] = name;
        data["headline"] = headline;
        data["body"] = body;
        // https://live-services.trackmania.nadeo.live/api/token/club/46587/news/602018/edit
        auto req = PostLiveEndpoint("/api/token/club/"+clubId+"/news/"+activityId+"/edit", data);
        auto code = req.ResponseCode();
        log_trace("SetNewsDetails: "+code+" / "+req.String());
        if (code == 0) {
            log_trace(req.Error());
        }
        return req.Json();
    }

    Json::Value@ GetNewsDetails(int clubId, int activityId) {
        // https://live-services.trackmania.nadeo.live/api/token/club/46587/news/602018
        return CallLiveApiPath("/api/token/club/"+clubId+"/news/"+activityId);
    }

    Json::Value@ CreateNews(int clubId, const string &in name, const string &in headline, const string &in body) {
        Json::Value@ data = Json::Object();
        data["name"] = name;
        data["headline"] = headline;
        data["body"] = body;
        // https://live-services.trackmania.nadeo.live/api/token/club/46587/news/create
        auto req = PostLiveEndpoint("/api/token/club/"+clubId+"/news/create", data);
        auto code = req.ResponseCode();
        log_trace("CreateNews: "+code+" / "+req.String());
        if (code == 0) {
            log_trace(req.Error());
        }
        return req.Json();
    }
}
