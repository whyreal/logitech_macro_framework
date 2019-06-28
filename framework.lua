if not macros then
    macros = {}
end

polling = {
    FAMILY   = "mouse",
    -- 轮训周期, 25 毫秒为 1.5 帧, 比较合理
    INTERVAL = 25
}
-- 轮询初始化
function polling:init()
    self.M_State = GetMKeyState(self.FAMILY)
    SetMKeyState(self.M_State, self.FAMILY)
end

-- 轮询
function polling:poll(event, arg, family)
    if family == self.FAMILY then
        if (event == "M_RELEASED") then
            Sleep(self.INTERVAL)
            SetMKeyState(self.M_State, self.FAMILY)
        end
    end
end

button = {
}

-- 根据 action 设置, 触发键盘或鼠标动作
function button:release_skill(action)

    if action.modifier ~= nil then
        PressKey(action.modifier)
    end

    if action.key == "left" then
        PressMouseButton(1)
        if action.duration ~= nil then Sleep(action.duration) end
        ReleaseMouseButton(1)
    elseif action.key == "right" then
        PressMouseButton(3)
        if action.duration ~= nil then Sleep(action.duration) end
        ReleaseMouseButton(3)
    else
        PressKey(action.key)
        if action.duration ~= nil then Sleep(action.duration) end
        ReleaseKey(action.key)
    end

    if action.modifier ~= nil then
        ReleaseKey(action.modifier)
    end
end

function macros:active_loop(loop)
    if loop == nil then return end

    loop.start_time = GetRunningTime()

    if loop.before ~= nil then
        self:excute_sequence(loop.before, false)
    end

    for _, action in ipairs(loop) do
        if action.interval ~= nil then
            action.release_time = 0 
        end
    end
end

function macros:deactive_loop(loop)
    if loop == nil then return end

    if loop.after ~= nil then
        self:excute_sequence(loop.after, false)
    end
end

-- 迭代 macros 中激活的宏, 进行相应处理
function macros:iterate()
    if not DO_ITERATE then return nil end
            
    local function _run_macro(macro)
        if not macro.enabled then
            return nil
        end

        local is_running = false

        if macro.loop ~= nil then
            local loop = macro.loop
            local loop_running_time = GetRunningTime() - loop.start_time

            if loop.duration == nil or loop_running_time < loop.duration then
                is_running = true
                for _, action in ipairs(loop) do
                    if action.interval == nil then
                        button:release_skill(action)
                    elseif loop_running_time >= action.release_time then
                        button:release_skill(action)
                        action.release_time = action.release_time + action.interval
                    end
                end
            end
        end

        if macro.sequence ~= nil and macro.sequence.co ~= nil then
            local sequence = macro.sequence

            if coroutine.status(sequence.co) == "dead" then
                self:deactive_sequence(sequence)
            elseif coroutine.status(sequence.co) == "suspended" then
                is_running = true
                coroutine.resume(sequence.co)
            end
        end

        macro.enabled = is_running
    end

    for _, macro in ipairs(self) do
        _run_macro(macro)
    end
end

function macros:excute_sequence(sequence, async)

    local function _run_action(action, is_first_time)
        if (action.once and not is_first_time) then
            return nil
        end

        if action.type == "delay" then
            if async then
                sequence.resume_time = sequence.resume_time + action.duration
                while true do
                    if GetRunningTime() >= sequence.resume_time then break end
                    if coroutine.yield() == "EXIT" then return nil end
                end
            else
                Sleep(action.duration)
            end

        elseif action.type == "macro" then
            self:toggle(action.value)

        elseif action.type == "skill" then
            button:release_skill(action)
        end
    end

    local is_first_time = true

    repeat
        sequence.resume_time = GetRunningTime()

        for _, action in ipairs(sequence) do
            _run_action(action, is_first_time)
        end
            
        is_first_time = false

        if async then
            -- 每次循环后, 保留一个退出窗口
            if coroutine.yield() == "EXIT" then return nil end
        end
    until not sequence.loop
end

function macros:active_sequence(sequence)
    if sequence == nil then return end

    sequence.co = coroutine.create(self.excute_sequence)
    -- coroutine 初始化
    coroutine.resume(sequence.co, self, sequence, true)
end

function macros:deactive_sequence(sequence)
    if sequence == nil or sequence.co == nil then return end

    if coroutine.status(sequence.co) ~= "dead" then
        coroutine.resume(sequence.co, "EXIT")
    end
    sequence.co = nil
end

-- 切换宏的状态
-- 数字宏具有排他性
function macros:toggle(trigger)

    local function _toggle(macro, trigger)

        if trigger ~= macro.trigger then
            if (type(trigger) == "number" and type(macro.trigger) == "number" and macro.enabled) then
                -- 匿名(数字)宏由鼠标按键触发, 具有排他性, 同一时间只能激活一个
                -- 当激活一个数字宏, 其他的数字宏将被自动关闭
                macro.enabled = false
            else
                return nil
            end
        else
            macro.enabled = not macro.enabled
        end

        if macro.enabled then
            self:active_loop(macro.loop)
            self:active_sequence(macro.sequence)
        else
            self:deactive_loop(macro.loop)
            self:deactive_sequence(macro.sequence)
        end
    end

    for _, macro in ipairs(self) do
        _toggle(macro, trigger)
    end
end

--[[
命名 action 中
loop 必须设置持续时间(duration)并且小于 60 秒,
sequence 的 loop 属性不能为 true.
]]
function macros:init()
    local function _init(macro)
        macro.enabled = false
        if type(macro.trigger) == "number" then
            return nil
        end

        if macro.loop ~= nil
                and (macro.loop.duration == nil
                    or macro.loop.duration > 60000) then
            macro.loop.duration = 0
        end
        if macro.sequence ~= nil then
            macro.sequence.loop = false
        end
    end

    for _, macro in ipairs(self) do
        _init(macro)
    end
end

-- 处理系统消息
function OnEvent(event, arg, family)
    -- Profile 激活事件
    if event == "PROFILE_ACTIVATED" then
        --  初始化
        ClearLog()
        OutputLogMessage("Script started !\n")
        polling:init()
        macros:init()
    end

    --  Profile 终止事件
    if event == "PROFILE_DEACTIVATED" then
    end
    
    -- 鼠标点击事件
    if(event == "MOUSE_BUTTON_PRESSED") then
        -- 事件处理期间, 暂停 macros 轮询
        DO_ITERATE = false
        macros:toggle(arg)
        DO_ITERATE = true
    end

    macros:iterate()
    polling:poll(event, arg, family)
end
