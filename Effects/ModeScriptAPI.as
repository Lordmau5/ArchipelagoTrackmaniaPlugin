namespace Effects
{
    bool SendEffectEvent(array<string> data)
    {
        auto app = cast<CGameManiaPlanet>(GetApp());
        auto network = app.Network;
        auto maniaApp = cast<CGameManiaAppPlayground>(network.ClientManiaAppPlayground);
        if (maniaApp is null) {
            error("ManiaApp was null whilst trying to send event");
            return false;
        }

        MwFastBuffer<wstring> eventData;
        for (uint i = 0; i < data.Length; i++) {
            eventData.Add(data[i]);
        }
        maniaApp.SendCustomEvent("AP.Effect", eventData);
        return true;
    }
}

