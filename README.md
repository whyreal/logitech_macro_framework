Macro framework of logitech mouse for diablo3 or other game.

暗黑3 罗技鼠标宏框架

# 目标

降低罗技鼠标宏开发难度.
使用本框架, 不了解编程知识的人, 也可以方便的编写鼠标宏.

# 使用方法

1. 创建宏
2. 关闭按键默认绑定
3. 右键-> 编辑脚本
5. 将 macros 定义, 粘贴到文本框中
4. 将 framework.lua 内容粘贴到文本框中, macros 定义之后
5. 启用宏

# macros 定义

## macro(宏) 分类

从宏的用途方面, 可以将将宏分为两类:

- 周期宏 loop

	用来执行周期性指令, 通常是 buff 类技能

- 序列宏 sequence

	用来执行有前后顺序的一系列指令

从触发方式, 也可以将宏分为两类:

- 数字宏

	由鼠标按键触发

	数字宏, 具有排他性, 当激活一个数字宏, 其他的数字宏将被自动关闭.

- 命名宏

	由宏触发, 本框架中, 宏是可以嵌套的

## 简介

	keymap = {
		left = "left";
		ji_neng1 = "1"
	}

	macros = {
		{ 
			trigger  = 4,

			loop = {
				{ type = "skill", key = keymap.left };
			},
		},
		{ 
			trigger  = 7,

			sequence = {
				{ type = "skill", key = keymap.ji_neng1 };
			},
		},
	}

上述宏定义中, macros 中定义了两个宏:

第一个宏:

- G4 触发
- 定义了一个 loop 宏
- loop 中包含了一个 action: 点击左键
- action 由于没有定义执行周期 -- interval, 表示每个执行周期(25ms, 1.5 帧)都会点击一次左键

第二个宏:

- G7 触发
- 定义了一个 sequence 宏
- sequence 中包含了一个 action: 点击 "keymap.ji_neng1" 对应的按键, 这里是 "1"

当我们点击 G4 开启第一个宏, 可以实现左键连点. 再次点击 G4, 则左键连点关闭.

当我们点击 G7 开启第二个宏, 点击 "1" 一次.

当点击 G4 开启第一个宏后, 如果点击 G7, 由于是数字宏, 在启动第二个宏的同时, 第一个宏将被关闭. 

> 数字宏, 具有排他性, 当激活一个数字宏, 其他的数字宏将被自动关闭.

> 数字宏, 具有排他性, 当激活一个数字宏, 其他的数字宏将被自动关闭.

> 数字宏, 具有排他性, 当激活一个数字宏, 其他的数字宏将被自动关闭.

## 动作 action

 action 即 动作, loop 或者 sequence 中包含的没一条指令即为一个 action. 本框架中, 提供了 3 种 action:

### skill
 	
用于技能释放

格式:

	{ type = "skill", key = "1", interval = 1000, modifier = "lsfift", duration = 1000, once = true};

- type

	设定 action 类型

	必选

- key

	设定技能对应的按键, 例如: "a", "b", "1", "2" 等等, 鼠标左键为"left", 右键为"right"

	必选

- interval

	设定技能释放间隔时间, 单位为毫秒, 1000 即为 1 秒

	可选

- duration

	设定技能持续时间, 单位为毫秒, 适用于引导类技能

	可选

- modifier

	设定修饰按键, 例如: "lshift" -- 左边的shift,  保持强制站立

	可选

- once

	设定该技能是否只在 sequence 第一次执行触发, true 或者 false

### delay

使宏等待一段时间

格式:

	{ type = "delay", duration = "1000" };

- type

	设定 action 类型

	必选

- duration

	设定等待持续时间, 单位为毫秒, 适用于引导类技能

	必选

### macro

用来触发另一个宏

格式:

	{ type = "macro", value = "yun_shi" };

- type

	设定 action 类型

	必选

- value

	设定被触发的宏名称

	必选

