# Stonia.html 代码结构与架构说明

本文档从代码实现角度分析 `Stonia.html` 的结构和架构设计，适用于开发者理解代码组织方式。

## 1. 整体架构

`Stonia.html` 是一个单页 HTML 应用，所有代码（HTML、CSS、JavaScript）都在一个文件中。JavaScript 主体是一个立即执行函数表达式（IIFE），内部封装了所有游戏状态和逻辑，无外部依赖。

### 文件结构

```
<!DOCTYPE html>
├── <head>
│   ├── <title>Stonia Demo</title>
│   └── <style> 全部 CSS 样式 </style>
├── <body>
│   ├── 界面布局（左右两栏）
│   │   ├── 左栏：状态栏 + 地图网格 + 日志
│   │   ├── 右栏：背包 + 箱子 + 合成区
│   │   └── 提示文字
│   ├── 模态弹窗（通用弹窗 + 通关弹窗）
│   └── <script> IIFE 包裹的全部游戏逻辑 </script>
└── </html>
```

## 2. CSS 结构

使用 CSS 变量定义主题色：

```css
:root {
  --bg: #f5f0e8;
  --panel: #fffef9;
  --border: #d4cfc4;
  --text: #3d3830;
  --accent: #7a9e6a;
  /* ... */
}
```

布局采用 CSS Grid 实现两栏响应式布局：主地图区域（左）和背包/合成面板（右）。使用 `@media (max-width: 720px)` 断点在窄屏下切换为单栏。

地图格（`.cell`）使用固定尺寸 40×40px 的 Grid 布局，11 列。关键 CSS 类：

| 类名 | 用途 |
|------|------|
| `.cell.hidden` | 夜晚未照亮时隐藏 |
| `.cell.player` | 玩家所在格描边 |
| `.cell.breakable` | 可凿石/可放置高亮 |
| `.cell.ground-normal/water/stone` | 地面类型 |
| `.cell.campfire-lit` | 篝火照亮区域 |
| `.cell.crystal-lit` | 水晶球照亮区域 |
| `.inv-cell.selected` | 背包物品选中态 |
| `.craft-box.filled` | 合成格已放入材料 |
| `.modal-bg.show` | 弹窗显示 |

夜晚模式使用 `body.night-mode` 类切换，通过 `.visible-night`、`.campfire-lit`、`.crystal-lit` 控制可见性。

## 3. JavaScript 数据模型

所有代码封装在单个 IIFE 中，无模块化导出。

### 3.1 常量

```javascript
const SIZE = 11;          // 地图尺寸 11×11
const CENTER = 5;         // 中心格坐标
const STAMINA_MAX = 30;   // 体力上限
const INV_MAX = 30;       // 背包容量上限
const CHEST_MAX = 30;     // 箱子容量上限
```

### 3.2 物品定义（ITEMS 表）

`ITEMS` 对象定义了所有物品类型，每个物品可包含以下属性：

```javascript
{
  name: '铁块',       // 显示名称
  emoji: '🔩',        // 显示图标（当前用 emoji 占位）
  vol: 1,             // 体积（0 表示不占空间）
  use: 'heal1',       // 使用效果（可选）：heal1/2/3/heal_fish
  plant: true,        // 可栽种（可选，用于树苗）
  place: 'forge'      // 可放置结构（可选）：forge/chest/toolbox/campfire
}
```

### 3.3 核心状态

```javascript
let grid = [];                    // 11×11 二维数组，格对象包含：
                                  // { stone, ground, hidden, entity, plant,
                                  //   structure, mature, treeHits, wheatHits,
                                  //   hadTree, incubatingEgg, groundLoot, lit, spawn }

let player = {                    // 玩家状态
  x, y,                           // 当前坐标
  stamina,                        // 体力值 0-30
  exp,                            // 当前经验
  level,                          // 等级
  breaks                          // 累计凿石次数（驱动昼夜和多种机制）
};

let inventory = [];               // 背包：{ id, count } 数组
const chestStorages = {};         // 箱子存储：以 "x,y" 为 key 的 { id, count }[] 对象

let craftSlots = [null, null];    // 合成材料格
let craftMode = 'make';           // 合成模式：make / forge / cook
let placedMode = null;            // 放置模式：sapling / wheat / egg / building / place_*
let collectedPages = [];          // 已收集书页索引数组
let submittedPages = [];          // 已提交书页索引数组
let guarantees = {};              // 保底/首次触发标记
```

### 3.4 单元格数据结构

