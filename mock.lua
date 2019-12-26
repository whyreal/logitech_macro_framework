function PressMouseButton(button)
    pressed_key[button] = {"down"}
end
function ReleaseMouseButton(button)
    table.insert(pressed_key[button], 1, "up")
end

function PressKey(button)
    pressed_key[button] = {"down"}
end

function ReleaseKey(button)
    table.insert(pressed_key[button], 1, "up")
end

function GetRunningTime()
    return os.clock()
end
