# Server-Game Scoreboard

**Required Dependency:** Better Room Manager *(You **must** install BRM too)*

This plugin will detect leaderboards for server-based games like TMX Together (could be implemented for RMT, too).

It works by looking for club news posts with a title matching "LB:<Server Name>"

Other games can implement it similar to TMX Together (look for `GetOrCreateClubNewsActivity` and `SaveMedalsToClubNews`)
