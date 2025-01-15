Json::Value@ FetchLiveEndpoint(const string &in route) {
    NadeoServices::AddAudience("NadeoLiveServices");
    while (!NadeoServices::IsAuthenticated("NadeoLiveServices")) yield();

    log_trace("[FetchLiveEndpoint] Requesting: " + route);
    auto req = NadeoServices::Get("NadeoLiveServices", route);
    req.Start();
    while(!req.Finished()) { yield(); }
    return req.Json();
}

Json::Value@ FetchClubEndpoint(const string &in route) {
    NadeoServices::AddAudience("NadeoLiveServices");
    while (!NadeoServices::IsAuthenticated("NadeoLiveServices")) yield();

    log_trace("[FetchClubEndpoint] Requesting: " + route);
    auto req = NadeoServices::Get("NadeoLiveServices", route);
    req.Start();
    while(!req.Finished()) { yield(); }
    return req.Json();
}

Net::HttpRequest@ PostLiveEndpoint(const string &in route, Json::Value@ data) {
    AssertGoodPath(route);
    NadeoServices::AddAudience("NadeoLiveServices");
    while (!NadeoServices::IsAuthenticated("NadeoLiveServices")) yield();

    string url = NadeoServices::BaseURLLive() + route;
    log_trace("[PostLiveEndpoint] Requesting: " + url);
    auto req = NadeoServices::Post("NadeoLiveServices", url, Json::Write(data));
    req.Start();
    while(!req.Finished()) { yield(); }
    return req;
}

Json::Value@ CallLiveApiPath(const string &in path) {
    AssertGoodPath(path);
    return FetchLiveEndpoint(NadeoServices::BaseURLLive() + path);
}

Json::Value@ CallCompApiPath(const string &in path) {
    AssertGoodPath(path);
    return FetchClubEndpoint(NadeoServices::BaseURLMeet() + path);
}

Json::Value@ CallClubApiPath(const string &in path) {
    AssertGoodPath(path);
    return FetchClubEndpoint(NadeoServices::BaseURLMeet() + path);
}

Json::Value@ CallMapMonitorApiPath(const string &in path) {
    AssertGoodPath(path);
    // auto token = MM_Auth::GetCachedToken();
    auto url = MM_API_ROOT + path;
    log_trace("[CallMapMonitorApiPath] Requesting: " + url);
    Net::HttpRequest@ req = Net::HttpRequest();
    req.Url = MM_API_ROOT + path;
    req.Headers['User-Agent'] = 'TmxTogether/Openplanet-Plugin/contact=@XertroV';
    // req.Headers['Authorization'] = 'openplanet ' + token;
    req.Method = Net::HttpMethod::Get;
    req.Start();
    while(!req.Finished()) { yield(); }
    return req.Json();
}

// Ensure we aren't calling a bad path
void AssertGoodPath(string &in path) {
    if (path.Length <= 0 || !path.StartsWith("/")) {
        throw("API Paths should start with '/'!");
    }
}

// Length and offset get params helper
const string LengthAndOffset(uint length, uint offset) {
    return "length=" + length + "&offset=" + offset;
}


Net::HttpRequest@ PluginRequest(const string &in url) {
    Net::HttpRequest@ r = Net::HttpRequest();
    r.Url = url;
    // r.Headers['User-Agent'] = "TM_Plugin:" + Meta::ExecutingPlugin().Name + " / contact=@XertroV,m@xk.io / client_version=" + Meta::ExecutingPlugin().Version;
    return r;
}

Net::HttpRequest@ PluginPostRequest(const string &in url) {
    auto r = PluginRequest(url);
    r.Method = Net::HttpMethod::Post;
    return r;
}

Net::HttpRequest@ PluginGetRequest(const string &in url) {
    auto r = PluginRequest(url);
    r.Method = Net::HttpMethod::Get;
    return r;
}


namespace Http {
    int64 GetFileSize(const string &in url) {
        log_debug("GetFileSize: Requesting " + url);
        auto req = PluginRequest(url);
        req.Method = Net::HttpMethod::Head;
        req.Start();
        while(!req.Finished()) { yield(); }
        auto respCode = req.ResponseCode();
        log_debug("GetFileSize: Response code " + respCode);
        if (respCode == 200) {
            try {
                auto len = req.ResponseHeader("content-length");
                log_debug("GetFileSize: Content-Length " + len);
                // auto body = req.String(); // Ensure we read the response
                // log_debug('req body: ' + req.String());
                // log_debug('req error: ' + req.Error());
                log_debug('returning filesize: ' + Text::ParseInt64(len));
                return Text::ParseInt64(len);
            } catch {
                log_warn("GetFileSize: Failed to get Content-Length from response headers for " + url);
                log_warn(getExceptionInfo());
                return -1;
            }
        }
        // redirects seem to be followed automatically
        // else if (respCode == 307) {
        //     auto loc = req.ResponseHeader("location");
        //     if (loc.Length > 0) {
        //         log_debug("GetFileSize: Http 307 Redirecting to " + loc);
        //         return GetFileSize(loc);
        //     }
        //     log_warn("GetFileSize: Http 307 Error: Failed to get location from response headers for " + url);
        //     log_warn("GetFileSize: Http 307 Error: Response Headers: " + Json::Write(req.ResponseHeaders().ToJson()));
        //     return -1;
        // }
        log_warn("GetFileSize Error: Failed to get Content-Length from response headers for " + url);
        log_warn("GetFileSize Error: Response code " + respCode + " / error: " + req.Error());
        return -1;
    }
}
