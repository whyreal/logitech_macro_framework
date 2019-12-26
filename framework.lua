Macros = macros or {}

Polling = {
    FAMILY   = "mouse",
    -- 轮训周期, 25 毫秒为 1.5 帧, 比较合理
    INTERVAL = 50
}
-- 轮询初始化
function Polling:init()
    self.M_State = GetMKeyState(self.FAMILY)
    SetMKeyState(self.M_State, self.FAMILY)
end

-- 轮询
function Polling:poll(event, _, family)
    if family == self.FAMILY then
        if (event == "M_RELEASED") then
            Sleep(self.INTERVAL)
            SetMKeyState(self.M_State, self.FAMILY)
        end
    end
end

Action = { }
function Action:new(data, context)
    data = data or {}
    local o = {
        release_time = 0,
        -- 持续时间
        duration = data.duration or 0,
        duration_end = 0,
        -- 周期
        interval = data.interval or 0,
        key = data.key or nil,
        key_status = "up",
        modifier = data.modifier or nil,
        -- 一次性
        once = data.once or false,
        -- 类型 ["skill", "delay", "macro"]
        type = data.type or nil,
        value = data.value or nil,
        context = context,
    }

    setmetatable(o, self)
    self.__index = self
    return o
end

function Action:press_key()
    if self.modifier ~= nil then PressKey(self.modifier) end

    if self.key == "right"  then
        PressMouseButton(3)
    elseif self.key == "left" then
        PressMouseButton(1)
    else
        PressKey(self.key)
    end
    self.key_status = "down"
end

function Action:release_key()
    if self.key == "right"  then
        ReleaseMouseButton(3)
    elseif self.key == "left" then
        ReleaseMouseButton(1)
    else
        ReleaseKey(self.key)
    end
    self.key_status = "up"

    if self.modifier ~= nil then ReleaseKey(self.modifier) end
end

-- 根据 action 设置, 触发键盘或鼠标动作
function Action:release_skill()
    if self.key_status == "up" then 
        self:press_key()
        if self.duration > 0 then
            self.duration_end = self.context.running_time + self.duration
        end
    end

    if self.duration > 0 then
        if self.context.type == "loop" and self:finished() then
            self:release_key()
        end
        if self.context.type == "sequence" then
            self.context:delay(self.duration)
            self:release_key()
        end
    else
        self:release_key()
    end
end

function Action:finished()
    if self.context.running_time >= self.duration_end then
        return true
    else
        return false
    end
end

function Action:run()
    if (self.once and not self.context.is_first_time) then
        return nil
    end

    if self.type == "skill" then
        if self.interval == nil then
            self:release_skill()
        elseif self.context.running_time >= self.release_time then
            self:release_skill()
            self.release_time = self.release_time + self.interval
        end
    elseif self.type == "macro" then
        if self.interval == nil then
            Toggle(self.value)
        elseif self.context.running_time >= self.release_time then
            Toggle(self.value)
            self.release_time = self.release_time + self.interval
        end
        self.context.subtrigger[self.value] = true
    elseif self.type == "delay" then
        self.context:delay(self.duration)
    end
end

Macro = {
    enabled = false
}

function Macro:active()
    if self.type == "loop" then
        self.co = coroutine.create(self.excute_loop)
    elseif self.type == "sequence" then
        self.co = coroutine.create(self.excute_sequence)
    end
    local status, value = coroutine.resume(self.co, self)
    if not status then
        OutputLogMessage(value)
    end
end

function Macro:deactive()
    for _, action in ipairs(self) do
        if action.key ~= nil then
            action:release_key()
        end
    end

    if coroutine.status(self.co) ~= "dead" then
        local status, value = coroutine.resume(self.co, "EXIT")
        if not status then
            OutputLogMessage(value)
        end
    end
end

function Macro:excute_loop()
    if self.before ~= nil then
        for _,action in ipairs(self.before) do
            action:run()
        end
    end

    while true do
        if self:timeout() then
            break
        else
            for _, action in ipairs(self.actions) do
                action:run()
            end
        end

        self.is_first_time = false

        self:will_exit()
        if self.exit then return nil end
    end

    if self.after ~= nil then
        for _,action in ipairs(self.after) do
            action:run()
        end
    end