```javascript
{
  stone: true,          // 是否有石头
  ground: 'stone',      // 地面类型：stone / normal / water
  hidden: null,         // 石头下的隐藏内容
  entity: null,         // 生物：{ type: 'chicken'|'cow'|'wolf', alive: true }
  plant: null,          // 植物：fruit / veg / sapling / tree / bush / wheat
  structure: null,      // 结构：toolbox / forge / treasure_chest / storage_chest / bag / golden / silver_box / crystal_ball / campfire / shelter
  mature: 0,            // 成熟度计数器
  treeHits: 0,          // 树木成长/砍伐计数 (0-3)
  wheatHits: 0,         // 小麦成长计数 (0-3)
  hadTree: false,       // 是否曾种过树
  incubatingEgg: 0,     // 鸡蛋孵化倒计时（0=未孵化）
  groundLoot: null,     // 地面掉落物：{ id, count }
  lit: false,           // 是否被照亮
  spawn: false          // 是否为起点
}
```

## 4. 核心函数架构

### 4.1 游戏初始化

```
initGrid()              ← 创建 11×11 全石头地图，中心格清空并放工具箱
    ↓
addLog()                ← 输出初始提示
    ↓
render()                ← 首次渲染
```

### 4.2 核心游戏循环（事件驱动）

```
用户操作（点击/键盘）
    ↓
breakStone() / move() / interactCell()
    ↓
  更新状态（体力、经验、计数、地图内容、生物行为、植物成长等）
    ↓
render()                ← 重绘整个 UI
```

游戏是纯事件驱动的，**不存在游戏主循环（Game Loop）**。所有状态变更后都会调用 `render()` 进行全量重绘。

### 4.3 交互分发（interactCell）

`interactCell(x, y)` 是核心交互函数，按优先级处理各种交互：

1. 石头 → `breakStone()`
2. 地面掉落物 → 拾取
3. 放置模式 → 栽种/建造/放置
4. 孵蛋中的鸡蛋 → 收回
5. 可采集植物 → 采集
6. 结构 → 开启宝箱/商店/水晶球/庇护所
7. 生物 → 击杀/互动
8. 未处理 → 无操作

### 4.4 隐藏内容生成（rollReveal + applyReveal）

凿石时触发随机内容生成，流程：

```
breakStone()
    ↓
rollReveal(cell)        ← 按权重随机选择隐藏内容类型
    ↓
applyReveal(x, y, hidden)  ← 根据类型修改格状态 + 输出日志
```

特殊覆盖逻辑（在 applyReveal 之前执行）：
- 前 10 次保底（水池、灌木、矿物）
- 40 次后金色盒子（12%）
- 70 次真实凿石后水晶球（2%，100 次后递增，121 次或最后一石保底）
- 书页进度追赶

### 4.5 渲染（render）

`render()` 是 UI 全量重绘函数：

```
render()
  ├── 设置 body.night-mode 类
  ├── 清空网格容器，逐个创建 cell div
  │   ├── 设置可见性（夜晚/照亮）
  │   ├── 设置地面样式
  │   ├── 标记玩家位置
  │   ├── 标记可凿石/可放置
  │   ├── 标记特殊结构样式
  │   ├── 设置 emoji 内容
  │   └── 绑定 onclick
  ├── 更新状态栏 HTML
  └── 调用 renderInv() + renderChest() + updateCraft()
```

### 4.6 合成系统

合成系统有三个模式，由 `getCraftMode()` 根据当前条件自动判断：

| 模式 | 触发条件 | 配方来源 |
|------|---------|---------|
| make（制造） | 靠近工具箱 | `data/recipes.js` 中 `station: 'toolbox'` 的配方 |
| forge（铸造） | 靠近铸造台 | `data/recipes.js` 中 `station: 'forge'` 的配方 |
| cook（烹饪） | 靠近篝火 + 有铁锅 / 站在铁板上 / 靠近烤箱 | `data/recipes.js` 中 `station: 'campfire'`、`'iron_plate'`、`'oven'` 的配方 |

配方统一在 `MINIPLAIN_RECIPES` 表里维护，结构是“平台 + 原料列表 + 产物 + 数量”。运行时会按 `station` 建索引，配方匹配函数 `recipeKey(a, b)` 将材料 ID 按字母序排序后拼接成 `"iron+stone"` 格式的 key；单材料配方只保留一个材料 ID。

### 4.7 昼夜系统

昼夜由 `player.breaks`（累计凿石次数）驱动：

```javascript
function isNight() {
  return player.breaks >= 20 && (player.breaks % 20) < 5;
}
```

- 前 20 次凿石永远是白天。
- 之后每 20 次为一个周期，前 5 次为夜晚。
- 夜晚视野仅限玩家 4 邻格 + 篝火半径 3 格 + 水晶球及其 4 邻格。

## 5. 事件绑定结构

游戏交互通过三种方式绑定：

### 5.1 网格点击

在 `render()` 中为每个 `.cell` 元素绑定 `onclick`：

```javascript
el.onclick = () => {
  if (放置模式) → tryPlaceStructure()
  else if (放置模式 + 非石头) → interactCell()
  else if (可凿石) → breakStone()
  else if (相邻非石头) → interactCell()
  else → move()
};
```

