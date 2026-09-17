void ProcessMessage(const string &in message)
{
    if (IS_DEV_MODE)
    {
        print("Recieved Message: " + message);
    }

    Json::Value@ cmdJson;
    string cmd = "";

    try
    {
        Json::Value@ json = Json::Parse(message);

        if (json.GetType() == Json::Type::Array)
        {
            @cmdJson = json[0];
        }
        else
        {
            @cmdJson = json;
        }

        cmd = cmdJson["cmd"];
    }
    catch
    {
        //if we get a mesage with invalid json, its probably a disconnect request from the server
        if (message.Length == 2)
        {
            print("Message not valid JSON. Disconnecting...");
            socket.Close();
        }
        else
        {
            print("Message not valid JSON. Dropping...");
        }

        print (""+message.Length);
        return;
    }

    // Angelscript does not support switch-cases with strings. Great language.
    if (cmd == "RoomInfo")
    {
        ProcessRoomInfo(cmdJson);
        SendConnectionPacket();
    }
    else if (cmd == "Connected")
    {
        ProcessConnected(cmdJson);
    }
    else if (cmd == "Resync")
    {
        ProcessResync();
    }
    else if (cmd == "PrintJSON")
    {
        ProcessPrintJson(cmdJson);
    }
    else if (cmd == "ConnectionRefused")
    {
        ProcessConnectionRefused(cmdJson);
    }
    else if (cmd == "ReceivedItems")
    {
        ProcessReceivedItems(cmdJson);
    }
    else if (cmd == "LocationInfo")
    {
        ProcessLocationInfo(cmdJson);
    }
    else if (cmd == "Bounced")
    {
        ProcessBounced(cmdJson);
    }
    else if (cmd == "Retrieved")
    {
        ProcessRetrieved(cmdJson);
    }
    else if (cmd == "RoomUpdate")
    {
        ProcessRoomUpdate(cmdJson);
    }
    else if (cmd == "Reroll")
    {
        ProcessReroll(cmdJson);
    }
}

string seedNameCache = "";
void ProcessRoomInfo(Json::Value@ json)
{
    seedNameCache = json["seed_name"];
}

void ProcessConnected(Json::Value@ json)
{
    int teamIndex       = json["team"];
    int playerIndex     = json["slot"];
    string playerName   = "";

    auto players = json["players"];

    for(uint i = 0; i < players.Length; i++)
    {
        if (players[i]["team"] == teamIndex && players[i]["slot"] == playerIndex)
        {
            playerName = players[i]["alias"];
            break;
        }
    }

    @saveFile = SaveFile(seedNameCache, teamIndex, playerIndex);

    if (saveFile.Exists())
    {
        Json::Value@ saveJson = saveFile.Load();

        @data = SaveData(seedNameCache, teamIndex, playerIndex, playerName, saveJson);

        if (data.settings.seriesCount == 0)
        {
            //I accidently ruined some save files in 1.3, this recovers them
            data.Recover1_3Error(json["slot_data"]);
        }

        //resend all map checks we have, just in case some got missed!
        ProcessResync();
    }
    else
    {
        @data = SaveData(seedNameCache, teamIndex, playerIndex, playerName, json["slot_data"], true);

        startnew(CoroutineFunc(data.world[0].Initialize));
    }

    seedNameCache = "";
    if (!socket.NotDisconnected()) return;

    CheckLocations(json);
    SendStatusUpdate(ClientStatus::CLIENT_PLAYING);
}

void ProcessResync()
{
    if (data is null) return;

    Log::Log("Resyncing all Checks", false);

    array<int> allChecks = array<int>(MAX_SERIES_COUNT * MAX_MAPS_IN_SERIES * MAX_MAP_LOCATIONS);

    int total = 0;

    for (uint seriesIndex = 0; seriesIndex < data.world.Length; seriesIndex++)
    {
        for (uint mapIndex = 0; mapIndex < data.world[seriesIndex].maps.Length; mapIndex++)
        {
            total += data.locations.AddLocationChecks(allChecks, total, seriesIndex, mapIndex);
        }
    }

    SendLocationChecks(allChecks, total);
}

