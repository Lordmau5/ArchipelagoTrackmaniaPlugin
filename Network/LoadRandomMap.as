bool isQueryingForMap   = false;
bool isNextMapLoading   = false;
bool isRerollingMap     = false;

namespace MX
{
    const dictionary ModesFromMapType = {
#if MP4
        // ManiaPlanet
        { "Race",                     "" }, // Base ManiaPlanet Map Type
        { "TrackMania\\Race",         "" },
        { "Platform",                 "" },
        { "Stunts",                   "" },
        { "GoalHuntArena",            "GoalHunt" },
        { "HuntersArena",             "Hunters" },
        { "PursuitArena",             "Pursuit" },
        { "TMOne\\PlatformOneArena",  "" },
        { "EW Stunts - Score Attack", "ExtraWorldSolo" },
        { "EW Race - Time Attack",    "ExtraWorldSolo"}
#elif TMNEXT
        { "TM_Race",                  "" },
        { "TM_Stunt",                 "TrackMania/TM_StuntSolo_Local" },
        { "TM_Platform",              "TrackMania/TM_Platform_Local" },
        { "TM_Royal",                 "TrackMania/TM_RoyalTimeAttack_Local" }
#endif
    };

    const dictionary ModesFromTitlePack = {
#if MP4
        // Base title packs
        { "TMCanyon",        "SingleMap" },
        { "TMStadium",       "SingleMap" },
        { "TMValley",        "SingleMap" },
        { "TMLagoon",        "SingleMap" },

        // Envimix
        { "TMAll",           "SingleMap" },
        { "Envimix_Turbo",   "EnvimixSolo" },
        { "Nadeo_Envimix",   "EnvimixSolo" },

        // Environments recreations
        // TMOne's script doesn't work outside campaigns
        // { "TMOneAlpine",     "Unbitn/TMOne/TimeAttackOne" },
        // { "TMOneSpeed",      "Unbitn/TMOne/TimeAttackOne" },
        { "TMOneBay",        "Unbitn/TMOne/TimeAttackOne" },
        { "TM2Rally",        "GlobalSolo" },
        { "TM2U_Island",     "SoloUni" },
        { "TM2_Coast",       "CoastSolo" },

        // Gamemodes recreations
        { "Platform",        "PlatformSolo" },
        { "ExtraWorld",      "ExtraWorldSolo" },
        { "ModePlus",        "GlobalSolo" },

        // Competition
        { "esl_comp",        "SingleMap" },

        // Other
        { "TMPlus_Canyon",   "SingleMap" },
        { "TMPlus_Lagoon",   "SingleMap" }
#endif
    };
}

class RerollMapInfo
{
    int     seriesIndex;
    int     mapIndex;
}

RerollMapInfo@ GetRerollMapInfo(int seriesIndex, int mapIndex)
{
    RerollMapInfo@ info = RerollMapInfo();

    info.seriesIndex    = seriesIndex;
    info.mapIndex       = mapIndex;

    return info;
}

void RerollMapFromUI(int seriesIndex, int mapIndex)
{
    isRerollingMap = true;

    startnew(RerollMap, GetRerollMapInfo(seriesIndex, mapIndex));
}

void RerollMap(ref@ rerollMapInfo)
{
    RerollMapInfo@ info = cast<RerollMapInfo@>(rerollMapInfo);
    if (info is null)
    {
        isRerollingMap = false;
        return;
    }

    int seriesIndex = info.seriesIndex;
    int mapIndex    = info.mapIndex;

    if (seriesIndex < 0 || uint(seriesIndex) >= data.world.Length)
    {
        isRerollingMap = false;
        return;
    }

    if (mapIndex < 0 || uint(mapIndex) >= data.world[seriesIndex].maps.Length)
    {
        isRerollingMap = false;
        return;
    }

    Log::Log("Rerolling Series " + (seriesIndex + 1) + ", Map " + (mapIndex + 1) + ". One second please!", true);
    
    MapState@ mapState          = data.world[seriesIndex].maps[mapIndex];
    SearchCriteria@ URLBuilder  = data.world[seriesIndex].searchBuilder;

    MapInfo@ mapRoll = QueryForRandomMap(URLBuilder);
    if (mapRoll is null)
    {
        isRerollingMap = false;

        Log::Error("Unable to reroll map", true);
        return;
    }

    isRerollingMap = false;

    mapState.ReplaceMap(mapRoll);

    // Only start a new map if we're already playing one
    if (GetIsOnMap())
    {
        startnew(LoadMap, mapRoll);
    }
}

void LoadMapByIndex(int seriesIndex, int mapIndex)
{
    @loadedMap = data.GetMap(seriesIndex, mapIndex);

    if (loadedMap !is null)
    {
        MapInfo@ info = loadedMap.mapInfo;

        startnew(LoadMap, info);
    }
}

