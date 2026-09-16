void RenderMainMenu() {
    UI::PushStyleVar(UI::StyleVar::WindowTitleAlign, vec2(.5, .5));
    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(12, 12));
    UI::PushStyleVar(UI::StyleVar::WindowRounding, 16.0);
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 8.0);
    int flags = UI::WindowFlags::NoCollapse | UI::WindowFlags::NoDocking | UI::WindowFlags::AlwaysAutoResize;
    if (UI::Begin("Archipelago - Menu", isOpen, flags)) {
        float scale = UI::GetScale() / 1.5;

        if (data is null) {
            UI::Text("Awaiting Server Connection...");
        }
        else {
            vec2 viewSize = vec2(600, 700) * scale;
            float manMarn = 4 * scale;
            bool seriesInitializing = false;
            UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(4, 8));
            UI::BeginChild("Serieses", viewSize);
            if (!shownBefore) {
                shownBefore = true;
                UI::SetScrollHereY();
            }
            for (uint i = 0; i < data.world.Length; i++) {
                UI::PushFont(fontHeader);
                
                UI::Text (Text::Format("Series %d", i + 1));
                UI::PopFont();
                VPadding(int(manMarn));
                UI::Separator();
                VPadding(int(manMarn));

                if (data.world[i].IsUnlocked() && data.world[i].initialized) {
                    for (int j = 0; j < data.world[i].mapCount; j++){
                        MapState@ map = data.world[i].maps[j];

                        UI::PushStyleVar(UI::StyleVar::ChildRounding, 5);
                        UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(5));

                        if (map.skipped) {
                            UI::PushStyleColor(UI::Col::ChildBg, vec4(0, 0.12, 0.96, 0.15));
                        }
                        else if (data.locations.GotAllChecks(map.seriesIndex, map.mapIndex)) {
                            UI::PushStyleColor(UI::Col::ChildBg, vec4(0, 0.96, 0.12, 0.15));
                        }
                        else if (map.mapIndex % 2 == 1) {
                            UI::PushStyleColor(UI::Col::ChildBg, vec4(1, 1, 1, 0.04));
                        }

                        UI::BeginChild("Map" + i + "_" + j, vec2(0), UI::ChildFlags::AutoResizeY | UI::ChildFlags::AlwaysUseWindowPadding);

                        // Series Number
                        UI::PushFont(fontTime);
                        UI::Text(Text::Format("%02d", j + 1));
                        UI::PopFont();

                        // Map Name
                        UI::SameLine();

                        UI::BeginChild("MapNameAndAuthor" + i + "_" + j, vec2(0), UI::ChildFlags::AutoResizeY, UI::WindowFlags::NoBackground);

                        UI::PushFont(fontHeaderSub);
                        UI::PushFontSize(Math::Max(16, Math::Min(16 * scale, 20)));

                        string mapName = map.mapInfo.Name;
                        if (mapName.Length > 35){
                            mapName = mapName.SubStr(0,32)+"...";
                        }
                        UI::Text(mapName);
                        UI::PopFontSize();
                        UI::PopFont();

                        UI::SameLine();
                        DrawChecksRemaining(map.seriesIndex, map.mapIndex, false);

                        // Author and Titlepack
                        MoveCursor(vec2(0, -20));
                        UI::PushStyleColor(UI::Col::Text, vec4(0.7, 0.7, 0.7, 1.0));
                        UI::PushFontSize(Math::Max(12, Math::Min(12 * scale, 16)));

                        string authorAndTitlepack = "by " + map.mapInfo.Username;
#if MP4
                        authorAndTitlepack = authorAndTitlepack + " / "
                            + GetEnvironmentFromTitlePack(map.mapInfo.TitlePack);
#endif

                        UI::Text(authorAndTitlepack);
                        UI::PopFontSize();
                        UI::PopStyleColor();

                        UI::EndChild();

                        if (UI::IsItemHovered()) {
                            RenderTooltip(data.world[i].maps[j]);
                        }

                        if(UI::IsItemClicked(UI::MouseButton::Left)) {
                            LoadMapByIndex(i,j);
                        }

                        if(UI::IsItemClicked(UI::MouseButton::Right)) {
                            RerollMapFromUI(i, j);
                        }

                        UI::EndChild();

                        if (map.mapIndex % 2 == 1 || map.skipped || data.locations.GotAllChecks(map.seriesIndex, map.mapIndex)) {
                            UI::PopStyleColor();
                        }

                        UI::PopStyleVar(2);
                    }
                }
                else if (!data.world[i].IsUnlocked()) {
                    UI::NewLine();
                    UI::NewLine();
                    float center = viewSize.x / 2;
                    MoveCursor(vec2(center, 0));
                    UI::PushStyleColor(UI::Col::Text, vec4(0.52, 0.5, 0.5, 1.0));
                    RenderTextCentered(Icons::Lock, fontHeader, 0);
                    UI::PopStyleColor();
                    MoveCursor(vec2(-center, 0));
                    UI::NewLine();
                }
                else {
                    if (data.world[i].initializing || seriesInitializing) {
                        seriesInitializing = true;
                        UI::Text("Rolling Maps...");
                        UI::NewLine();
                    }
                    else{
                        UI::Text("Maps could not been rolled.");
                        if (UI::ButtonColored("Force Load Maps", 0)) {
                            startnew(CoroutineFunc(data.world[i].Initialize));
                        }
                    }
                    UI::NewLine();
                    UI::NewLine();
                    UI::NewLine();
                }
                MoveCursor(vec2(0, manMarn));
                UI::Separator();
                MoveCursor(vec2(0, manMarn));

                uint nextSeries = i+1;
                int count = data.items.GetProgressionMedalCount();
                int total = (nextSeries < data.world.Length) ? data.world[nextSeries].medalRequirement : data.victoryRequirement;
                int size = 60;
                float medalOffset = (viewSize.x / 2)
                    -((size + UI::MeasureString("" + count + "/" + total, fontHeaderSub).x) / 2
                    + 16 * UI::GetScale()
                );
                RenderSeriesLine(nextSeries,viewSize, 40, 4, 8);
                MoveCursor(vec2(medalOffset, -15.0));
                RenderMedalProgress(GetProgressionTex(), size, count, total);
                MoveCursor(vec2(-medalOffset, -15.0));
                RenderSeriesLine(nextSeries, viewSize, 40, 4, 8);
                MoveCursor(vec2(0, manMarn));
                MoveCursor(vec2(0, -32));
                if (nextSeries >= data.world.Length) {
                    MoveCursor(vec2(0, 10));
                    string text = "Victory";
                    if (count >= total) text = "Victory!!!!! :D";
                    UI::PushFont(fontHeader);
                    vec4 color = vec4(0.5, 0.5, 0.5, 1.0);
                    if (count >= total) {
                        color = (vec4(0.0, 1.0, 0.1, 1.0));
                    }
                    UI::PushStyleColor(UI::Col::Text, color);
                    vec2 stringSize = UI::MeasureString(text, fontHeader);
                    float textOffset = (viewSize.x / 2) - (stringSize.x / 2);
                    MoveCursor(vec2(textOffset, 0));
                    UI::Text(text);
                    MoveCursor(vec2(-textOffset, 0));
                    UI::PopStyleColor();
                    UI::PopFont();
                    UI::NewLine();
                }
            }
            UI::EndChild();
            UI::PopStyleVar(1);
            UI::Separator();

            if (UI::ButtonColored(Icons::Times+" Disconnect", 0.0)) {
                socket.Close();
            }
        }
    }
    UI::End();
    UI::PopStyleVar(4);
}