void ProcessPrintJson(Json::Value@ json)
{
    //¯\_(ツ)_/¯
    Json::Value@ jsonData = json["data"];
    if (jsonData !is null && jsonData.GetType() == Json::Type::Array)
    {
        for (uint i = 0; i < jsonData.Length; i++)
        {
            string rawText      = json["data"][i]["text"];
            string displayText  = StripArchipelagoColorCodes(rawText);

            if (!Setting_ShowToasts) return;

            if (Setting_ShowOnlyRelevantToasts)
            {
                if (!displayText.Contains(data.playerName) || displayText.Contains(data.playerName + ":")) return;
            }

            Log::ArchipelagoNotification(displayText);
        }
    }
}

void ProcessConnectionRefused(Json::Value@ json)
{
    seedNameCache = "";
    Log::Error("Server Refused Connection, closing...", true);
    socket.Close();
}

void ProcessReceivedItems(Json::Value@ json)
{
    if (data is null) return;

    int serverIndex     = json["index"];
    Json::Value@ items  = json["items"];

    if (serverIndex == 0 && data.items.itemsRecieved > 0)
    {
        // resync!!
        data.items.Reset();
    }

    if (serverIndex > data.items.itemsRecieved)
    {
        SendSync();
    }

    for (uint i = 0; i < items.Length; i++)
    {
        data.items.AddItem(items[i]["item"]);
    }

    //check if we won
    if (!data.hasGoal && data.items.GetProgressionMedalCount() >= data.victoryRequirement)
    {
        data.hasGoal = true;

        SendStatusUpdate(ClientStatus::CLIENT_GOAL);

        saveFile.Save(data); // removes thumbnails from save file
        startnew(Celebrate);
    }

    // check if we need to preload a new series
    data.InitializeUpcomingSeries();
}

void ProcessLocationInfo(Json::Value@ json)
{
    auto locations = json["locations"];

    if (locations is null) return;

    for (uint i = 0; i < locations.Length; i++)
    {
        Json::Value@ netItem = locations[i];

        ItemTypes itemType = ItemTypes::Archipelago;

        // not totally sure this works
        if (netItem["player"] == data.playerTeamIndex)
        {
            int itemId = int(netItem["item"]);

            itemType = ItemTypes(int(netItem["item"]));

            if (itemId >= BASE_TRAP_ID && itemId != int(ItemTypes::Archipelago))
            {
                itemType = ItemTypes::Filler;

                if (itemId < int(ItemTypes::Filler))
                {
                    itemType = ItemTypes::Trap;
                }
            }
        }

        // TODO: Convert this to a locationClass or whatever so we don't need indices.x,y,z?
        vec3 location = MapIdToIndices(netItem["location"]);

        int seriesIndex         = int(location.x);
        int mapIndex            = int(location.y);
        CheckTypes checkType    = CheckTypes(int(location.z));

        data.world[seriesIndex].maps[mapIndex].SetItemType(itemType, checkType);
    }
}

void ProcessBounced(Json::Value@ json)
{
    // if we ever add deathlink it will be added here
}

void ProcessRetrieved(Json::Value@ json)
{
    // a response to a get command, which we arent using so this should never happen! ^-^
}

void ProcessRoomUpdate(Json::Value@ json)
{
    CheckLocations(json);
}

void ProcessReroll(Json::Value@ json)
{
    RerollMapInfo@ rerollMapInfo;

    if (
        json["series_index"] !is null
        && json["map_index"] !is null
        && int(json["series_index"]) >= 1
        && int(json["map_index"]) >= 1
    )
    {
        rerollMapInfo = GetRerollMapInfo(int(json["series_index"]) - 1, int(json["map_index"]) - 1);
    }
    else if (loadedMap !is null && loadedMap.mapInfo.MapUid == GetLoadedMapUid())
    {
        rerollMapInfo = GetRerollMapInfo(loadedMap.seriesIndex, loadedMap.mapIndex);
    }

    RerollMap(rerollMapInfo);
}

void CheckLocations(Json::Value@ json)
{
    Json::Value@ locations = json["checked_locations"];

    if (locations !is null && locations.GetType() == Json::Type::Array)
    {
        for (uint i = 0; i < locations.Length; i++)
        {
            // TODO: Convert this to a locationClass or whatever so we don't need indices.x,y,z?
            vec3 location    = MapIdToIndices(locations[i]);

            int seriesIndex         = int(location.x);
            int mapIndex            = int(location.y);
            CheckTypes checkType    = CheckTypes(int(location.z));

            data.locations.FlagCheck(seriesIndex, mapIndex, checkType);
        }
    }
}