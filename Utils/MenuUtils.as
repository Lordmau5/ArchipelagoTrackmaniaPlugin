string[] BaseTitlePacks = { "TMValley", "TMCanyon", "TMStadium", "TMLagoon" };

bool IsCurrentTitlepackCompatible(const string &in titlePack)
{
    const string loadedTitlePack = CurrentTitlePack();

    if (loadedTitlePack == "")
    {
        return false;
    }

    if (loadedTitlePack == "TMPlus_Canyon" && titlePack == "TMCanyon")
    {
        return true;
    }

    if (loadedTitlePack == "TMPlus_Lagoon" && titlePack == "TMLagoon")
    {
        return true;
    }

    if (
        (loadedTitlePack == 'TMAll' || loadedTitlePack == 'TMPlus' || loadedTitlePack == 'Nadeo_Envimix')
        && BaseTitlePacks.Find(loadedTitlePack) > -1
    )
    {
        return true;
    }

    if (loadedTitlePack.StartsWith('TMAll') && titlePack.StartsWith('TMAll'))
    {
        // Covers TMAll with TMAllMaker
        return true;
    }

    if (loadedTitlePack == "Platform" && titlePack == "TMCanyon")
    {
        // it can only open maps with mapType Platform but that's okay
        return true;
    }

    return loadedTitlePack == titlePack;
}

#if MP4
dictionary environmentMap = {
    {"Canyon",  "TMCanyon"},
    {"Stadium", "TMStadium"},
    {"Valley",  "TMValley"},
    {"Lagoon",  "TMLagoon"},
    {"Desert",  "TMOneSpeed"},
    {"Snow",    "TMOneAlpine"},
    {"Bay",     "TMOneBay"},
    {"Island",  "TM2U_Island"},
    {"Mix",     "TMAll"}
};

array<string> NormalizeTitlePackNames(const array<string>& in titlePacks)
{
    array<string> normalizedTitlePacks;

    for (uint i = 0; i < titlePacks.Length; i++)
    {
        string pack = titlePacks[i];
        if (environmentMap.Exists(pack))
        {
            normalizedTitlePacks.InsertLast(string(environmentMap[pack]));
        }
    }

    return normalizedTitlePacks;
}

string GetEnvironmentFromTitlePack(const string& in titlePack)
{
    array<string>@ keys = environmentMap.GetKeys();
    for (uint i = 0; i < keys.Length; i++)
    {
        string key = keys[i];
        string value;

        if (environmentMap.Get(key, value))
        {
            if (value == titlePack)
            {
                return key;
            }
        }
    }

    return titlePack;
}
#endif

array<string> GetInstalledTitlePacks(const array<string>& in targetPacks)
{
    array<string> installedPacks;
    CTrackMania@ app = cast<CTrackMania>(GetApp());

    if (app is null) return installedPacks;

    for (uint targetPackIndex = 0; targetPackIndex < targetPacks.Length; targetPackIndex++)
    {
        string packName = targetPacks[targetPackIndex];

        for (uint maniaTitleIndex = 0; maniaTitleIndex < app.ManiaTitles.Length; maniaTitleIndex++)
        {
            auto title = app.ManiaTitles[maniaTitleIndex];
            if (title is null) continue;

            // Handles both plain IDs ("TMCanyon") and full IDs ("TMCanyon@nadeo")
            if (title.TitleId == packName || title.TitleId.StartsWith(packName + "@"))
            {
                installedPacks.InsertLast(packName);
                break;
            }
        }
    }

    return installedPacks;
}

CGameManiaTitle@ MatchTitlePack(const string& in packName)
{
    CTrackMania@ app = cast<CTrackMania>(GetApp());
    if (app is null) return null;

    for (uint maniaTitleIndex = 0; maniaTitleIndex < app.ManiaTitles.Length; maniaTitleIndex++)
    {
        auto title = app.ManiaTitles[maniaTitleIndex];
        if (title is null) continue;

        // Handles both plain IDs ("TMCanyon") and full IDs ("TMCanyon@nadeo")
        if (title.TitleId.StartsWith(packName + "@"))
        {
            return title;
        }
    }

    return null;
}

void BackToStationsMenu()
{
    CTrackMania@ app = cast<CTrackMania>(GetApp());

    while (app.ManiaTitles.Length == 0)
    {
        yield();
    }

    ClosePauseMenu();

    yield();

    BackToMainMenu();

    // Extra yield  when requesting exit out of a titlepack / Map Selection
    while (!app.ManiaTitleControlScriptAPI.IsReady)
    {
        yield();
    }

    string url = "maniaplanet://#menustations=";
    app.ManiaPlanetScriptAPI.OpenLink(url, CGameManiaPlanetScriptAPI::ELinkType::ManialinkBrowser);
}

bool LoadTitlePack(const string &in titlepack)
{
    CTrackMania@ app = cast<CTrackMania>(GetApp());

    while (app.ManiaTitles.Length == 0)
    {
        yield();
    }

    if (IsCurrentTitlepackCompatible(titlepack))
    {
        return true;
    }

    auto title = MatchTitlePack(titlepack);
    if (title is null)
    {
        Log::Error('Title pack "' + titlepack + '" not found.\nMake sure you have it installed!');
        return false;
    }

    string url = "maniaplanet://#menustations=play@" + title.TitleId;
    app.ManiaPlanetScriptAPI.OpenLink(url, CGameManiaPlanetScriptAPI::ELinkType::ManialinkBrowser);

    yield();
    sleep(100);

    UI::ShowNotification("Loading title pack...", GetEnvironmentFromTitlePack(titlepack));
    app.ManiaPlanetScriptAPI.EnterTitle(title.TitleId);

    yield();
    sleep(100);

    while(app.LoadedManiaTitle is null || !app.ManiaTitleControlScriptAPI.IsReady)
    {
        yield();
    }

    return true;
}
