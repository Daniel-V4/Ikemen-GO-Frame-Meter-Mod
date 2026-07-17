local FrameMeter = require("external.mods.frameviewer.framemeter")
FrameMeter.init()

local dumped = false
hook.add("loop", "SF6FrameMeterDraw", function()
    if not dumped then
        dumped = true
        local f = io.open("dir_test.txt", "w")
        if f then
            local files = getDirectoryFiles("chars")
            if type(files) == "table" then
                for i, v in ipairs(files) do
                    f:write(tostring(v) .. "\n")
                end
            else
                f:write(type(files) .. "\n")
            end
            f:close()
        end
    end
    -- Only show in training mode
    if gamemode('training') then
        FrameMeter.update()
        FrameMeter.draw()
    end
end)