void RenderTooltip(MapState@ map) {
    UI::BeginTooltip();
    
    UI::Text("Tags:");
    UI:: SameLine();
    DrawTags(map, false);

    UI::Text("Target Time:");
    UI::SameLine();
    UI::Text(Time::Format(map.targetTime));
    
    UI::EndTooltip();
}

void RenderSeriesLine(uint seriesI, vec2 viewSize, float height, float width, float margin) {
    vec2 cursorPos = UI::GetCursorPos();
    cursorPos.x = 0;
    UI::SetCursorPos(cursorPos);
    MoveCursor(vec2(0, margin));
    vec2 startPos = UI::GetCursorPos() + UI::GetWindowPos() - vec2(0, UI::GetScrollY()) + vec2(viewSize.x / 2, 0);
    MoveCursor(vec2(0, height));
    vec2 endPos = UI::GetCursorPos() + UI::GetWindowPos() - vec2(0, UI::GetScrollY()) + vec2(viewSize.x / 2, 0);
    vec4 rect = vec4(startPos.x - (width/2),startPos.y,width,endPos.y - startPos.y);
    MoveCursor(vec2(0, margin));

    int total = (seriesI < data.world.Length) ? data.world[seriesI].medalRequirement : data.victoryRequirement;
    int count = data.items.GetProgressionMedalCount();
    vec4 color = vec4(0.35, 0.35, 0.35, 1.0);
    if (count >= total){
        color = vec4(0, 0.96, 0.12, 0.7);
    }
    UI::GetWindowDrawList().AddRectFilled(rect, color, width / 2);
}