end

function Macro:timeout()
    if not self.duration then
        return false
    end

    if self.running_time > self.duration then
        -- 超时
        return true
    else
        return false
    end
end

function Macro:excute_sequence()
    repeat
        for _, action in ipairs(self) do
            action:run()
            -- action 执行过程中可能会被终止
            -- 每一个 action 执行完, 都需要检查退出信号
            self:will_exit()
            if self.exit then return nil end
        end

        self.is_first_time = false
    until not self.loop
end

function Macro:will_exit()
    if self.exit then return nil end
    if coroutine.yield() == "EXIT" then
        self.exit = true
    end
end

function Macro:delay(duration)
    local resume_time = GetRunningTime() + duration
    while true do
        if GetRunningTime() >= resume_time then break end
        self:will_exit()
        if self.exit then return nil end
    end
end

function Macro:updateTime()
    self.running_time = GetRunningTime() - self.start_time
end

function Macro:run()
    self:updateTime()

    if coroutine.status(self.co) == "dead" then
        Toggle(self.trigger)
    elseif coroutine.status(self.co) == "suspended" then
        local status, value = coroutine.resume(self.co)
        if not status then
            OutputLogMessage(value)
        end
    end
end

function Macro:new(data)
    data = data or {}
    local o = {
        actions = {},
        before = {},
        after = {},
        type = data.type,
        duration = data.duration or nil,
        loop = data.loop or false,
        trigger = data.trigger,
        start_time = GetRunningTime(),
        running_time = 0,
        co = nil,
        is_first_time = true,
        exit = false,
    }

    if type(o.trigger) == "string" then
        --[[
        命名 action 中
        - loop 必须设置持续时间(duration)并且小于 60 秒,
        - sequence 的 loop 属性不能为 true.
        ]]
        if o.type == "loop"
            and (o.duration == nil or o.duration > 60000) then
            o.duration = 60000
        end

        if o.type == "sequence" then
            o.loop = false
        end
    end

    for idx,a in ipairs(data.before or {}) do
        table.insert(o.before, Action:new(a, o))
    end
    for idx,a in ipairs(data.after or {}) do
        table.insert(o.after, Action:new(a, o))
    end
    for idx,a in ipairs(data) do
        table.insert(o.actions, Action:new(a, o))
    end

    setmetatable(o, self)
    self.__index = self
    return o
end


ActivedMacros = {}
function ActivedMacros:run()
    for _, macro in ipairs(self) do
        macro:run()
    end
end

-- 切换宏的状态
function Toggle(trigger)
    -- stop macro
    local stop_macro = false
    for i, macro in ipairs(ActivedMacros) do
        if type(macro.trigger) == "number" then
            macro:deactive()
        end

        if macro.trigger == trigger then
            stop_macro = true
            if type(macro.trigger) == "string" then
                macro:deactive()
                ActivedMacros[i] = nil
            end
        end
    end

    if type(macro.trigger) == "number" then
        ActivedMacros = {}
    end

    if stop_macro then return nil end

    -- start macro
    for _, macro in ipairs(Macros) do
        if macro.trigger == trigger then
            local m = Macro:new(macro)
            m:active()
            table.insert(ActivedMacros, m)
        end
    end
end

-- 处理系统消息
function OnEvent(event, arg, family)
    -- Profile 激活事件
    if event == "PROFILE_ACTIVATED" then
        --  初始化
        ClearLog()
        Polling:init()
        OutputLogMessage("Script started !\n")
    end

    --  Profile 终止事件
    -- if event == "PROFILE_DEACTIVATED" then
    -- end

    -- 鼠标点击事件
    if(event == "MOUSE_BUTTON_PRESSED") then
        -- 事件处理期间, 暂停 macros 轮询
        Toggle(arg)
    end

    ActivedMacros:run()
    Polling:poll(event, arg, family)
end
--OutputLogMessage("event = %s, arg = %s\n", event, arg);
