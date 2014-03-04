PLUGIN.Title         = "Decay Control"
PLUGIN.Author        = "Gliktch"
PLUGIN.Description   = "Turns decay of buildings on or off, with the option to leave decay on but customise the time it takes for structures to decay."
PLUGIN.Version       = "0.8"
PLUGIN.ConfigVersion = "0.5"
PLUGIN.ResourceID    = "334"

function PLUGIN:Init()

    print("Loading Decay Control mod...")

    self:LoadConfig()

    if self.Config.CheckForUpdates then
        self:UpdateCheck()
    end

    self:AddChatCommand( "decay", self.cmdDecay )

    if (self.Config.DecayOff) then
        self:DisableDecay()
    else
        self:EnableDecay( true )
    end
end

function PLUGIN:PostInit()
    self:LoadFlags()
end

function PLUGIN:LoadFlags()
    self.oxminPlugin = plugins.Find("oxmin")
    if (self.oxminPlugin) then
        self.FLAG_DECAY = oxmin.AddFlag("decay")
        self.oxminPlugin:AddExternalOxminChatCommand(self, "decay", { self.FLAG_DECAY }, self.cmdDecay)
    end
    self.flagsPlugin = plugins.Find("flags")
    if (self.flagsPlugin) then
        self.flagsPlugin:AddFlagsChatCommand(self, "decay", { "decay" }, self.cmdDecay)
    end
end

function PLUGIN:HasFlag(netuser, flag)
    if (netuser:CanAdmin()) then
        do return true end
    elseif ((self.oxminPlugin ~= nil) and (self.oxminPlugin:HasFlag(netuser, flag))) then
        do return true end
    elseif ((self.flagsPlugin ~= nil) and (self.flagsPlugin:HasFlag(netuser, flag))) then
        do return true end
    end
    return false
end

function PLUGIN:LoadConfig()
    local b, res = config.Read("decay")
    self.Config = res or {}
    if (not b) then
        print("Decay Control: Creating default config...")
        self:LoadDefaultConfig()
        if (res) then config.Save("decay") end
    end
    if ( self.Config.ConfigVersion < self.ConfigVersion ) then
        print("Decay Control's configuration file needs to be updated - backing up and replacing with default values.")
        ConfigUpdateAlertTimer = timer.Repeat( 60, 3, function() rust.BroadcastChat("Decay Control: Changes in a recent update led to default values being loaded.  Decay is now OFF.") end )
        config.Save( "decay_backupconfig" )
        self:LoadDefaultConfig()
        config.Save( "decay" )
    end
end

function PLUGIN:LoadDefaultConfig()
    self.Config.ConfigVersion = "0.5"
    self.Config.CheckForUpdates = true
    self.Config.DecayOff = true
    self.Config.DecayTime = 4838400
    self.Config.PublicDecayStatus = true
    self.Config.CheckTickRate = true
end

function PLUGIN:UpdateCheck()
    if (self.ResourceID) then
        self.url = "http://wulf.im/oxide/" .. self.ResourceID
        local request = webrequest.Send(url, function(code, response)
            if (code == 200) then
                if (self.Version < response) then
                    updatemsg = "Alert: \"" .. self.Title .. "\" (filename " .. self.Filename .. ".lua) has an update available, from v" .. self.Version .. " to v" .. response .. "."
                    error(updatemsg)
                    error("Visit http://forum.rustoxide.com/resources/" .. self.ResourceID .. "/ to download the latest version!")
                    DecayControlUpdateAlertTimer = timer.Repeat( 60, 3, function() rust.BroadcastChat(updatemsg) end )
                    else
                end
            else
                updatefailed = true
            end
        end)
        if ((not request) or (updatefailed)) then
            errmsg = "Alert: Update Check Failed for \"" .. tostring(self.Title) .. "\" (filename " .. tostring(self.Filename) .. ".lua) v" .. tostring(self.Version) .. "."
            DecayControlUpdateFailTimer = timer.Repeat( 60, 3, function() rust.BroadcastChat( errmsg ) end )
            error(errmsg)
        end
    end
end


