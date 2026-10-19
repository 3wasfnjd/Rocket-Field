-- صواريخ منصة الإطلاق — من جدول أسلحة "حرب الطاولة" (table-war/weapons/weapon_table.gd)
-- محوّلة لمقياس Roblox (studs). الصواريخ تنطلق من منصة المعسكر، واللاعب يختار الهدف من الكمبيوتر.
--   path      "arc" قوس باليستي | "cruise" يطير منخفض فوق الأرض ثم ينقضّ
--   flight    زمن الطيران للقوس (أطول = أعلى)
--   speed     سرعة الطيران المنخفض (cruise)
--   altitude  ارتفاع الطيران المنخفض فوق الأرض
--   blast     نصف قطر الانفجار، damage ضرر اللاعبين، structure ضرر المباني
--   hp        صحة الصاروخ (المضادات الأرضية تسقطه إذا خلصت)
--   cooldown  ثواني قبل ما يقدر نفس الفريق يطلق هذا النوع مرة ثانية
--   salvo     عدد الصواريخ (راجمة)، split عدد القنيبلات (عنقودي)، spread انتشارها

local Weapons = {}

Weapons.Gravity = 90

Weapons.List = {
	ballistic = {
		id = "ballistic",
		name = "صاروخ باليستي",
		path = "arc",
		flight = 5.0,
		blast = 22,
		damage = 110,
		structure = 160,
		hp = 60,
		cooldown = 20,
		scale = 2.2,
		color = Color3.fromRGB(215, 218, 210),
		order = 1,
	},
	cruise = {
		id = "cruise",
		name = "صاروخ كروز",
		path = "cruise",
		speed = 95,
		altitude = 22,
		blast = 16,
		damage = 90,
		structure = 120,
		hp = 40,
		cooldown = 14,
		scale = 1.8,
		wings = true,
		color = Color3.fromRGB(140, 148, 140),
		order = 2,
	},
	mlrs = {
		id = "mlrs",
		name = "راجمة صواريخ",
		path = "arc",
		flight = 3.2,
		blast = 9,
		damage = 40,
		structure = 45,
		hp = 10,
		cooldown = 22,
		salvo = 8,
		spread = 26,
		scale = 0.9,
		color = Color3.fromRGB(122, 132, 96),
		order = 3,
	},
	cluster = {
		id = "cluster",
		name = "صاروخ عنقودي",
		path = "arc",
		flight = 5.0,
		blast = 8,
		damage = 35,
		structure = 40,
		hp = 50,
		cooldown = 30,
		split = 10,
		spread = 30,
		scale = 2.0,
		color = Color3.fromRGB(200, 184, 128),
		order = 4,
	},
	hypersonic = {
		id = "hypersonic",
		name = "صاروخ فرط صوتي",
		path = "arc",
		flight = 1.6,
		blast = 30,
		damage = 140,
		structure = 220,
		hp = 120,
		cooldown = 60,
		scale = 2.4,
		color = Color3.fromRGB(56, 56, 66),
		order = 5,
	},
	bunker = {
		id = "bunker",
		name = "خارق التحصينات",
		path = "arc",
		flight = 6.0,
		blast = 14,
		damage = 70,
		structure = 400,
		hp = 70,
		cooldown = 40,
		scale = 2.2,
		color = Color3.fromRGB(102, 108, 92),
		order = 6,
	},
	drone = {
		id = "drone",
		name = "مسيّرة انتحارية",
		path = "cruise",
		speed = 45,
		altitude = 30,
		blast = 12,
		damage = 70,
		structure = 90,
		hp = 20,
		cooldown = 9,
		scale = 1.6,
		wings = true,
		color = Color3.fromRGB(220, 220, 212),
		order = 7,
	},
}

-- قنيبلة العنقودي (مو قابلة للاختيار)
Weapons.Submunition = {
	id = "submunition",
	name = "قنيبلة",
	path = "arc",
	flight = 1.1,
	blast = 7,
	damage = 30,
	structure = 35,
	hp = 5,
	scale = 0.6,
	color = Color3.fromRGB(190, 176, 120),
}

function Weapons.Sorted()
	local list = {}
	for _, w in Weapons.List do
		table.insert(list, w)
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

-- السرعة الابتدائية لقوس يوصل الهدف بزمن معيّن
function Weapons.ArcVelocity(origin: Vector3, target: Vector3, flight: number): Vector3
	local g = Vector3.new(0, -Weapons.Gravity, 0)
	return (target - origin - 0.5 * g * flight * flight) / flight
end

function Weapons.ArcPoint(origin: Vector3, velocity: Vector3, t: number): Vector3
	return origin + velocity * t + 0.5 * Vector3.new(0, -Weapons.Gravity, 0) * t * t
end

return Weapons
