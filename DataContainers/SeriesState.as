class SeriesState
{
    int                 medalTotal; //number of medals this series contributes to the final total 
    int                 mapCount; // maps in the series
    SearchCriteria@     searchBuilder; // handles making a MX search URL
    array<MapState@>    maps;
    bool                initialized;
    bool                initializing;

    SaveData@ saveData;

    //derived data
    int seriesIndex;
    int medalRequirement; // progression medals required to unlock

    SeriesState(
        SaveData@ saveData,
        const Json::Value &in json,
        int seriesIndex,
        int requirement,
        bool isSlot = false
    )
    {
        @this.saveData = saveData;

        this.seriesIndex        = seriesIndex;
        this.medalRequirement   = requirement;

        try
        {
            if (isSlot)
            {
                ReadSlotData(json);
            }
            else
            {
                ReadJsonV1_2(json);
            }
        }
        catch
        {
            Log::Error("Error parsing SeriesState for Series " + seriesIndex + "\nReason: " + getExceptionInfo());
        }
    }

    void Initialize()
    {
        if (initialized || initializing) return;

        initializing    = true;
        bool loadError  = false;

        for(int mapIndex = 0; mapIndex < mapCount; mapIndex++)
        {
            if (maps[mapIndex] !is null) continue;

            MapInfo@ mapRoll = QueryForRandomMap(searchBuilder);

            if (mapRoll is null)
            {
                Log::Error("Unable to roll Series " + seriesIndex + ", Map " + mapIndex);
                loadError = true;
                break;
            }

            @maps[mapIndex] = MapState(saveData, mapRoll, seriesIndex, mapIndex);
        }

        initialized     = !loadError;
        initializing    = false;

        if (!loadError)
        {
            SendScouts();
            saveFile.Save(saveData);
        }
    }

    bool IsUnlocked()
    {
        return medalRequirement <= data.items.GetProgressionMedalCount();
    }

    void SendScouts()
    {
        array<int> ids  = array<int>(MAX_MAP_LOCATIONS * mapCount);
        int index       = 0;

        bool doBronze = saveData.settings.DoingBronze();
        bool doSilver = saveData.settings.DoingSilver();
        bool doGold   = saveData.settings.DoingGold();
        bool doAuthor = saveData.settings.DoingAuthor();

        for (int mapIndex = 0; mapIndex < mapCount; mapIndex++)
        {
            if (doBronze)
            {
                ids[index++] = MapIndicesToId(seriesIndex, mapIndex, CheckTypes::Bronze);
            }

            if (doSilver)
            {
                ids[index++] = MapIndicesToId(seriesIndex, mapIndex, CheckTypes::Silver);
            }

            if (doGold)
            {
                ids[index++] = MapIndicesToId(seriesIndex, mapIndex, CheckTypes::Gold);
            }

            if (doAuthor)
            {
                ids[index++] = MapIndicesToId(seriesIndex, mapIndex, CheckTypes::Author);
            }

            // Target is always included regardless of settings
            ids[index++] = MapIndicesToId(seriesIndex, mapIndex, CheckTypes::Target);
        }

        SendLocationScouts(ids, index);
    }

    void ReadSlotData(const Json::Value@ &in json)
    {
        @this.searchBuilder = SearchCriteria(seriesIndex, json["SearchCriteria"], true);

        this.medalTotal = json["MedalTotal"];
        this.mapCount   = json["MapCount"];
        this.maps       = array<MapState@>(this.mapCount);

        initialized     = false;
        initializing    = false;
    }

    void ReadJsonV1_2(const Json::Value@ &in json)
    {
        @this.searchBuilder = SearchCriteria(seriesIndex, json["searchBuilder"]);

        this.medalTotal = json["medalTotal"];
        this.mapCount   = json["mapCount"];
        this.maps       = array<MapState@>(this.mapCount);

        const Json::Value@ mapObjects = json["maps"];
        for (uint mapIndex = 0; mapIndex < mapObjects.Length; mapIndex++)
        {
            @maps[mapIndex] = MapState(saveData, mapObjects[mapIndex], seriesIndex, mapIndex);
        }

        initialized     = int(mapObjects.Length) == mapCount;
        initializing    = false;
    }

    void ReadThumbnails(const Json::Value@ &in json)
    {
        for(int i = 0; i < seriesIndex + 1; i++)
        {
            yield(); // cant load all thumbnails on the same frame or we die
        }

        const Json::Value@ mapObjects = json["maps"];
        for (uint mapIndex = 0; mapIndex < mapObjects.Length; mapIndex++)
        {
            maps[mapIndex].LoadThumbnail(mapObjects[mapIndex]);
        }
    }

    Json::Value ToJson()
    {
        Json::Value json = Json::Object();

        try
        {
            json["searchBuilder"]   = searchBuilder.ToJson();
            json["medalTotal"]      = medalTotal;
            json["mapCount"]        = mapCount;

            Json::Value@ mapArray = Json::Array();
            for (uint mapIndex = 0; mapIndex < maps.Length; mapIndex++)
            {
                if (maps[mapIndex] !is null)
                {
                    mapArray.Add(maps[mapIndex].ToJson());
                }
            }

            json["maps"] = mapArray;
        }
        catch
        {
            Log::Error("Error converting SeriesState to JSON for Series " + seriesIndex);
        }

        return json;
    }
}

class SeriesStateThumbnailPacket
{
    SeriesState@        seriesState;
    const Json::Value@  seriesJson;

    SeriesStateThumbnailPacket(SeriesState@ seriesState, const Json::Value@ seriesJson)
    {
        @this.seriesState   = seriesState;
        @this.seriesJson    = seriesJson;
    }
}