void LoadMap(ref@ mapData)
{
#if TMNEXT
    if (!Permissions::PlayLocalMap())
    {
        Log::Log("Club Access is required to use this plugin, sorry!", true);
        return;
    }
#elif MP4
    CTrackMania@ app = cast<CTrackMania>(GetApp());
    if (app is null || app.ManiaTitles.Length == 0)
    {
        Log::Log("No title packs found. Are you in the stations menu yet?", true);
        return;
    }
#endif
    try
    {
        MapInfo@ map = cast<MapInfo@>(mapData);

        if (map is null)
        {
            warn ("Error, tried to load null map");
            return;
        }

        if (!IsCurrentTitlepackCompatible(map.TitlePack))
        {
            LoadTitlePack(map.TitlePack);
            yield();
        }

        if (!IsCurrentTitlepackCompatible(map.TitlePack))
        {
            Log::Error("Could not load title pack.", true);
            return;
        }

        isNextMapLoading = true;

        Log::LoadingMapNotification(map);

        ClosePauseMenu();
        BackToMainMenu(); // If we're on a map, go back to the main menu else we'll get stuck on the current map

        while(!app.ManiaTitleControlScriptAPI.IsReady)
        {
            yield(); // Wait until the ManiaTitleControlScriptAPI is ready for loading the next map
        }

        string Mode = "";
        MX::ModesFromMapType.Get(map.MapType, Mode);

#if MP4
        if (Mode == "")
        {
            const string loadedTP = CurrentTitlePack();
            MX::ModesFromTitlePack.Get(loadedTP, Mode);
        }
#endif

        app.ManiaTitleControlScriptAPI.PlayMap("https://" + MX_URL + "/mapgbx/" + map.MapId, Mode, "");
        isNextMapLoading = false;
    }
    catch
    {
        Log::Error("Could not load map. TMX API is not responding, it might be down...", true);
        isNextMapLoading = false;
    }
}

MapInfo@ QueryForRandomMap(SearchCriteria@ URLBuilder)
{
    if (!socket.NotDisconnected()) return null;

    isQueryingForMap    = true;
    bool reroll         = false;

    Json::Value@ res;
    Json::Value@ mapJson;

    while (true)
    {
        try
        {
            string URL  = URLBuilder.BuildQueryURL();
            @res        = API::GetAsync(URL)["Results"];
        }
        catch
        {
            Log::Error("Could not reach TMX, it might be down...", true);
            break;
        }

        if (data is null) break;

        if (res.GetType() != Json::Type::Array || res.Length == 0)
        {
            if (URLBuilder.forceSafeURL)
            {
                Log::Error("Unable to find any maps!", true);
                break;
            }

            URLBuilder.forceSafeURL = true;

            Log::Error("Search either returned no results or errored, entering safe mode and retrying...", true);
            sleep(1000);
            continue;
        }

        @mapJson = res[0];
        Log::Trace("Next Map: " + Json::Write(mapJson));
        if (!IsMapValid(mapJson))
        {
            Log::Warn("Map contains pre-patch physics, retrying...");
            sleep(1000);
            continue;
        }

        string mapUid = mapJson["MapUid"];
        if (!reroll && data.previouslySeenMaps.Exists(mapUid))
        {
            reroll = true;

            Log::Warn("Map was previously rolled, retrying once...");
            sleep(1000);
            continue;
        }

        data.previouslySeenMaps.Set(mapUid, true);

        MapInfo@ map = MapInfo(mapJson);
        if (map is null)
        {
            Log::Warn("Map is null, retrying...");
            sleep(1000);
            continue;
        }

        isQueryingForMap = false;
        return map;
    }

    isQueryingForMap = false;
    return null;
}

bool IsMapValid(Json::Value@ mapJson)
{
    //automatically throw out pre-patch ice and bob and water
    //sorry, I want this to be accessible to new players and I don't want to make them deal with pre-patch
    //nando plz add physics versioning
#if TMNEXT
    string exebuild = mapJson["Exebuild"];
    auto mapTags    = mapJson["Tags"];

    for(uint patchID = 0; patchID < PHYSICS_PATCHES.Length; patchID++)
    {
        auto patch = PHYSICS_PATCHES[patchID];

        if (exebuild <= patch.exebuild)
        {
            for (uint tagIndex = 0; tagIndex < patch.tags.Length; tagIndex++)
            {
                for (uint mapTagIndex = 0; mapTagIndex < mapTags.Length; mapTagIndex++)
                {
                    int physicsTagId    = int(TMX_TAGS[patch.tags[tagIndex]]);
                    int mapTagId        = int(mapTags[mapTagIndex]["TagId"]);

                    if (physicsTagId == mapTagId)
                    {
                        //is pre-patch!!
                        return false;
                    }
                }
            }
        }
    }
#endif

    return true;
}
