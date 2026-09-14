string[] BaseTitlePacks = { "TMValley", "TMCanyon", "TMStadium", "TMLagoon" };

bool IsCurrentTitlepackCompatible(const string &in titlePack) {
    const string loadedTitlePack = CurrentTitlePack();

    if (loadedTitlePack == "") {
        return false;
    }

    if (loadedTitlePack == "TMPlus_Canyon" && titlePack == "TMCanyon") {
        return true;
    }

    if (loadedTitlePack == "TMPlus_Lagoon" && titlePack == "TMLagoon") {
        return true;
    }

    if ((loadedTitlePack == 'TMAll' || loadedTitlePack == 'TMPlus' || loadedTitlePack == 'Nadeo_Envimix') && BaseTitlePacks.Find(loadedTitlePack) > -1) {
        return true;
    }

    if (loadedTitlePack.StartsWith('TMAll') && titlePack.StartsWith('TMAll')) {
        // Covers TMAll with TMAllMaker
        return true;
    }

    if (loadedTitlePack == "Platform" && titlePack == "TMCanyon") {
        // it can only open maps with mapType Platform but that's okay
        return true;
    }

    return loadedTitlePack == titlePack;
}

array<string> GetInstalledTitlePacks(const array<string>& in targetPacks) {
    array<string> installedPacks;
    CTrackMania@ app = cast<CTrackMania>(GetApp());
    if (app is null) return installedPacks;

    for (uint i = 0; i < targetPacks.Length; i++) {
        string packName = targetPacks[i];

        for (uint j = 0; j < app.ManiaTitles.Length; j++) {
            auto title = app.ManiaTitles[j];
            if (title is null) continue;

            // Handles both plain IDs ("TMCanyon") and full IDs ("TMCanyon@nadeo")
            if (title.TitleId == packName || title.TitleId.StartsWith(packName + "@")) {
                installedPacks.InsertLast(title.TitleId);
                break;
            }
        }
    }

    return installedPacks;
}

CGameManiaTitle@ MatchTitlePack(const string& in packName) {
    CTrackMania@ app = cast<CTrackMania>(GetApp());
    if (app is null) return null;

    for (uint i = 0; i < app.ManiaTitles.Length; i++) {
        auto title = app.ManiaTitles[i];
        if (title is null) continue;

        // Handles both plain IDs ("TMCanyon") and full IDs ("TMCanyon@nadeo")
        if (title.TitleId.StartsWith(packName + "@")) {
            return title;
        }
    }

    return null;
}

void BackToStationsMenu() {
    CTrackMania@ app = cast<CTrackMania>(GetApp());

    while (app.ManiaTitles.Length == 0) {
        yield();
    }

    // Extra yield when requesting exit out of a titlepack / Map Selection
    yield();

    string url = "maniaplanet://#menustations=";
    app.ManiaPlanetScriptAPI.OpenLink(url, CGameManiaPlanetScriptAPI::ELinkType::ManialinkBrowser);
}

bool LoadTitlePack(const string &in titlepack) {
    CTrackMania@ app = cast<CTrackMania>(GetApp());

    while (app.ManiaTitles.Length == 0) {
        yield();
    }

    if (IsCurrentTitlepackCompatible(titlepack)) {
        return true;
    }

    auto title = MatchTitlePack(titlepack);
    if (title is null)
    {
        Log::Error('Failed to load title pack "' + titlepack + '"\nMake sure you have it installed!');
        return false;
    }

    string url = "maniaplanet://#menustations=play@" + title.TitleId;
    app.ManiaPlanetScriptAPI.OpenLink(url, CGameManiaPlanetScriptAPI::ELinkType::ManialinkBrowser);
    sleep(1000);

    UI::ShowNotification("Loading title pack...", title.TitleId);
    app.ManiaPlanetScriptAPI.EnterTitle(title.TitleId);
    sleep(1000);

    while(app.LoadedManiaTitle is null || !app.ManiaTitleControlScriptAPI.IsReady) {
        yield();
    }

    return true;
}
