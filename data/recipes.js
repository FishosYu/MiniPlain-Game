/*
  station:
  - toolbox: 破旧工具箱制造
  - forge: 铸造台铸造
  - campfire: 篝火 + 背包铁锅烹饪
  - iron_plate: 站在铁板上煎烤
  - mill: 站在石磨上研磨
  - prep_table: 站在料理台上调理
  - oven: 站在烤箱上烘烤

  inputs 中的材料顺序不影响匹配；单材料配方只写一个 id。
*/
window.MINIPLAIN_RECIPES = [
  { station: 'toolbox', inputs: ['iron', 'stone'], output: 'forge' },
  { station: 'toolbox', inputs: ['stone', 'stone'], output: 'flint' },
  { station: 'toolbox', inputs: ['wood', 'wood'], output: 'chest' },
  { station: 'toolbox', inputs: ['stone', 'wood'], output: 'building' },
  { station: 'toolbox', inputs: ['flint', 'wood'], output: 'campfire' },
  { station: 'toolbox', inputs: ['campfire', 'iron'], output: 'oven' },
  { station: 'toolbox', inputs: ['stone', 'wood_plank'], output: 'bridge' },
  { station: 'toolbox', inputs: ['stone_slab', 'stone'], output: 'mill' },
  { station: 'toolbox', inputs: ['wood_plank', 'wood'], output: 'prep_table' },
  { station: 'toolbox', inputs: ['stone_axe', 'wood'], output: 'wood_plank', returns: [{ id: 'stone_axe', count: 1 }] },
  { station: 'toolbox', inputs: ['iron_sheet', 'iron_sheet'], output: 'iron_bucket' },
  { station: 'toolbox', inputs: ['hammer', 'iron'], output: 'iron_sheet', returns: [{ id: 'hammer', count: 1 }] },
  { station: 'toolbox', inputs: ['hammer', 'silver'], output: 'silver_sheet', returns: [{ id: 'hammer', count: 1 }] },
  { station: 'toolbox', inputs: ['iron_sheet', 'silver_sheet'], output: 'iron_silver_sheet' },
  { station: 'toolbox', inputs: ['fruit', 'iron_silver_sheet'], output: 'fruit_battery' },

  { station: 'forge', inputs: ['stone', 'wood'], output: 'stone_axe' },
  { station: 'forge', inputs: ['iron', 'wood'], output: 'iron_sword' },
  { station: 'forge', inputs: ['iron', 'iron'], output: 'iron_pot' },
  { station: 'forge', inputs: ['iron', 'stone'], output: 'iron_plate' },
  { station: 'forge', inputs: ['stone', 'stone'], output: 'hammer' },
  { station: 'forge', inputs: ['hammer', 'stone'], output: 'stone_slab', returns: [{ id: 'hammer', count: 1 }] },
  { station: 'forge', inputs: ['gold'], output: 'coin', count: 2 },
  { station: 'forge', inputs: ['silver'], output: 'silver_coin', count: 2 },

  { station: 'campfire', inputs: ['veg'], output: 'grilled_veg' },
  { station: 'campfire', inputs: ['potato'], output: 'roasted_potato' },
  { station: 'campfire', inputs: ['carrot'], output: 'roasted_carrot' },
  { station: 'campfire', inputs: ['egg'], output: 'fried_egg' },
  { station: 'campfire', inputs: ['chicken'], output: 'cooked_chicken' },
  { station: 'campfire', inputs: ['beef'], output: 'cooked_beef' },
  { station: 'campfire', inputs: ['fish'], output: 'grilled_fish' },
  { station: 'campfire', inputs: ['wheat'], output: 'stir_fried_wheat' },
  { station: 'campfire', inputs: ['veg', 'veg'], output: 'vegetable_stew' },
  { station: 'campfire', inputs: ['potato', 'veg'], output: 'potato_vegetable_stew' },
  { station: 'campfire', inputs: ['carrot', 'veg'], output: 'carrot_vegetable_stew' },
  { station: 'campfire', inputs: ['potato', 'potato'], output: 'roasted_potato', count: 2 },
  { station: 'campfire', inputs: ['carrot', 'potato'], output: 'carrot_potato_stew' },
  { station: 'campfire', inputs: ['carrot', 'carrot'], output: 'roasted_carrot', count: 2 },
  { station: 'campfire', inputs: ['egg', 'egg'], output: 'scrambled_eggs' },
  { station: 'campfire', inputs: ['chicken', 'egg'], output: 'chicken_egg_bowl' },
  { station: 'campfire', inputs: ['beef', 'egg'], output: 'beef_egg' },
  { station: 'campfire', inputs: ['chicken', 'chicken'], output: 'big_plate_chicken' },
  { station: 'campfire', inputs: ['beef', 'chicken'], output: 'chicken_beef_stew' },
  { station: 'campfire', inputs: ['beef', 'beef'], output: 'cooked_beef', count: 2 },
  { station: 'campfire', inputs: ['egg', 'veg'], output: 'veg_egg' },
  { station: 'campfire', inputs: ['chicken', 'veg'], output: 'veg_chicken_stew' },
  { station: 'campfire', inputs: ['beef', 'veg'], output: 'veg_beef_stew' },
  { station: 'campfire', inputs: ['egg', 'potato'], output: 'potato_egg' },
  { station: 'campfire', inputs: ['chicken', 'potato'], output: 'potato_chicken_stew' },
  { station: 'campfire', inputs: ['beef', 'potato'], output: 'potato_beef_stew' },
  { station: 'campfire', inputs: ['carrot', 'egg'], output: 'carrot_egg' },
  { station: 'campfire', inputs: ['carrot', 'chicken'], output: 'carrot_chicken' },
  { station: 'campfire', inputs: ['beef', 'carrot'], output: 'carrot_beef' },
  { station: 'campfire', inputs: ['wheat', 'wheat'], output: 'stir_fried_wheat', count: 2 },
  { station: 'campfire', inputs: ['fish', 'fish'], output: 'grilled_fish', count: 2 },
  { station: 'campfire', inputs: ['fish', 'veg'], output: 'fish_vegetable_stew' },

  { station: 'iron_plate', inputs: ['veg'], output: 'grilled_veg' },
  { station: 'iron_plate', inputs: ['potato'], output: 'roasted_potato' },
  { station: 'iron_plate', inputs: ['carrot'], output: 'roasted_carrot' },
  { station: 'iron_plate', inputs: ['egg'], output: 'fried_egg' },
  { station: 'iron_plate', inputs: ['chicken'], output: 'cooked_chicken' },
  { station: 'iron_plate', inputs: ['beef'], output: 'plain_steak' },
  { station: 'iron_plate', inputs: ['fish'], output: 'grilled_fish' },
  { station: 'iron_plate', inputs: ['wheat'], output: 'stir_fried_wheat' },
  { station: 'iron_plate', inputs: ['egg', 'egg'], output: 'scrambled_eggs' },
  { station: 'iron_plate', inputs: ['potato', 'potato'], output: 'roasted_potato', count: 2 },
  { station: 'iron_plate', inputs: ['carrot', 'carrot'], output: 'roasted_carrot', count: 2 },
  { station: 'iron_plate', inputs: ['beef', 'beef'], output: 'plain_steak', count: 2 },
  { station: 'iron_plate', inputs: ['fish', 'fish'], output: 'grilled_fish', count: 2 },
  { station: 'iron_plate', inputs: ['wheat', 'wheat'], output: 'stir_fried_wheat', count: 2 },
  { station: 'iron_plate', inputs: ['flour', 'chicken'], output: 'original_chicken' },

  { station: 'mill', inputs: ['wheat'], output: 'flour' },
  { station: 'mill', inputs: ['wheat', 'wheat'], output: 'flour', count: 2 },

  { station: 'prep_table', inputs: ['flour', 'milk'], output: 'rich_dough' },
  { station: 'prep_table', inputs: ['flour', 'water'], output: 'dough' },
  { station: 'prep_table', inputs: ['dough', 'egg'], output: 'cake_base' },
  { station: 'prep_table', inputs: ['bread', 'original_chicken'], output: 'chicken_burger' },
  { station: 'prep_table', inputs: ['bread', 'plain_steak'], output: 'beef_burger' },

  { station: 'oven', inputs: ['rich_dough'], output: 'bread' },
  { station: 'oven', inputs: ['dough'], output: 'steamed_bun' },
  { station: 'oven', inputs: ['dough', 'beef'], output: 'meat_bun' },
  { station: 'oven', inputs: ['cake_base'], output: 'cake' },
];
