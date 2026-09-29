namespace Effects
{
    bool IsEffectApplied(CGamePlayground@ playground, CTrackManiaGameTerminal@ playerControl, EffectType effectType)
    {
        auto controlledPlayer = cast<CTrackManiaPlayer>(playerControl.ControlledPlayer);
        switch(effectType)
        {
            case EffectType::LowGravity:
                return controlledPlayer.ScriptAPI.GravityCoef == 0.5;
            case EffectType::ForceBrake:
                return playerControl.ScriptedInputs_Brake;
            case EffectType::ForceAccelerate:
                return playerControl.ScriptedInputs_Accelerate;
            case EffectType::Blind:
                return playground.GameTerminals_IsBlackOut;
            default:
                warn("This effect has no duration: " + tostring(effectType));
                return false;
        }
    }

    void OnEffectReceived(CGamePlayground@ playground, CTrackManiaGameTerminal@ playerControl, EffectType effectType)
    {
        switch(effectType)
        {
            case EffectType::LowGravity:
                SetTimedEffectTimer(effectType, 30000);
                ArmEffect(playground, playerControl, effectType);
                break;
            case EffectType::ForceRestart:
                playerControl.ScriptedInputs_RequestGiveUp = true;
                break;
            case EffectType::ForceRespawn:
                playerControl.ScriptedInputs_RequestRespawn = true;
                break;
            case EffectType::ForceHorn:
                playerControl.ScriptedInputs_RequestHorn = true;
                break;
            case EffectType::ForceBrake:
                SetTimedEffectTimer(effectType, 2000);
                ArmEffect(playground, playerControl, effectType);
                break;
            case EffectType::ForceAccelerate:
                SetTimedEffectTimer(effectType, 10000);
                ArmEffect(playground, playerControl, effectType);
                break;
            case EffectType::Blind:
                SetTimedEffectTimer(effectType, 2000);
                ArmEffect(playground, playerControl, effectType);
                break;
            default:
                // should only happen if _Count is used
                warn("Unknown effect: " + tostring(effectType));
        }
        Log::Log("Effect " + tostring(effectType) + " has been handled for player " + playerControl.ControlledPlayer.User.Login);
    }

    void ArmEffect(CGamePlayground@ playground, CTrackManiaGameTerminal@ playerControl, EffectType effectType)
    {
        if(!IsEffectApplied(playground, playerControl, effectType))
        {
            switch(effectType)
            {
                case EffectType::LowGravity:
                    SendEffectEvent({tostring(effectType), "on"});
                    break;
                case EffectType::ForceBrake:
                    playerControl.ScriptedInputs_Brake = true;
                    break;
                case EffectType::ForceAccelerate:
                    playerControl.ScriptedInputs_Accelerate = true;
                    break;
                case EffectType::Blind:
                    playground.GameTerminals_IsBlackOut = true;
                    break;
                default:
                    warn("This effect should not be armed: " + tostring(effectType));
            }
            // Log::Log("Armed " + tostring(effectType) + " effect to player " + playerControl.ControlledPlayer.User.Login);
        }
    }
    void UnarmEffect(CGamePlayground@ playground, CTrackManiaGameTerminal@ playerControl, EffectType effectType)
    {
        switch(effectType)
        {
            case EffectType::LowGravity:
                SendEffectEvent({tostring(effectType), "off"});
                break;
            case EffectType::ForceBrake:
                playerControl.ScriptedInputs_Brake = false;
                break;
            case EffectType::ForceAccelerate:
                playerControl.ScriptedInputs_Accelerate = false;
                break;
            case EffectType::Blind:
                playground.GameTerminals_IsBlackOut = false;
                break;
            default:
                warn("This effect should not be unarmed: " + tostring(effectType));
        }
        // Log::Log("Unarmed " + tostring(effectType) + " effect to player " + playerControl.ControlledPlayer.User.Login);
    }
}