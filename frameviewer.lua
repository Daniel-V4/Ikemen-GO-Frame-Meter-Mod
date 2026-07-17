local FrameMeter = require("external.mods.frameviewer.framemeter")
FrameMeter.init()

local dumped = false
hook.add("loop", "SF6FrameMeterDraw", function()

    -- Only show in training mode
    if gamemode('training') then
        FrameMeter.update()
        FrameMeter.draw()
    end
end)