function PLUGIN:cmdDecay( netuser, args )
    if (self:HasFlag(netuser,"decay")) then
        if ((not args) or (args[1] == "?") or (args[1] == "help")) then
            self:PrintSyntax( netuser )
        elseif (string.lower(args[1]) == "on") then
            self:EnableDecay()
        elseif (string.lower(args[1]) == "off") then
            self:DisableDecay()
        elseif (type(tonumber(args[1])) == "number") then
            if     (strsub(string.lower(args[2]), 1, 4) == "hour") then
                self.Config.DecayTime = round( (args[1] *   3600), 0 )
            elseif (strsub(string.lower(args[2]), 1, 3) == "day") then
                self.Config.DecayTime = round( (args[1] *  86400), 0 )
            elseif (strsub(string.lower(args[2]), 1, 4) == "week") then
                self.Config.DecayTime = round( (args[1] * 604800), 0)
            -- Assume 'days' if the unit of DecayTime is not provided
            elseif (not args[2]) then
                rust.SendChatToUser("Decay Control: Assuming you meant " .. tonumber(args[1]) .. " days.")
                self.Config.DecayTime = round( (args[1] *  86400), 0 )
            else
                self:PrintSyntax( netuser )
                self:PrintDecayStatus( netuser )
                return
            end
            self:EnableDecay()
        end
        self:PrintDecayStatus( netuser )
    else
        if (self.Config.PublicDecayStatus) then
            self:PrintDecayStatus( netuser )
        else
            rust.SendChatToUser("Decay Control: You do not have access to this command.")
        end
    end
end

function PLUGIN:DisableDecay()
    self:CheckTickRate()
    if (not DecayTouchTimer) then
        DecayTouchTimer = timer.Repeat( 60, function() rust.RunServerCommand("structure.touchall") end )
    end
    self.Config.DecayOff = true
    config.Save("decay")
end

function PLUGIN:EnableDecay( frominit )
    self:CheckTickRate()
    if (DecayTouchTimer) then
        DecayTouchTimer:Destroy()
--      if (DecayReinstateAlertTimer) then
--          DecayReinstateAlertTimer:Destroy()
--      end
--      DecayReinstateAlertTimer = timer.Repeat( 60, 3, function() rust.BroadcastChat("Decay Control: Decay has been re-enabled. Decay time is now set to " .. self:CalculateDecayTime(self.Config.DecayTime)) end )
    end
    self.Config.DecayOff = false
    config.Save("decay")
    if (frominit) then
        DecayRateSetTimer = timer.Once( 60, function() rust.RunServerCommand("decay.deploy_maxhealth_sec " .. math.floor(tonumber(self.Config.DecayTime))) end )
    else
    rust.RunServerCommand("decay.deploy_maxhealth_sec " .. math.floor(tonumber(self.Config.DecayTime)))
    end
end

function round(num, dec)
  local pow = 10^(dec or 0)
  return math.floor(num * pow + 0.5) / pow
end

function PLUGIN:CalculateDecayTime( secs )
    if (secs < 86400) then
        result = round((secs / 3600), 2) .. " hour(s)"
    elseif (secs < 604800) then
        result = round((secs / 86400), 2) .. " day(s)"
    else
        result = round((secs / 604800), 2) .. " week(s)"
    end
    return result
end

function PLUGIN:CheckTickRate()
    if ((self.Config.CheckTickRate) and ((not Rust.decay.decaytickrate) or (Rust.decay.decaytickrate < 100))) then
        error("Decay Control: DecayTickRate setting too low or not found - resetting to default (300).")
        rust.BroadcastChat("Decay Control: DecayTickRate setting too low or not found - resetting to default (300).")
        rust.RunServerCommand("decay.decaytickrate 300")
    end
end

function PLUGIN:PrintDecayStatus( netuser )
    rust.SendChatToUser(netuser, "Decay is currently " .. (toboolean(self.Config.DecayOff)) and "OFF.  Decay Control is continuously keeping buildings from decaying. :)" or "ON, Decay Time is " .. self:CalculateDecayTime(self.Config.DecayTime) .. ".")
end

function PLUGIN:PrintSyntax( netuser )
    rust.SendChatToUser( netuser, "Decay Control Syntax: You may use /decay [number] [hour[s]|day[s]|week[s]]")
    rust.SendChatToUser( netuser, "or /decay [on|off], or simply /decay by itself to show current settings.")
end
