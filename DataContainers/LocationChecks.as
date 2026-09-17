class LocationChecks
{
    array<array<uint>> checkFlags;

    SaveData@ saveData;

    LocationChecks(SaveData@ saveData, uint seriesCount)
    {
        @this.saveData = saveData;
        checkFlags = array<array<uint>>(seriesCount, array<uint>(MAX_MAPS_IN_SERIES));
    }

    LocationChecks(SaveData@ saveData, const Json::Value &in json)
    {
        @this.saveData = saveData;

        if (json !is null)
        {
            checkFlags = array<array<uint>>(json.Length,array<uint>(MAX_MAPS_IN_SERIES));

            for (uint seriesIndex = 0; seriesIndex < json.Length; seriesIndex++)
            {
                for (uint mapIndex = 0; mapIndex < json[seriesIndex].Length; mapIndex++)
                {
                    checkFlags[seriesIndex][mapIndex] = uint(json[seriesIndex][mapIndex]);
                }
            }
        }
    }

    bool GotCheck(int seriesIndex, int mapIndex, CheckTypes check)
    {
        return checkFlags[seriesIndex][mapIndex] & uint(TypeToFlag(check)) > 0;
    }

    void FlagCheck(int seriesIndex, int mapIndex, CheckTypes check)
    {
        checkFlags[seriesIndex][mapIndex] |= uint(TypeToFlag(check));
    }

    void FlagAllChecksOfType(CheckTypes check)
    {
        for (uint seriesIndex = 0; seriesIndex < checkFlags.Length; seriesIndex++)
        {
                for (uint mapIndex = 0; mapIndex < checkFlags[seriesIndex].Length; mapIndex++)
                {
                    checkFlags[seriesIndex][mapIndex] |= uint(TypeToFlag(check));
                }
            }
    }

    bool GotAllChecks(int seriesIndex, int mapIndex)
    {
        uint mask = 0;

        if (saveData.settings.DoingBronze())
        {
            mask |= uint(CheckFlags::Bronze);
        }

        if (saveData.settings.DoingSilver())
        {
            mask |= uint(CheckFlags::Silver);
        }

        if (saveData.settings.DoingGold())
        {
            mask |= uint(CheckFlags::Gold);
        }

        if (saveData.settings.DoingAuthor())
        {
            mask |= uint(CheckFlags::Author);
        }

        mask |= uint(CheckFlags::Target);
        uint masked = checkFlags[seriesIndex][mapIndex] & mask;

        return masked == mask;
    }

    CheckTypes GetNthCheck(int seriesIndex, int mapIndex, int n)
    {
        int checkCount = 0;

        for(uint i = 0; i < checkFlags.Length; i++)
        {
            if (GotCheck(seriesIndex, mapIndex, CheckTypes(i)))
            {
                if (n == checkCount) return CheckTypes(i);

                checkCount++;
            }
        }

        return CheckTypes::Bronze;
    }

    int ChecksRemaining(int seriesIndex, int mapIndex)
    {
        int remaining = 0;
        int checks = checkFlags[seriesIndex][mapIndex];

        if (saveData.settings.DoingBronze() && checks & CheckFlags::Bronze == 0)
        {
            remaining += 1;
        }

        if (saveData.settings.DoingSilver() && checks & CheckFlags::Silver == 0)
        {
            remaining += 1;
        }

        if (saveData.settings.DoingGold() && checks & CheckFlags::Gold == 0)
        {
            remaining += 1;
        }

        if (saveData.settings.DoingAuthor() && checks & CheckFlags::Author == 0)
        {
            remaining += 1;
        }

        if (checks & CheckFlags::Target == 0)
        {
            remaining += 1;
        }

        return remaining;
    }

    int ChecksGotten(int seriesIndex, int mapIndex)
    {
        int checkCount = 0;

        for(uint i = 0; i < checkFlags.Length; i++)
        {
            if (GotCheck(seriesIndex, mapIndex, CheckTypes(i)))
            {
                checkCount++;
            }
        }

        return checkCount;
    }

    int AddLocationChecks(array<int> &checks,int currentTotal, int seriesIndex, int mapIndex)
    {
        int index = 0;

        for(uint i = 0; i < checkFlags.Length; i++)
        {
            if (GotCheck(seriesIndex, mapIndex, CheckTypes(i)))
            {
                checks[currentTotal + index] = MapIndicesToId(seriesIndex, mapIndex, CheckTypes(i));
                index++;
            }
        }

        return index;
    }

    private CheckFlags TypeToFlag(CheckTypes type)
    {
        switch (type)
        {
            case CheckTypes::Bronze:
                return CheckFlags::Bronze;

            case CheckTypes::Silver:
                return CheckFlags::Silver;

            case CheckTypes::Gold:
                return CheckFlags::Gold;

            case CheckTypes::Author:
                return CheckFlags::Author;

            case CheckTypes::Target:
                return CheckFlags::Target;

            default:
                return CheckFlags::None;
        }
    }

    Json::Value ToJson()
    {
        Json::Value json = Json::Array();

        try
        {
            for (uint seriesIndex = 0; seriesIndex < checkFlags.Length; seriesIndex++)
            {
                Json::Value jsonRow = Json::Array();

                for (uint mapIndex = 0; mapIndex < checkFlags[seriesIndex].Length; mapIndex++)
                {
                    jsonRow.Add(checkFlags[seriesIndex][mapIndex]);
                }

                json.Add(jsonRow);
            }
        }
        catch
        {
            Log::Error("Error converting Location Checks to JSON");
        }

        return json;
    }
}