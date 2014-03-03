PLUGIN.Title = "Decay Control"
PLUGIN.Author = "Gliktch"
PLUGIN.Version = "0.1"
PLUGIN.Description = "(Experimental) Attempts to turn decay off, or extend the time it takes for structures to decay."

function PLUGIN:Init()
  print("Loading Decay Control mod...")
  self:AddChatCommand( "decay", self.cmdDecay )
  -- if (self.Config.decayoff) then
  touchtimer = timer.Repeat( 60, function() rust.RunServerCommand("structure.touchall") print("testing...") end )
  -- end
  decayset = timer.Once( 60, function() rust.RunServerCommand("decay.deploy_maxhealth_sec 4838400") end )
end

function PLUGIN:cmdDecay( netuser, args )
  Rust.SendChatToUser(netuser, "Sorry, configuration is coming in the next version!")
  Rust.SendChatToUser(netuser, "Decay Control Syntax: You may use /decay [number] [hour[s]|day[s]|week[s]]")
  Rust.SendChatToUser(netuser, "or /decay [on|off], or simply /decay by itself to show current settings.")
end
