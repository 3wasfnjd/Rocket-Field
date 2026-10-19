-- أسلحة ميدان الصواريخ — مأخوذة من جدول أسلحة "حرب الطاولة" (table-war/weapons/weapon_table.gd)
-- ومحوّلة لمقياس Roblox (studs). كل الفرق بين سلاح وثاني هنا.
--   path     "straight" صاروخ مستقيم | "arc" قوس باليستي
--   flight   زمن الطيران بالثواني (للقوس) — أطول = قوس أعلى
--   speed    سرعة الصاروخ المستقيم
--   blast    نصف قطر الانفجار
--   damage   ضرر في مركز الانفجار (يقل مع البعد)
--   structure ضرر على المباني
--   cooldown ثواني بين طلقتين، ammo الذخيرة الكاملة، reload ثواني لكل طلقة ترجع (0 = ما ترجع)
--   salvo    عدد الصواريخ بالضغطة (راجمة)، spread انتشارها حول الهدف
--   warn     دائرة تحذير على الأرض قبل الوصول
--   crate    ما يكون مع اللاعب من البداية، يطلع من صناديق

local Weapons = {}

Weapons.Gravity = 110 -- جاذبية القذائف (أخف من جاذبية اللاعب عشان الأقواس تكون حلوة)

Weapons.List = {
	rocket = {
		id = "rocket",
		name = "قاذفة صواريخ",
		path = "straight",
		speed = 160,
		maxRange = 420,
		blast = 10,
		damage = 70,
		structure = 60,
		cooldown = 1.2,
		ammo = 4,
		reload = 3,
		color = Color3.fromRGB(110, 120, 90),
		trail = Color3.fromRGB(235, 230, 220),
		order = 1,
	},
	mortar = {
		id = "mortar",
		name = "مدفع هاون",
		path = "arc",
		flight = 1.6,
		maxRange = 280,
		blast = 8,
		damage = 45,
		structure = 35,
		cooldown = 0.8,
		ammo = 8,
		reload = 2,
		color = Color3.fromRGB(85, 88, 80),
		trail = Color3.fromRGB(200, 198, 190),
		order = 2,
	},
	mlrs = {
		id = "mlrs",
		name = "راجمة صواريخ",
		path = "arc",
		flight = 1.5,
		maxRange = 320,
		blast = 6,
		damage = 30,
		structure = 25,
		cooldown = 6,
		ammo = 2,
		reload = 9,
		salvo = 8,
		spread = 12,
		color = Color3.fromRGB(122, 132, 96),
		trail = Color3.fromRGB(220, 214, 200),
		order = 3,
	},
	ballistic = {
		id = "ballistic",
		name = "صاروخ باليستي",
		path = "arc",
		flight = 3.0,
		maxRange = 600,
		blast = 20,
		damage = 110,
		structure = 200,
		cooldown = 4,
		ammo = 2,
		reload = 0,
		warn = true,
		crate = true,
		color = Color3.fromRGB(215, 218, 210),
		trail = Color3.fromRGB(245, 240, 230),
		order = 4,
	},
}

-- السرعة الابتدائية لقوس يوصل الهدف بزمن معيّن
function Weapons.ArcVelocity(origin: Vector3, target: Vector3, flight: number): Vector3
	local g = Vector3.new(0, -Weapons.Gravity, 0)
	return (target - origin - 0.5 * g * flight * flight) / flight
end

function Weapons.ArcPoint(origin: Vector3, velocity: Vector3, t: number): Vector3
	return origin + velocity * t + 0.5 * Vector3.new(0, -Weapons.Gravity, 0) * t * t
end

-- يقصّر الهدف إذا أبعد من مدى السلاح
function Weapons.ClampTarget(origin: Vector3, target: Vector3, maxRange: number): Vector3
	local d = target - origin
	if d.Magnitude > maxRange then
		return origin + d.Unit * maxRange
	end
	return target
end

-- من وين يطلع الصاروخ: فوق كتف اللاعب اليمين
function Weapons.Muzzle(root: BasePart): Vector3
	return root.Position + Vector3.new(0, 2.2, 0) + root.CFrame.RightVector * 1.1 + root.CFrame.LookVector * 1.5
end

return Weapons