## 周期宏 loop 定义

	keymap = {   -- 定义按键
		 name = "1"   
	}

	macros = {
		{ 
			trigger  = 4,


			loop = {

				duration = 20000,

				before = {
					action;
					action;
					...
				};
				action;
				action;
				...
				after = {
					action;
					action;
					...
				};
			};
		}
	}

loop 宏, 可以定义持续时间 duration, 超过 duration, 宏会自动关闭.

支持 before, after, 可以在宏开始前, 或结束后执行 action.

假设一个法师, 想要在变身黑人后, 持续点击左键, 同时每 2 秒释放技能 1, 而且在变身结束后释放黑洞, 可以编写如下宏:

	keymap = {
		left = "left";          -- 定义左键
		hei_dong = "1";         -- 定义黑洞按键
		bin_bao_shu = "1";      -- 定义冰爆术按键
		hei_ren = "4";          -- 定义黑人按键
	}

	macros = {
		{ 
			trigger  = 4,      -- 使用 G4 触发该宏

			loop = {

				duration = 20000, -- 持续 20 秒

				before = {   -- 技能循环开始前执行
					{ type = "skill", key = keymap.hei_ren};  -- 变身
				},

				{ type = "skill", key = keymap.left};  -- 持续点击左键
				{ type = "skill", key = keymap.bin_bao_shu, interval = 2000};  -- 每两秒释放冰爆术

				before = {   -- 技能循环结束后, 或 宏被关闭时 执行
					{ type = "skill", key = keymap. hei_dong};  -- 释放黑洞
				},

			},
		},
	}

