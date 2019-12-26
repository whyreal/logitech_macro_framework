-- Unit testing starts
unit = require('luaunit')

require('framework_new')
require('mock')

pressed_key = {}
loop_macro = {
    trigger  = 7,
    type = "loop",

    before = {
        { type = "skill", key = "1"};
    },

    { type = "skill", key = "2"};

    after = {
        { type = "skill", key = "3"};
    },
}

TestActionPressKey = {} --class
    function TestActionPressKey:setup()
        a = Action:new()
    end

    function TestActionPressKey:testPress()
        a.key = "1"
        a.modifier = "lshift"

        pressed_key = {}
        a:press_key()
        unit.assertEquals(pressed_key[a.key][1], "down")
        unit.assertEquals(a.key_status, "down")
        unit.assertEquals(pressed_key[a.modifier][1], "down")

        a:release_key()
        unit.assertEquals(pressed_key[a.key][1], "up")
        unit.assertEquals(a.key_status, "up")
        unit.assertEquals(pressed_key[a.modifier][1], "up")

        a.modifier = nil

        pressed_key = {}
        a.key = "right"

        a:press_key()
        unit.assertEquals(pressed_key[3][1], "down")
        unit.assertEquals(a.key_status, "down")

        a:release_key()
        unit.assertEquals(pressed_key[3][1], "up")
        unit.assertEquals(a.key_status, "up")

        pressed_key = {}
        a.key = "left"

        a:press_key()
        unit.assertEquals(pressed_key[1][1], "down")
        unit.assertEquals(a.key_status, "down")

        a:release_key()
        unit.assertEquals(pressed_key[1][1], "up")
        unit.assertEquals(a.key_status, "up")
    end

TestActionFinished = {} --class
    function TestActionFinished:setup()
        a = Action:new({duration_end = 1}, {running_time = 2})
    end

    function TestActionFinished:testFinished(args)
        unit.assertEquals(a:finished(), true)
    end
    function TestActionFinished:testNotFinished(args)
        a.duration_end = 3
        unit.assertEquals(a:finished(), false)
    end

TestActionReleaseSkill = {} --class
    function TestActionReleaseSkill:setup()
        a = Action:new({key = "1", key_status = "up"}, {type = "loop", running_time = 1})
    end
    function TestActionReleaseSkill:testReleaseSkill()
        a:release_skill()
        unit.assertEquals(pressed_key[a.key][1], "up")
        unit.assertEquals(pressed_key[a.key][2], "down")
    end
    function TestActionReleaseSkill:testReleaseSkillDuration()
        a.duration = 1
        a:release_skill()
        unit.assertEquals(pressed_key[a.key][1], true)

        a.context.running_time = 3
        a:release_skill()
        unit.assertEquals(pressed_key[a.key][1], nil)
    end
    function TestActionReleaseSkill:testReleaseSkillDuration()
        a.key_status = "down"
        a.context.type = "sequence"
        a.context.delay = function () end

        a:release_skill()
        unit.assertEquals(pressed_key[a.key][1], "up")
    end

TestActionRunOnce = {}
    function TestActionRunOnce:setup()
        a = Action:new({once = true}, {is_first_time = false})
    end

    function TestActionRunOnce:testRun(args)
        unit.assertEquals(a:run(), nil)
    end

TestActionRunDelay = {}
    function TestActionRunDelay:setup()
        context_duration = 0
        a = Action:new({once = true, type = "delay", duration = 1},
            {
                is_first_time = true,
                delay = function(context, duration)
                    context_duration = duration
                end,
            })
    end

    function TestActionRunDelay:testRun()
        a:run()
        unit.assertEquals(context_duration, a.duration)
    end

TestActionRunSkill = {}
    function TestActionRunSkill:setup()
        context_duration = 0
        a = Action:new({type = "skill", release_time = 2, key = "2"},
            {
                running_time = 2
            })
    end

    function TestActionRunSkill:testNoInterval()
        a:run()
        unit.assertEquals(pressed_key[a.key][1], "up")
        unit.assertEquals(pressed_key[a.key][2], "down")
    end

    function TestActionRunSkill:testInterval()
        a.interval = 5
        a.release_time = 100
        a.context.running_time = 101
        a:run()
        unit.assertEquals(pressed_key[a.key][1], "up")
        unit.assertEquals(pressed_key[a.key][2], "down")
        unit.assertEquals(a.release_time, 105)
    end

TestActionRunMacro = {}
    function TestActionRunMacro:setup()
        context_duration = 0
        a = Action:new({type = "macro", value = "x"},
            {
                running_time = 2,
                subtrigger = {}
            })
        macros_toggled = nil
        Macros = {}
        function Toggle(value)
            macros_toggled = value
        end
    end

    function TestActionRunMacro:testNoInterval()
        a:run()
        unit.assertEquals(macros_toggled, a.value)
    end

    function TestActionRunMacro:testInterval()
        a.interval = 5
        a.release_time = 100
        a.context.running_time = 101
        a:run()
        unit.assertEquals(macros_toggled, a.value)
        unit.assertEquals(a.release_time, 105)
    end

TestToggle = {}
    function TestToggle:setup()
        run_macro = false
        table.insert(ActivedMacros, {
                run = function ()
                    run_macro = true
                end
            })
    end
    function TestToggle:testRun()
        ActivedMacros:run()
        unit.assertEquals(run_macro, true)
    end

TestMacroLoop = {}
    function TestMacroLoop:setup()
        m = Macro:new(loop_macro)
        m.running_time = 100
        function m:updateTime() end
    end

    function TestMacroLoop:testNew()
        unit.assertEquals(#m.actions, 1)
        unit.assertEquals(#m.after, 1)
        unit.assertEquals(#m.before, 1)
    end

    function TestMacroLoop:testActiveRunDeactive()
        unit.assertEquals(m.is_first_time, true)
        pressed_key = {}
        m:active()
        unit.assertEquals(type(m.co), "thread")
        unit.assertEquals(m.is_first_time, false)

        unit.assertEquals(pressed_key[m.before[1].key], {"up", "down"})
        unit.assertEquals(pressed_key[m.actions[1].key], {"up", "down"})

        pressed_key = {}
        m:run()
        unit.assertEquals(pressed_key[m.actions[1].key], {"up", "down"})

        m:deactive()
        unit.assertEquals(m.exit, true)
        unit.assertEquals(pressed_key[m.after[1].key], nil)
    end

TestMacroLoop2 = {}
    function TestMacroLoop:setup()
        m = Macro:new(loop_macro)
        m.running_time = 100
        function m:updateTime() end
    end
    function TestMacroLoop2:testTimeout()
        m:active()
        unit.assertEquals(m:timeout(), false)

        m.duration = 150
        unit.assertEquals(m:timeout(), false)

        m.duration = 50
        unit.assertEquals(m:timeout(), true)

        pressed_key = {}
        m:run()
        unit.assertEquals(pressed_key[m.after[1].key], {"up", "down"})
    end

os.exit( unit.LuaUnit.run())
