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

function delay(co_context, duration)
    local resume_time = GetRunningTime() + duration
    while true do
        if GetRunningTime() >= resume_time then break end
        if coroutine.yield() == "EXIT" then
            co_context.exit = true
            break
        end
    end
end

base_action = {
}

-- 根据 action 设置, 触发键盘或鼠标动作
function base_action:release_skill(co_context)
    if self.modifier ~= nil then
        PressKey(self.modifier)
    end

    if self.key == "left" then
        PressMouseButton(1)
        if self.duration ~= nil then delay(co_context, self.duration) end
        ReleaseMouseButton(1)
    elseif self.key == "right" then
        PressMouseButton(3)
        if self.duration ~= nil then delay(co_context, self.duration) end
        ReleaseMouseButton(3)
    else
        PressKey(self.key)
        if self.duration ~= nil then delay(co_context, self.duration) end
        ReleaseKey(self.key)
    end

    if self.modifier ~= nil then
        ReleaseKey(self.modifier)
    end
end

base_macro = {}

function base_macro:active()
    self.subtrigger = {}
    self.exit = false


    if self.type == "loop" then
        self.co = coroutine.create(self.excute_loop)
        coroutine.resume(self.co, self)
    elseif self.type == "sequence" then
        self.co = coroutine.create(self.excute_sequence)
        coroutine.resume(self.co, self)
    end
end

function base_macro:deactive()
    self.enabled = false

    if self.co == nil then return end

    for t, _ in pairs(self.subtrigger) do
        macros:toggle(t, false)
    end

    if coroutine.status(self.co) ~= "dead" then
        coroutine.resume(self.co, "EXIT")
    end
    self.co = nil
end

function base_macro:excute_loop()
    self.start_time = GetRunningTime()
    local loop_running_time = 0

    local function _check()
        for _, action in ipairs(self) do
            if action.type == "skill" then
                if action.interval == nil then
                    action:release_skill(self)
                elseif loop_running_time >= action.release_time then
                    action:release_skill(self)
                    action.release_time = action.release_time + action.interval
                end
            elseif action.type == "macro" then
                if action.interval == nil then
                    self:toggle(action.value)
                elseif loop_running_time >= action.release_time then
                    self:toggle(action.value)
                    action.release_time = action.release_time + action.interval
                end
                self.subtrigger[action.value] = true
            end
        end
    end

    -- init skill
    for _, action in ipairs(self) do
        if action.interval ~= nil then
            action.release_time = 0 
        end
    end

    if self.before ~= nil then
        self.before:excute_sequence()
    end

    while true do
        if self.exit then
            break
        end

        loop_running_time = GetRunningTime() - self.start_time
        if self.duration then
            if loop_running_time > self.duration then
                -- 超时
                break
            else
                _check()
            end
        else
            _check()
        end

        if coroutine.yield() == "EXIT" then
            self.exit = true
        end
    end

    if self.after ~= nil then
        self.after:excute_sequence()
    end
end

function base_macro:excute_sequence()
    local is_first_time = true

    local function _run(action)
        if action.type == "delay" then
        end
        if (action.once and not is_first_time) then
            return nil
        end

        if action.type == "delay" then
            delay(self, action.duration)

        elseif action.type == "macro" then
            macros:toggle(action.value)
            self.subtrigger[action.value] = true

        elseif action.type == "skill" then
            action:release_skill(self)
        end
    end

    repeat
        for _, action in ipairs(self) do
            _run(action)
            if self.exit then return nil end
        end
            
        is_first_time = false

        -- 每次循环后, 保留一个退出窗口
        if coroutine.yield() == "EXIT" then
            self.exit = true
        end
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

    if self.co ~= nil then
        if coroutine.status(self.co) == "dead" then
            self:deactive()
        elseif coroutine.status(self.co) == "suspended" then
            coroutine.resume(self.co)
        end
    end
end

if not macros then
    macros = {}
end

--[[
命名 action 中
loop 必须设置持续时间(duration)并且小于 60 秒,
sequence 的 loop 属性不能为 true.
]]
function macros:init()
    local function _init_string_macro(macro)
        if macro.type == "loop"
                and (macro.duration == nil
                    or macro.duration > 60000) then
            macro.duration = 0
        end
        if macro.type == "sequence" then
            macro.loop = false
        end
    end

    init_list_metatable(self, base_macro)

    for _, macro in ipairs(self) do
        init_list_metatable(macro, base_action)
        -- make macro.before and macro.before as a sequence macro
        for _, s in ipairs({macro.before, macro.after}) do
            if s ~= nil then
                s.type = "sequence"
                init_list_metatable({s}, base_macro)
                init_list_metatable(s, base_action)
            end
        end

        macro.enabled = false
        if type(macro.trigger) == "string" then
            _init_string_macro(macro)
        end
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
