function init_list_metatable(o_list, proto)
    if o_list == nil then return nil end

    for _, o in ipairs(o_list) do
        setmetatable(o, {__index = proto})
    end
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

base_action = {
}
-- 根据 action 设置, 触发键盘或鼠标动作
function base_action:release_skill()
    if self.modifier ~= nil then
        PressKey(self.modifier)
    end

    if self.key == "left" then
        PressMouseButton(1)
        if self.duration ~= nil then self.context:delay(self.duration) end
        ReleaseMouseButton(1)
    elseif self.key == "right" then
        PressMouseButton(3)
        if self.duration ~= nil then self.context:delay(self.duration) end
        ReleaseMouseButton(3)
    else
        PressKey(self.key)
        if self.duration ~= nil then self.context:delay(self.duration) end
        ReleaseKey(self.key)
    end

    if self.modifier ~= nil then
        ReleaseKey(self.modifier)
    end
end

function base_action:run_by_interval()
    if self.type == "skill" then
        if self.interval == nil then
            self:release_skill()
        elseif self.context.running_time >= self.release_time then
            self:release_skill()
            self.release_time = self.release_time + self.interval
        end
    elseif self.type == "macro" then
        if self.interval == nil then
            macros:toggle(self.value)
        elseif self.context.running_time >= self.release_time then
            macros:toggle(self.value)
            self.release_time = self.release_time + self.interval
        end
        self.context.subtrigger[self.value] = true
    end
end

function base_action:run()
    if (self.once and not self.context.is_first_time) then
        return nil
    end

    if self.type == "delay" then
        self.context:delay(self.duration)

    elseif self.type == "macro" then
        macros:toggle(self.value)
        self.context.subtrigger[self.value] = true

    elseif self.type == "skill" then
        self:release_skill()
    end
end

base_macro = {
    enabled = false
}

function base_macro:delay(duration)
    local resume_time = GetRunningTime() + duration
    while true do
        if GetRunningTime() >= resume_time then break end
        self:will_exit()
        if self.exit then return nil end
    end
end

function base_macro:active()
    self.start_time = GetRunningTime()
    self.running_time = 0
    self.subtrigger = {}
    self.is_first_time = true

    -- 协程中, 无法直接终止执行,  exit 用来标识协程是否退出
    -- 将 macro 作为上下文, 通过函数参数传递
    self.exit = false
    -- init skill
    for _, action in ipairs(self) do
        if action.interval ~= nil then
            action.release_time = 0 
        end
    end

    if self.type == "loop" then
        self.co = coroutine.create(self.excute_loop)
        status, value = coroutine.resume(self.co, self)
        if not status then
            OutputLogMessage(value)
        end
    elseif self.type == "sequence" then
        self.co = coroutine.create(self.excute_sequence)
        status, value = coroutine.resume(self.co, self)
        if not status then
            OutputLogMessage(value)
        end
    end
end

function base_macro:deactive()
    self.enabled = false

    if self.co == nil then return end

    for t, _ in pairs(self.subtrigger) do
        macros:toggle(t, false)
    end

    if coroutine.status(self.co) ~= "dead" then
        status, value = coroutine.resume(self.co, "EXIT")
        if not status then
            OutputLogMessage(value)
        end
    end
    self.co = nil
end

function base_macro:need_processing()
    self.running_time = GetRunningTime() - self.start_time

    if not self.duration then
        return true
    end

    if self.running_time > self.duration then
        -- 超时
        return false
    else
        return true
    end
end

function base_macro:excute_loop()
    if self.before ~= nil then
        for _,action in ipairs(self.before) do
            action:run()
        end
    end

    while true do
        if self:need_processing() then
            for _, action in ipairs(self) do
                action:run_by_interval()
            end
        else
            break
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

function base_macro:will_exit() 
    if coroutine.yield() == "EXIT" then
        self.exit = true
    end
end

function base_macro:excute_sequence()
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

function base_macro:toggle(trigger, status)
    if trigger ~= self.trigger then
        if (type(trigger) == "number" and type(self.trigger) == "number" and self.enabled) then
            -- 匿名(数字)宏由鼠标按键触发, 具有排他性, 同一时间只能激活一个
            -- 当激活一个数字宏, 其他的数字宏将被自动关闭
            self.enabled = false
        else
            return nil
        end
    else
        if status == nil then
            self.enabled = not self.enabled
        else
            self.enabled = status
        end
    end

    if self.enabled then
        self:active()
    else
        self:deactive()
    end
end

function base_macro:run()
    if not self.enabled then
        return nil
    end

    if self.co == nil then
        return nil
    end

    if coroutine.status(self.co) == "dead" then
        self:deactive()
    elseif coroutine.status(self.co) == "suspended" then
        status, value = coroutine.resume(self.co)
        if not status then
            OutputLogMessage(value)
        end
    end
end

function base_macro:check_string_macro()
    --[[
    命名 action 中
    - loop 必须设置持续时间(duration)并且小于 60 秒,
    - sequence 的 loop 属性不能为 true.
    ]]
    if self.type == "loop"
            and (self.duration == nil
            or self.duration > 60000) then
        self.duration = 0
    end
    if self.type == "sequence" then
        self.loop = false
    end
end

function base_macro:init()
    -- init metatable and context
    for _, s in ipairs({self, self.before, self.after}) do
        if s ~= nil then
            init_list_metatable(s, base_action)
            for _, action in ipairs(s) do
                action.context = self
            end
        end
    end

    if type(self.trigger) == "string" then
        self:check_string_macro()
    end
end

if not macros then
    macros = {}
end

-- 设置对象原型
function macros:init()
    for _, macro in ipairs(self) do
        setmetatable(macro, {__index = base_macro})
        macro:init()
    end
end

-- 切换宏的状态
-- 数字宏具有排他性
function macros:toggle(trigger, status)
    for _, macro in ipairs(self) do
        macro:toggle(trigger, status)
    end
end
 
-- 迭代 macros 中激活的宏, 进行相应处理
function macros:run()
    if not DO_ITERATE then return nil end

    for _, macro in ipairs(self) do
        macro:run()
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

    macros:run()
    polling:poll(event, arg, family)
end
