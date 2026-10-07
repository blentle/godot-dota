extends RefCounted
## 开发物品目录；名称、价格与效果均不是已校对的原版装备。

const ITEMS := {
	"blade": {"name": "训练短剑", "short": "短剑", "price": 100, "damage": 12.0, "hp": 0.0, "mana": 0.0, "speed": 0.0, "description": "攻击 +12；多件叠加"},
	"vest": {"name": "训练护衣", "short": "护衣", "price": 150, "damage": 0.0, "hp": 150.0, "mana": 0.0, "speed": 0.0, "description": "生命上限 +150；购买不治疗"},
	"charm": {"name": "训练护符", "short": "护符", "price": 120, "damage": 0.0, "hp": 0.0, "mana": 80.0, "speed": 0.0, "description": "魔法上限 +80；购买不回魔"},
	"boots": {"name": "训练行靴", "short": "行靴", "price": 125, "damage": 0.0, "hp": 0.0, "mana": 0.0, "speed": 1.0, "description": "移动速度 +1；多双不叠加"}
}