### 5.2 键盘事件

```javascript
document.addEventListener('keydown', e => {
  // WASD / 方向键 → move(dx, dy)
});
```

### 5.3 拖拽事件

使用 HTML5 Drag & Drop API 管理背包、箱子、合成格之间的物品转移。

关键机制：
- 拖拽数据类型为 `text/plain`，自定义格式 `mp:inv/chest/craft:index:id`
- 使用 `mpDrag` 变量在 `dragstart` 时保存拖拽源信息
- `readDragData()` 解析拖拽数据
- 合成格支持拖拽放入和拖动交换

## 6. 弹窗系统

使用通用弹窗模式：一个半透明遮罩（`.modal-bg`）包含一个内容面板（`.modal`）。

```
<div class="modal-bg" id="modal">
  <div class="modal">
    <h3 id="modal-title">标题</h3>
    <div id="modal-body">动态内容</div>
    <div id="modal-footer">动态按钮</div>
  </div>
</div>
```

弹窗通过 CSS 类 `.show` 控制显隐。各弹窗内容由对应函数动态生成：

- `openCrystalBallUI()` — 水晶球提交书页
- `openGoldenMerchant()` — 金色盒子商店
- `openSilverMerchant()` — 银色盒子料理商店
- `showModal()` — 通用信息弹窗（书页阅读等）
- 通关弹窗（`#victory-modal`）为独立模态框

## 7. 状态流转关键路径

### 7.1 凿石

```
breakStone(x, y)
  ├── 检查条件（相邻、有普通地面、体力≥1）
  ├── 扣体力、加凿石次数
  ├── 清除石头、设地面为 normal
  ├── +1 经验
  ├── randomMineral() → 获得矿物
  ├── rollReveal() + applyReveal() → 生成隐藏内容
  ├── applyPageGuarantee() → 书页保底
  ├── onBreakEffects() → 动物产蛋/产奶、昼夜提示
  ├── tickEggIncubation() → 推进孵化
  ├── checkLevel() → 检查升级
  ├── tickPlants() → 推进植物成长
  └── render() → 刷新 UI
```

### 7.2 移动

```
move(dx, dy)
  ├── 检查边界和可通行
  ├── 更新玩家坐标
  ├── moveAnimals() → 推动附近动物随机移动
  └── render()
```

### 7.3 合成

```
doCraft()
  ├── 读取当前合成模式（make/forge/cook）
  ├── 匹配配方
  ├── 清空材料格
  ├── 生成成品入背包（或退回材料）
  └── updateCraft() + renderInv()
```

## 8. 数据结构关系图

```
ITEMS 表                    grid[][]                   inventory[]
[id] → {name,emoji,vol,use,place}    [y][x] → cell对象          [{id,count}, ...]
         ↑                                ↑                            ↑
    显示/规则参考                      地图状态                     背包状态
         ↓                                ↓                            ↓
   合成配方引用                      玩家坐标指引                   操作交互源
         ↓                                ↓
   使用效果函数                    render() 读取

chestStorages                     craftSlots                    collectedPages
{"x,y": [{id,count},...]}         [itemId, itemId]              [pageIndex, ...]
    ↑                                  ↑                             ↑
 箱子内容                           合成材料                     书页收藏

player → {x, y, stamina, exp, level, breaks}  ← 核心状态驱动多数逻辑
```

## 9. 设计特点分析

### 优点
- **零外部依赖**：无需引入任何框架或库，纯浏览器原生 API
- **单文件部署**：复制即可运行，适合快速原型和分享
- **响应式布局**：CSS Grid 断点适配移动端和桌面端
- **状态集中管理**：所有状态在 IIFE 顶层定义，流转路径清晰
- **全量渲染模式**：`render()` 全量刷新避免状态同步 Bug，适合小型游戏

### 可改进之处
- **渲染性能**：每次操作都重新创建整个网格 DOM，大规模场景下可能有性能问题
- **代码组织**：无模块化，所有函数在 IIFE 内平铺，函数间依赖由调用顺序隐式保证
- **状态持久化**：未实现存档/读档功能
- **移动端支持**：虽然响应式布局已有，但交互方式（拖拽、长按）在移动端仍需优化
- **无障碍访问**：缺乏 ARIA 属性、键盘导航和屏幕阅读器支持
- **抽取 Godot 版本**：当前文档目录中的游戏玩法文档主要用于指导 Godot 版本开发

## 10. 构建与运行

- 无需构建步骤，直接打开 `index.html`，再从简介页进入 `Stonia.html` 即可运行。
- 本项目根目录为 Godot 项目（`Stonia`），`Stonia.html` 为快速原型/Demo 版本。
- Godot 版本计划在 `Stonia-Game-Docs/` 中的玩法文档和美术需求文档中有详细设计参考。