## 序列宏 sequence 定义

	keymap = {
		name = "1";
	}

	macros = {
		{ 
			trigger  = 4,

			sequence = {

				loop = true; 是否重复执行

				action;
				action;
				...
		}
	}

sequence 宏, 可以通过设置 loop 属性设置是否重复执行. 如果不设置 loop 则 sequence 只执行一次.

假设一个法师, 想要顺序执行以下动作:

1. 释放陨石
2. 释放左键技能
3. 释放引导技能

可以编写以下宏:

	keymap = {
		yun_shi = "1";  -- 定义陨石按键
		hei_ren = "2";  -- 定义黑人按键
		hui_neng = "left";  -- 定义左键
		yin_dao = "right";  -- 定义引导技能按键
	}

	macros = {
		{ 
			trigger  = 4,  -- G4 触发

			sequence = {

				-- 陨石
				{ type = "skill", key = keymap.yun_shi};

				-- 延时 350 毫秒
				{ type = "delay", duration = "350" };

				-- 强制站立 点击左键 持续 500 毫秒
				{ type = "skill", key = keymap.hui_neng, duration = 500, modifier = "lshift"};

				-- 延时 350 毫秒
				{ type = "delay", duration = "350" };

				-- 引导技能
				{ type = "skill", key = keymap.ying_dao, duration = 50};
				}
		}
	}

## macros 定义

	keymap = {
		-- 按键定义
	}

	macros = {
		{ 宏 1 };
		{ 宏 2 };
		...
	}

keymap 中可以给按键定义一个名字, 方便后续宏的编写, 当然也可以不定义 keymap, 在 action 的 key 属性中直接配置按键.

macros 中包含了我们定义的所有宏, 可以有多个.

"macros" 这个名字不可修改

每个宏中, 都需要定义一个 触发器按键 -- trigger, 如果是数字, 则代表该宏由鼠标 G 键触发, 例如: trigger 为 4, 代表由鼠标 G4 键触发; 如果是字符串, 则表示该宏为"命名宏", 由其他宏触发.

宏中, 可以同时包含 loop 和 sequence

## 示例

以下宏定义只作为演示, 未经测试, 不建议直接用于游戏

奶僧

	keymap = {
		left = "left";
		jufengpo = "right";
		chanding = "1";
		linguangwu = "2";
		jinlunzhen = "3";
		zhenyan = "4";
	}

	macros = {
		-- 赶路
		{ 
			trigger  = 7,

			loop = {
				{ type = "skill", key = keymap.zhenyan,   interval = 2900 };
				{ type = "skill", key = keymap.linguangwu, interval = 1000 };
				{ type = "skill", key = keymap.left };
			},
		},
		-- 站桩
		{ 
			trigger  = 4,

			loop = {
				{ type = "skill", key = keymap.jufengpo, interval = 1000};
				{ type = "skill", key = keymap.left};
				{ type = "skill", key = keymap.chanding,   interval = 1000 };
				{ type = "skill", key = keymap.linguangwu, interval = 1000 };
				{ type = "skill", key = keymap.jinlunzhen, interval =  5900 };
				{ type = "skill", key = keymap.zhenyan,   interval = 500 };
			}
		}
	}

奥陨

	keymap = {
		yunshi = "1";
		heiren = "2";
		huineng = "left";
		yindao = "right";
	}

	macros = {
		{ 
			trigger  = 4,

			sequence = {

				loop = true;

				-- 变黑人
				{ type = "skill", key = keymap.heiren};
				{ type = "delay", duration = "20000" };

				-- 第一次 由于没有勾玉 增加 7 秒延迟
				{ type = "delay", duration = "7000", once=true };

				-- 正常延迟
				{ type = "delay", duration = "4250" };

				-- 第一发
				{ type = "skill", key = keymap.yunshi};
				{ type = "delay", duration = "350" };

				-- 回能
				{ type = "skill", key = keymap.huineng, duration = 500, modifier = "lshift"};

				{ type = "delay", duration = "350" };

				-- 引导技能
				{ type = "skill", key = keymap.yindao, duration = 350};

				{ type = "delay", duration = "5000" };

				-- 第二发
				{ type = "skill", key = keymap.yunshi};
				{ type = "delay", duration = "350" };

				-- 回能
				{ type = "skill", key = keymap.huineng, duration = 450, modifier = "lshift"};

				{ type = "delay", duration = "350" };

				-- 引导技能
				{ type = "skill", key = keymap.yindao, duration = 50};
			}
		}
	}

奥陨 2

	-- 火 1s 后开宏
	keymap = {
		yun_shi = "1";
		hei_ren = "2";
		zeng_shang = "3";
		hu_jia = "4";
		hui_neng = "left";
		ying_dao = "right";
	}

	macros = {
		{ 
			trigger  = 4,

			sequence = {

				loop = true;

				-- 黑人
				{ type = "macro", value = "hei_ren" };
				{ type = "delay", duration = "20000" };

					-- 第一次 由于没有勾玉 增加 7 秒延迟
					{ type = "delay", duration = "7000", once=true };

				{ type = "skill", key = keymap.hui_neng, duration = 3250 };
				{ type = "skill", key = keymap.zeng_shang};
				{ type = "delay", duration = "1000" };

				-- 第一发
				{ type = "macro", value = "yun_shi" };
				{ type = "delay", duration = 1250 };

				{ type = "skill", key = keymap.hui_neng, duration = 4250 };
				{ type = "skill", key = keymap.zeng_shang};
				{ type = "delay", duration = "1000" };

				-- 第二发
				{ type = "macro", value = "yun_shi" };
				{ type = "delay", duration = 1250 };
			}
		},
		{
			trigger = "hei_ren",
			loop = {
				duration = 20000;
				before = {
					{ type = "skill", key = keymap.shi_jian_yan_chi};
				},
				{ type = "skill", key = keymap.bin_bao_shu };
			},
		},
		{
			trigger = "yun_shi",
			sequence = {
				-- 陨石
				{ type = "skill", key = keymap.yun_shi};
				{ type = "delay", duration = "350" };

				-- 回能
				{ type = "skill", key = keymap.hui_neng, duration = 500, modifier = "lshift"};
				{ type = "delay", duration = "350" };

				-- 引导技能
				{ type = "skill", key = keymap.ying_dao, duration = 50};
			}
		}
	}

# 注意事项

- action 中的 modifier 属性, 可以用来实现强制站立. 但是, 对于非持续性技能, 效果不佳, 不建议使用.

- 命名宏中, loop 必须设置持续时间(duration) 且不能超过 60 秒, sequence 的 loop 属性不能为 true.
