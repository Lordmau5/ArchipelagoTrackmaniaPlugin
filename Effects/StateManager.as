namespace Effects
{
    enum EffectType
    {
        LowGravity,
        ForceRestart,
        ForceRespawn,
        ForceHorn,
        ForceBrake,
        ForceAccelerate,
        Blind,
        _Count // keep last, this will convert to the number of effect types in the enum
    }

    class TimedEffect
    {
        EffectType  type;
        int         msLeft;

        TimedEffect
        (
            EffectType type,
            int msLeft = 0
        )
        {
            this.type = type;
            this.msLeft = msLeft;
        }
    }
    

    const array<TimedEffect@> AP_TIMED_EFFECTS = {
        TimedEffect(EffectType::LowGravity),
        TimedEffect(EffectType::ForceBrake),
        TimedEffect(EffectType::ForceAccelerate),
        TimedEffect(EffectType::Blind)
    };
    uint lastGameTime = 0;
    CTrackManiaPlayer::ERaceState lastRaceState;

    void SetTimedEffectTimer(EffectType effectType, uint msLeft)
    {
        for (uint i=0; i < AP_TIMED_EFFECTS.Length; i++)
        {
            auto effect = AP_TIMED_EFFECTS[i];
            if (effect.type == effectType)
            {
                effect.msLeft = msLeft;
            }
        }
    }

    // should only be run while GetIsOnMap() = true
    void TimedEffectsLoop()
    {
        auto app = cast<CGameManiaPlanet>(GetApp());
        auto playground = app.CurrentPlayground;
        if (playground is null) return;

        uint gameTime = app.Network.PlaygroundClientScriptAPI.GameTime;
        uint delta = gameTime - lastGameTime;
        lastGameTime = gameTime;

        for (uint i=0; i < playground.GameTerminals.Length; i++)
        {
            CTrackManiaGameTerminal@ playerControl = cast<CTrackManiaGameTerminal>(playground.GameTerminals[i]);
            if (playerControl is null) return;
            CTrackManiaPlayer@ player = cast<CTrackManiaPlayer>(playerControl.ControlledPlayer);
            if (player.RaceState == CTrackManiaPlayer::ERaceState::Running)
            {
                for (uint j=0; j < AP_TIMED_EFFECTS.Length; j++)
                {
                    auto effect = AP_TIMED_EFFECTS[j];
                    if (effect.msLeft > 0)
                    {
                        if (!IsEffectApplied(playground, playerControl, effect.type))
                        {
                            ArmEffect(playground, playerControl, effect.type);
                        }
                        else
                        {
                            effect.msLeft -= delta;
                        }
                    }
                    else
                    {
                        if (IsEffectApplied(playground, playerControl, effect.type))
                        {
                            UnarmEffect(playground, playerControl, effect.type);
                            effect.msLeft = 0;
                        }
                    }
                }
            }
            else if (player.RaceState == CTrackManiaPlayer::ERaceState::Finished && lastRaceState == CTrackManiaPlayer::ERaceState::Running)
            {
                for (uint j=0; j < AP_TIMED_EFFECTS.Length; j++)
                {
                    auto effect = AP_TIMED_EFFECTS[j];
                    if (effect.msLeft > 0)
                    {
                        if (IsEffectApplied(playground, playerControl, effect.type))
                        {
                            effect.msLeft = 0;
                            UnarmEffect(playground, playerControl, effect.type);
                        }
                    }
                }
            }
            else if (player.RaceState == CTrackManiaPlayer::ERaceState::BeforeStart)
            {
                for (uint j=0; j < AP_TIMED_EFFECTS.Length; j++)
                {
                    auto effect = AP_TIMED_EFFECTS[j];
                    if (effect.msLeft > 0)
                    {
                        if (!IsEffectApplied(playground, playerControl, effect.type))
                        {
                            ArmEffect(playground, playerControl, effect.type);
                            playerControl.ScriptedInputs_RequestGiveUp = true;
                        }
                    }
                }
            }
            lastRaceState = player.RaceState;
        }
    }

    void Handle(EffectType effectType, string[] args)
    {
        Log::Log("Received " + tostring(effectType) + " effect");
        auto app = cast<CGameManiaPlanet>(GetApp());
        auto playground = app.CurrentPlayground;
        if (playground is null || playground.GameTerminals.Length == 0)
        {
            // TODO: add queue system when effect is played while not in a map for relevant effects
            Log::Log("Effect " + tostring(effectType) + " received while not ingame. Skipping.", true);
            return;
        }

        for (uint i=0; i < playground.GameTerminals.Length; i++)
        {
            CTrackManiaGameTerminal@ playerControl = cast<CTrackManiaGameTerminal>(playground.GameTerminals[i]);
            OnEffectReceived(playground, playerControl, effectType);
        }
    }
}