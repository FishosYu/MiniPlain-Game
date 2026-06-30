const fs = require('fs');
const path = require('path');
const vm = require('vm');
const zlib = require('zlib');

const ROOT = path.resolve(__dirname, '..');
const ITEMS_FILE = path.join(ROOT, 'data', 'items.js');
const ITEM_OUT_DIR = path.join(ROOT, 'assets', '2D', 'items');
const ENTITY_OUT_DIR = path.join(ROOT, 'assets', '2D', 'entities');
const SIZE = 32;

const palette = {
  line: '#2f2b26',
  lineSoft: '#4a4036',
  shadow: '#00000055',
  paper: '#fff4d8',
  paperLight: '#fff9e9',
  brown: '#6f4a34',
  brownDark: '#3f281d',
  brownLight: '#b9793d',
  wood: '#8c5a2f',
  woodLight: '#c58a45',
  stone: '#b8b6aa',
  stoneDark: '#6f6f72',
  stoneLight: '#e4dfcf',
  iron: '#858b91',
  ironDark: '#4d5358',
  ironLight: '#d4d9d9',
  silver: '#ccd3d6',
  silverDark: '#7b858b',
  gold: '#f0b834',
  goldDark: '#a46323',
  green: '#6ea64d',
  greenDark: '#3f6d36',
  greenLight: '#b8d84c',
  orange: '#e9812b',
  orangeDark: '#99451f',
  red: '#d65f43',
  redDark: '#8e3528',
  yellow: '#ffd46b',
  cream: '#f3d69b',
  water: '#4da0cf',
  waterLight: '#a6d8e8',
  purple: '#8a58c4',
};

function loadItems() {
  const context = { window: {} };
  vm.runInNewContext(fs.readFileSync(ITEMS_FILE, 'utf8'), context, { filename: ITEMS_FILE });
  return context.window.MINIPLAIN_ITEMS || {};
}

function hexToRgba(value) {
  if (value.startsWith('#')) value = value.slice(1);
  let alpha = 255;
  if (value.length === 8) {
    alpha = parseInt(value.slice(6, 8), 16);
    value = value.slice(0, 6);
  }
  return [
    parseInt(value.slice(0, 2), 16),
    parseInt(value.slice(2, 4), 16),
    parseInt(value.slice(4, 6), 16),
    alpha,
  ];
}

function canvas() {
  return {
    data: new Uint8Array(SIZE * SIZE * 4),
    set(x, y, color) {
      x = Math.round(x);
      y = Math.round(y);
      if (x < 0 || y < 0 || x >= SIZE || y >= SIZE) return;
      const [r, g, b, a] = hexToRgba(color);
      const i = (y * SIZE + x) * 4;
      this.data[i] = r;
      this.data[i + 1] = g;
      this.data[i + 2] = b;
      this.data[i + 3] = a;
    },
    rect(x, y, w, h, color) {
      for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) this.set(xx, yy, color);
    },
    strokeRect(x, y, w, h, color) {
      this.rect(x, y, w, 1, color);
      this.rect(x, y + h - 1, w, 1, color);
      this.rect(x, y, 1, h, color);
      this.rect(x + w - 1, y, 1, h, color);
    },
    framedRect(x, y, w, h, fill, outline = palette.line) {
      this.rect(x, y, w, h, outline);
      this.rect(x + 2, y + 2, w - 4, h - 4, fill);
    },
    ellipse(cx, cy, rx, ry, color) {
      for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) {
        for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
          if (((x - cx) ** 2) / (rx ** 2) + ((y - cy) ** 2) / (ry ** 2) <= 1) this.set(x, y, color);
        }
      }
    },
    line(x0, y0, x1, y1, color) {
      x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
      const dx = Math.abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
      const dy = -Math.abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
      let err = dx + dy;
      let guard = SIZE * SIZE;
      while (true) {
        this.set(x0, y0, color);
        if (x0 === x1 && y0 === y1) break;
        if (--guard <= 0) throw new Error(`line draw exceeded guard: ${x0},${y0} -> ${x1},${y1}`);
        const e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
      }
    },
  };
}

function crc32(buf) {
  let crc = ~0;
  for (const byte of buf) {
    crc ^= byte;
    for (let i = 0; i < 8; i++) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }
  return ~crc >>> 0;
}

function chunk(type, data) {
  const name = Buffer.from(type);
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([name, data])));
  return Buffer.concat([len, name, data, crc]);
}

function pngBuffer(c) {
  const raw = Buffer.alloc((SIZE * 4 + 1) * SIZE);
  for (let y = 0; y < SIZE; y++) {
    const row = y * (SIZE * 4 + 1);
    raw[row] = 0;
    Buffer.from(c.data.slice(y * SIZE * 4, (y + 1) * SIZE * 4)).copy(raw, row + 1);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(SIZE, 0);
  ihdr.writeUInt32BE(SIZE, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function shadow(c) {
  c.ellipse(16, 25, 10, 3, palette.shadow);
}

function shine(c, x, y) {
  c.rect(x, y, 4, 2, '#ffffffaa');
  c.rect(x + 1, y + 2, 2, 2, '#ffffff88');
}

function drawRock(c, base = palette.stone, dark = palette.stoneDark, light = palette.stoneLight) {
  shadow(c);
  c.framedRect(6, 8, 20, 16, base);
  c.rect(8, 10, 5, 4, light);
  c.rect(17, 10, 6, 3, '#8f8f8f');
  c.rect(11, 18, 8, 3, '#9d9a91');
  c.rect(7, 22, 18, 2, dark);
  c.rect(10, 24, 2, 3, palette.lineSoft);
  c.rect(20, 24, 2, 3, palette.lineSoft);
}

function drawOre(c, base, dark, light) {
  shadow(c);
  c.framedRect(8, 10, 16, 12, base);
  c.rect(10, 12, 5, 3, light);
  c.rect(18, 15, 4, 4, '#ffffff66');
  c.rect(9, 20, 14, 2, dark);
}

function drawLog(c) {
  shadow(c);
  c.rect(6, 14, 20, 11, palette.line);
  c.rect(8, 16, 16, 7, palette.wood);
  c.rect(8, 16, 4, 7, palette.cream);
  c.strokeRect(8, 16, 16, 7, palette.brownDark);
  c.rect(14, 17, 8, 2, palette.woodLight);
  c.line(13, 21, 23, 21, palette.brownDark);
}

function drawFlint(c) {
  shadow(c);
  drawRock(c, '#4e5359', '#25282b', '#9fa4a9');
  c.rect(20, 6, 2, 7, palette.yellow);
  c.rect(17, 9, 8, 2, palette.yellow);
  c.rect(20, 8, 2, 3, '#fff2a4');
}

function drawFruit(c) {
  shadow(c);
  c.ellipse(15, 17, 8, 8, palette.redDark);
  c.ellipse(16, 16, 7, 8, palette.red);
  c.rect(12, 11, 4, 3, '#ff9072');
  c.rect(16, 7, 3, 5, palette.brownDark);
  c.rect(19, 8, 5, 3, palette.green);
}

function drawVeg(c, cooked = false) {
  shadow(c);
  const base = cooked ? '#6f8f42' : palette.green;
  c.ellipse(12, 15, 5, 7, palette.greenDark);
  c.ellipse(20, 14, 5, 7, base);
  c.ellipse(16, 12, 5, 6, palette.greenLight);
  c.rect(11, 19, 4, 7, palette.paperLight);
  c.rect(16, 18, 4, 8, '#e8f0c9');
  c.rect(20, 19, 3, 6, '#d8e6b7');
  c.line(13, 20, 10, 14, palette.greenDark);
  c.line(18, 20, 22, 13, palette.greenDark);
  c.line(16, 18, 16, 11, palette.greenDark);
}

function drawPotato(c, roasted = false) {
  shadow(c);
  c.ellipse(16, 17, 9, 7, palette.brownDark);
  c.ellipse(16, 16, 8, 6, roasted ? '#9c5c2c' : '#b98248');
  c.rect(11, 14, 2, 2, '#6f4a34');
  c.rect(18, 18, 2, 2, '#6f4a34');
  if (roasted) c.rect(12, 12, 8, 2, '#d09a58');
}

function drawCarrot(c, roasted = false) {
  shadow(c);
  c.rect(13, 12, 9, 12, palette.line);
  c.rect(14, 13, 7, 9, roasted ? '#c96928' : palette.orange);
  c.rect(16, 22, 3, 3, palette.line);
  c.rect(11, 6, 4, 7, palette.greenDark);
  c.rect(16, 5, 4, 8, palette.green);
  c.rect(20, 7, 4, 6, palette.greenLight);
  c.rect(15, 16, 5, 1, palette.yellow);
}

function drawSapling(c) {
  shadow(c);
  c.rect(15, 13, 3, 12, palette.greenDark);
  c.ellipse(12, 14, 6, 4, palette.green);
  c.ellipse(20, 12, 5, 4, palette.greenLight);
  c.rect(10, 24, 13, 2, palette.brown);
}

function drawWheat(c, seed = false) {
  shadow(c);
  if (seed) {
    c.line(16, 14, 16, 25, palette.brown);
    for (let i = 0; i < 3; i++) {
      const y = 15 + i * 3;
      c.rect(13, y, 3, 2, palette.gold);
      c.rect(17, y + 1, 3, 2, palette.yellow);
    }
    return;
  }
  c.line(16, 10, 16, 25, palette.brown);
  c.line(12, 12, 15, 25, palette.brown);
  c.line(20, 12, 17, 25, palette.brown);
  const grains = [
    [15, 8, palette.yellow], [12, 10, palette.gold], [18, 10, palette.yellow],
    [11, 13, palette.gold], [19, 13, palette.yellow], [12, 16, palette.gold],
    [18, 16, palette.yellow], [14, 11, palette.gold], [17, 12, palette.yellow],
  ];
  for (const [x, y, color] of grains) {
    c.ellipse(x, y, 2, 3, palette.goldDark);
    c.ellipse(x, y - 1, 1, 2, color);
  }
}

function drawFish(c, grilled = false) {
  shadow(c);
  const body = grilled ? '#d97837' : palette.water;
  c.ellipse(15, 16, 9, 5, palette.line);
  c.ellipse(15, 15, 8, 4, body);
  c.rect(23, 13, 4, 3, palette.line);
  c.rect(23, 16, 4, 3, palette.line);
  c.rect(22, 14, 3, 4, body);
  c.set(11, 14, palette.paperLight);
  if (grilled) {
    c.line(11, 13, 20, 20, palette.brownDark);
    c.line(13, 12, 22, 19, palette.brownDark);
  }
}

function drawFisherFish(c) {
  shadow(c);
  const outline = palette.brownDark;
  const head = '#f3bd8c';
  const headLight = '#ffe2bd';
  const body = '#e85f45';
  const bodyLight = '#ff7c55';
  const bodyDark = '#a85b45';
  const tail = '#35534b';

  c.ellipse(14, 16, 11, 7, outline);
  c.ellipse(11, 15, 7, 6, head);
  c.rect(8, 12, 5, 3, headLight);
  c.rect(11, 10, 8, 2, headLight);
  c.rect(15, 12, 5, 11, body);
  c.rect(17, 12, 6, 9, bodyLight);
  c.rect(14, 20, 10, 3, bodyDark);
  c.line(15, 21, 22, 14, bodyDark);
  c.rect(24, 14, 5, 4, outline);
  c.rect(24, 18, 5, 5, outline);
  c.rect(23, 15, 4, 4, tail);
  c.rect(24, 20, 3, 3, tail);
  c.rect(25, 16, 3, 1, '#496b62');
  c.set(11, 15, palette.brownDark);
}

function drawEgg(c, fried = false) {
  shadow(c);
  if (fried) {
    c.ellipse(13, 17, 7, 5, palette.line);
    c.ellipse(19, 17, 7, 5, palette.line);
    c.ellipse(16, 15, 9, 6, palette.line);
    c.ellipse(13, 17, 6, 4, palette.paperLight);
    c.ellipse(19, 17, 6, 4, palette.paperLight);
    c.ellipse(16, 15, 8, 5, '#fffdf2');
    c.ellipse(16, 16, 4, 4, palette.gold);
    c.ellipse(15, 15, 2, 2, palette.yellow);
  } else {
    c.ellipse(16, 17, 7, 9, palette.line);
    c.ellipse(16, 16, 6, 8, palette.paperLight);
    shine(c, 13, 11);
  }
}

function drawSteak(c) {
  shadow(c);
  c.ellipse(16, 17, 10, 7, palette.line);
  c.ellipse(13, 16, 5, 6, palette.line);
  c.ellipse(17, 16, 8, 6, '#8f3d2d');
  c.ellipse(13, 16, 4, 5, '#a94d34');
  c.rect(12, 13, 8, 2, '#d08a63');
  c.rect(20, 16, 4, 3, '#f0c49b');
  c.line(10, 18, 20, 13, palette.brownDark);
  c.line(12, 21, 24, 15, palette.brownDark);
  c.rect(14, 15, 3, 2, '#c76946');
}

function drawMeat(c, kind = 'chicken', cooked = false) {
  shadow(c);
  if (kind === 'chicken') {
    c.rect(9, 18, 12, 8, palette.line);
    c.ellipse(15, 17, 8, 6, palette.line);
    c.ellipse(15, 16, 7, 5, cooked ? '#b85b2d' : '#d98a6a');
    c.rect(20, 20, 6, 3, palette.cream);
    c.rect(24, 18, 3, 3, palette.paperLight);
    c.rect(24, 22, 3, 3, palette.paperLight);
  } else {
    c.ellipse(16, 16, 10, 7, palette.line);
    c.ellipse(16, 15, 9, 6, cooked ? '#88452c' : '#c96358');
    c.rect(13, 13, 6, 3, '#ffd0c7');
    if (cooked) {
      c.line(10, 14, 22, 19, palette.brownDark);
      c.line(12, 11, 24, 17, palette.brownDark);
    }
  }
}

function drawMilk(c) {
  shadow(c);
  c.framedRect(11, 9, 10, 17, '#d6f3f5');
  c.rect(13, 6, 6, 5, palette.line);
  c.rect(14, 7, 4, 3, palette.paperLight);
  c.rect(13, 14, 6, 7, '#ffffff');
  shine(c, 13, 11);
}

function drawWolfFur(c) {
  shadow(c);
  c.rect(8, 11, 17, 12, palette.line);
  c.rect(10, 12, 13, 10, '#6f6a66');
  c.rect(6, 16, 5, 5, palette.line);
  c.rect(22, 16, 5, 5, palette.line);
  c.rect(12, 14, 4, 3, '#9c9994');
}

function drawTool(c, id) {
  shadow(c);
  if (id === 'rod') {
    c.line(9, 25, 23, 7, palette.brownDark);
    c.line(10, 25, 24, 7, palette.woodLight);
    c.line(23, 7, 24, 19, palette.line);
    c.set(24, 20, palette.water);
    return;
  }
  if (id === 'stone_axe') {
    c.line(10, 27, 19, 12, palette.brownDark);
    c.line(11, 27, 20, 12, palette.woodLight);
    c.line(12, 25, 21, 12, palette.brownDark);
    c.ellipse(16, 10, 9, 6, palette.line);
    c.rect(18, 7, 7, 8, palette.line);
    c.ellipse(15, 10, 7, 4, palette.stone);
    c.rect(18, 8, 5, 6, palette.stone);
    c.rect(19, 8, 4, 1, palette.stoneLight);
    c.rect(10, 9, 4, 2, palette.stoneLight);
    c.rect(10, 13, 7, 2, palette.stoneDark);
    c.rect(18, 11, 4, 3, palette.brownDark);
    c.set(8, 10, palette.stoneLight);
    c.set(24, 11, palette.stoneLight);
    return;
  }
  if (id === 'iron_sword') {
    c.rect(15, 6, 3, 17, palette.line);
    c.rect(16, 7, 1, 15, palette.ironLight);
    c.rect(11, 22, 11, 3, palette.goldDark);
    c.rect(15, 24, 3, 5, palette.brownDark);
    return;
  }
  if (id === 'hammer') {
    c.line(9, 27, 18, 14, palette.brownDark);
    c.line(10, 27, 19, 14, palette.woodLight);
    c.line(11, 25, 20, 14, palette.brownDark);
    c.rect(12, 7, 14, 3, palette.line);
    c.rect(10, 10, 18, 6, palette.line);
    c.rect(13, 16, 11, 2, palette.line);
    c.rect(13, 8, 12, 1, palette.ironLight);
    c.rect(11, 11, 16, 4, palette.iron);
    c.rect(14, 15, 9, 1, palette.ironDark);
    c.rect(23, 11, 4, 2, palette.ironLight);
    c.rect(10, 12, 3, 2, palette.ironDark);
  }
}

function drawPot(c, bucket = false) {
  shadow(c);
  if (bucket) {
    c.framedRect(10, 13, 13, 12, palette.iron);
    c.rect(12, 15, 9, 3, palette.ironLight);
    c.line(10, 13, 16, 8, palette.line);
    c.line(22, 13, 16, 8, palette.line);
    return;
  }
  c.ellipse(16, 13, 9, 4, palette.line);
  c.framedRect(8, 13, 17, 11, palette.ironDark);
  c.rect(11, 15, 11, 4, palette.iron);
  c.rect(6, 15, 3, 4, palette.line);
  c.rect(24, 15, 3, 4, palette.line);
}

function drawFacility(c, id) {
  shadow(c);
  if (id === 'toolbox') {
    c.rect(8, 12, 16, 2, palette.line);
    c.rect(6, 14, 20, 9, palette.line);
    c.rect(8, 23, 16, 3, palette.line);
    c.rect(8, 13, 16, 1, '#c16a3f');
    c.rect(8, 15, 16, 7, '#9d4f32');
    c.rect(10, 22, 12, 2, '#7b3d2a');
    c.rect(11, 9, 10, 5, palette.line);
    c.rect(13, 10, 6, 3, palette.brownLight);
    c.line(11, 21, 21, 13, palette.line);
    c.line(12, 21, 22, 13, palette.ironLight);
    c.ellipse(22, 12, 3, 3, palette.line);
    c.rect(22, 10, 3, 3, '#00000000');
    c.set(22, 12, palette.ironLight);
    c.set(23, 13, palette.ironLight);
    c.ellipse(11, 22, 2, 2, palette.line);
    c.set(11, 22, palette.ironLight);
    c.rect(15, 17, 4, 3, palette.gold);
    return;
  }
  if (id === 'forge') {
    c.framedRect(7, 10, 18, 15, palette.stoneDark);
    c.rect(10, 13, 12, 7, palette.line);
    c.rect(12, 14, 8, 5, '#e85b2f');
    c.rect(14, 12, 4, 7, palette.yellow);
    return;
  }
  if (id === 'chest') {
    c.framedRect(7, 11, 18, 13, palette.wood);
    c.rect(8, 11, 16, 4, palette.woodLight);
    c.rect(15, 15, 3, 5, palette.gold);
    c.strokeRect(7, 11, 18, 13, palette.line);
    return;
  }
  if (id === 'campfire') {
    c.rect(8, 22, 17, 4, palette.line);
    c.line(10, 23, 22, 16, palette.wood);
    c.line(22, 23, 10, 16, palette.wood);
    c.ellipse(16, 16, 7, 8, palette.redDark);
    c.ellipse(16, 15, 5, 7, palette.orange);
    c.ellipse(16, 15, 3, 5, palette.yellow);
    return;
  }
  if (id === 'oven') {
    c.framedRect(7, 8, 18, 18, palette.ironDark);
    c.rect(10, 13, 12, 8, palette.line);
    c.rect(12, 15, 8, 5, '#ff9b3d');
    c.rect(10, 9, 12, 3, palette.ironLight);
    return;
  }
  if (id === 'iron_plate') {
    c.framedRect(7, 14, 18, 9, palette.ironDark);
    c.rect(10, 16, 12, 2, palette.ironLight);
    return;
  }
  if (id === 'building') {
    c.rect(7, 12, 18, 13, palette.line);
    c.rect(9, 14, 7, 4, '#b66a40');
    c.rect(17, 14, 6, 4, '#c98a51');
    c.rect(9, 19, 6, 4, '#c98a51');
    c.rect(16, 19, 7, 4, '#b66a40');
  }
}

function drawCoin(c, silver = false) {
  shadow(c);
  const base = silver ? palette.silver : palette.gold;
  const dark = silver ? palette.silverDark : palette.goldDark;
  c.ellipse(16, 16, 8, 8, palette.line);
  c.ellipse(16, 15, 7, 7, base);
  c.ellipse(16, 15, 4, 4, '#ffffff55');
  c.rect(13, 21, 7, 2, dark);
}

function drawPage(c) {
  shadow(c);
  c.framedRect(10, 7, 13, 18, palette.paperLight);
  c.rect(20, 7, 3, 5, '#d8c896');
  c.line(13, 13, 20, 13, palette.brown);
  c.line(13, 17, 20, 17, palette.brown);
  c.line(13, 21, 18, 21, palette.brown);
}

function drawSheet(c, fill, dark) {
  shadow(c);
  c.rect(8, 12, 17, 12, palette.line);
  c.rect(10, 13, 13, 9, fill);
  c.rect(11, 14, 8, 2, '#ffffff88');
  c.rect(9, 22, 15, 2, dark);
}

function drawBattery(c) {
  shadow(c);
  drawFruit(c);
  c.rect(20, 10, 4, 12, palette.line);
  c.rect(21, 11, 2, 10, palette.ironLight);
  c.rect(22, 8, 2, 3, palette.line);
  c.line(11, 12, 22, 11, palette.gold);
}

function drawWater(c) {
  shadow(c);
  c.ellipse(16, 17, 8, 10, palette.line);
  c.ellipse(16, 17, 7, 9, palette.water);
  c.rect(12, 12, 7, 3, palette.waterLight);
  c.rect(14, 20, 6, 2, '#2f79ad');
}

function drawLiveChicken(c) {
  shadow(c);
  c.ellipse(15, 18, 9, 7, palette.line);
  c.ellipse(15, 17, 8, 6, '#f3e7cf');
  c.ellipse(22, 13, 5, 5, palette.line);
  c.ellipse(22, 12, 4, 4, palette.paperLight);
  c.rect(25, 12, 4, 2, palette.orange);
  c.rect(20, 7, 2, 4, palette.red);
  c.rect(23, 8, 2, 3, palette.red);
  c.rect(12, 22, 2, 5, palette.orangeDark);
  c.rect(18, 22, 2, 5, palette.orangeDark);
  c.rect(10, 26, 5, 1, palette.orangeDark);
  c.rect(16, 26, 5, 1, palette.orangeDark);
  c.set(23, 12, palette.line);
}

function drawCow(c) {
  shadow(c);
  c.ellipse(15, 18, 11, 7, palette.line);
  c.ellipse(15, 17, 10, 6, '#f5ead8');
  c.rect(10, 15, 5, 4, '#5b4a3f');
  c.rect(18, 17, 5, 3, '#5b4a3f');
  c.ellipse(24, 13, 6, 5, palette.line);
  c.ellipse(24, 12, 5, 4, '#f5ead8');
  c.rect(20, 8, 3, 3, palette.cream);
  c.rect(26, 8, 3, 3, palette.cream);
  c.rect(22, 14, 6, 3, '#d99b8a');
  c.set(23, 12, palette.line);
  c.set(27, 12, palette.line);
  c.rect(9, 23, 2, 5, palette.brownDark);
  c.rect(19, 23, 2, 5, palette.brownDark);
}

function drawWolf(c) {
  shadow(c);
  c.ellipse(14, 18, 10, 6, palette.line);
  c.ellipse(14, 17, 9, 5, '#6f6a66');
  c.line(5, 16, 2, 11, palette.line);
  c.line(6, 16, 3, 12, '#6f6a66');
  c.ellipse(23, 13, 6, 5, palette.line);
  c.ellipse(23, 12, 5, 4, '#77736e');
  c.rect(20, 7, 3, 5, palette.line);
  c.rect(26, 8, 3, 4, palette.line);
  c.rect(26, 13, 5, 3, palette.line);
  c.rect(26, 13, 4, 2, '#9c9994');
  c.set(23, 12, palette.paperLight);
  c.rect(10, 23, 2, 5, palette.line);
  c.rect(19, 22, 2, 6, palette.line);
}

function drawLiangtianDog(c) {
  shadow(c);
  const fur = '#f6f0df';
  const furLight = '#fffdf2';
  const furDark = '#d7c8ad';
  const outline = palette.brownDark;

  c.ellipse(14, 19, 9, 6, outline);
  c.ellipse(14, 18, 8, 5, fur);
  c.ellipse(10, 17, 4, 4, outline);
  c.ellipse(10, 17, 3, 3, furLight);
  c.ellipse(17, 16, 6, 4, furLight);
  c.rect(9, 22, 3, 5, outline);
  c.rect(10, 22, 2, 4, fur);
  c.rect(17, 22, 3, 5, outline);
  c.rect(18, 22, 2, 4, fur);

  c.ellipse(23, 13, 7, 6, outline);
  c.ellipse(23, 12, 6, 5, furLight);
  c.ellipse(19, 14, 4, 6, outline);
  c.ellipse(19, 14, 3, 5, furDark);
  c.ellipse(27, 15, 3, 5, outline);
  c.ellipse(27, 15, 2, 4, furDark);
  c.ellipse(24, 15, 4, 3, fur);
  c.rect(22, 12, 1, 1, palette.line);
  c.rect(26, 12, 1, 1, palette.line);
  c.rect(24, 15, 2, 2, palette.line);
  c.line(24, 17, 23, 18, outline);
  c.line(25, 17, 26, 18, outline);
  c.rect(21, 9, 4, 2, furLight);
  c.rect(17, 11, 4, 2, '#eee0c6');

  c.ellipse(6, 13, 5, 5, outline);
  c.ellipse(7, 13, 4, 4, fur);
  c.ellipse(8, 14, 2, 2, '#00000000');
  c.rect(7, 17, 5, 3, outline);
  c.rect(8, 17, 4, 2, fur);
}

function drawTree(c) {
  shadow(c);
  c.rect(13, 15, 7, 12, palette.brownDark);
  c.rect(15, 15, 4, 12, palette.wood);
  c.ellipse(16, 11, 10, 7, palette.greenDark);
  c.ellipse(11, 16, 8, 6, palette.green);
  c.ellipse(21, 16, 8, 6, palette.green);
  c.ellipse(16, 15, 9, 7, palette.greenLight);
  c.rect(9, 17, 5, 3, palette.greenDark);
  c.rect(19, 12, 5, 2, '#d1e779');
}

function drawBush(c) {
  shadow(c);
  c.ellipse(10, 19, 7, 6, palette.greenDark);
  c.ellipse(17, 17, 9, 8, palette.green);
  c.ellipse(23, 20, 6, 5, palette.greenDark);
  c.ellipse(14, 15, 5, 4, palette.greenLight);
  c.rect(9, 22, 16, 3, palette.greenDark);
}

function drawPlayer(c) {
  const skin = '#f2c7aa';
  const blush = '#e99595';
  shadow(c);
  c.ellipse(16, 10, 5, 5, palette.line);
  c.ellipse(16, 9, 4, 4, skin);
  c.set(14, 9, palette.line);
  c.set(18, 9, palette.line);
  c.set(13, 11, blush);
  c.set(19, 11, blush);
  c.rect(12, 14, 9, 9, palette.line);
  c.rect(13, 15, 7, 7, '#d65f43');
  c.rect(11, 23, 4, 5, palette.brownDark);
  c.rect(18, 23, 4, 5, palette.brownDark);
  c.rect(10, 16, 3, 7, skin);
  c.rect(20, 16, 3, 7, skin);
  c.rect(13, 6, 7, 2, palette.brownDark);
}

function drawSpawn(c) {
  shadow(c);
  c.rect(10, 7, 3, 20, palette.brownDark);
  c.rect(13, 8, 13, 9, palette.line);
  c.rect(14, 9, 10, 6, palette.red);
  c.rect(14, 15, 7, 2, palette.redDark);
  c.rect(8, 26, 8, 2, palette.brownDark);
}

function drawPaperBag(c) {
  shadow(c);
  c.framedRect(9, 10, 15, 16, '#d9a35d');
  c.rect(12, 8, 9, 5, palette.line);
  c.rect(13, 9, 7, 4, '#f0c06d');
  c.rect(11, 15, 10, 2, '#f0c06d');
  c.rect(13, 20, 5, 2, palette.brown);
}

function drawTreasureChest(c) {
  shadow(c);
  c.framedRect(6, 12, 20, 13, palette.wood);
  c.rect(8, 10, 16, 6, palette.line);
  c.rect(9, 11, 14, 4, palette.woodLight);
  c.rect(15, 15, 3, 6, palette.gold);
  c.rect(8, 19, 16, 2, palette.brownDark);
}

function drawGoldenBox(c) {
  shadow(c);
  c.framedRect(8, 10, 17, 16, palette.gold);
  c.rect(11, 13, 11, 3, palette.yellow);
  c.rect(15, 10, 3, 16, palette.goldDark);
  c.rect(8, 17, 17, 3, palette.goldDark);
  c.rect(25, 6, 2, 6, '#ffffff');
  c.rect(23, 8, 6, 2, '#ffffff');
}

function drawSilverBox(c) {
  shadow(c);
  c.framedRect(8, 10, 17, 16, palette.silver);
  c.rect(11, 13, 11, 3, '#ffffff');
  c.rect(15, 10, 3, 16, palette.silverDark);
  c.rect(8, 17, 17, 3, palette.silverDark);
}

function drawCrystalBall(c) {
  shadow(c);
  c.ellipse(16, 13, 9, 9, palette.line);
  c.ellipse(16, 12, 8, 8, '#9f82dc');
  c.rect(12, 20, 9, 5, palette.line);
  c.rect(13, 21, 7, 3, palette.goldDark);
  c.rect(12, 9, 6, 3, '#ffffff99');
  c.rect(20, 15, 3, 2, '#ffffff66');
}

function drawShelter(c) {
  shadow(c);
  for (let y = 7; y <= 15; y++) {
    const half = y - 7;
    c.rect(16 - half, y, half * 2 + 1, 1, '#9d4f32');
  }
  c.rect(11, 13, 11, 3, '#b65f39');
  c.rect(7, 15, 18, 11, palette.line);
  c.rect(9, 16, 14, 9, palette.wood);
  c.line(6, 15, 16, 7, palette.line);
  c.line(16, 7, 27, 15, palette.line);
  c.line(8, 14, 16, 9, '#cf7d42');
  c.line(16, 9, 25, 14, '#cf7d42');
  c.rect(14, 19, 5, 7, palette.brownDark);
  c.rect(20, 17, 3, 3, palette.paperLight);
}

function drawProcessed(c, id) {
  if (id === 'wood_plank') {
    shadow(c);
    c.framedRect(7, 13, 18, 10, palette.wood);
    c.line(9, 17, 23, 17, palette.brownDark);
    c.rect(10, 14, 10, 2, palette.woodLight);
  } else if (id === 'stone_slab') drawSheet(c, palette.stone, palette.stoneDark);
  else if (id === 'flour') {
    shadow(c);
    c.framedRect(10, 10, 12, 15, palette.paper);
    c.rect(12, 14, 8, 7, '#eee2ca');
    c.rect(13, 11, 6, 2, palette.gold);
  } else if (id === 'dough' || id === 'rich_dough' || id === 'cake_base') {
    shadow(c);
    c.ellipse(16, 17, 9, 6, palette.line);
    c.ellipse(16, 16, 8, 5, id === 'rich_dough' ? '#f1c16d' : '#dfbd82');
    if (id === 'cake_base') c.rect(11, 14, 10, 3, '#f8e1ab');
  } else if (id === 'bridge') {
    shadow(c);
    c.rect(6, 13, 20, 12, palette.line);
    c.rect(8, 15, 16, 8, palette.wood);
    c.line(9, 16, 23, 16, palette.brownDark);
    c.line(9, 20, 23, 20, palette.brownDark);
  } else if (id === 'mill') {
    shadow(c);
    c.framedRect(9, 15, 14, 10, palette.stone);
    c.ellipse(16, 14, 7, 7, palette.line);
    c.ellipse(16, 14, 5, 5, '#aaa59b');
    c.rect(15, 9, 2, 10, palette.stoneLight);
  } else if (id === 'prep_table') {
    shadow(c);
    c.framedRect(7, 12, 18, 9, palette.woodLight);
    c.rect(9, 21, 3, 5, palette.brownDark);
    c.rect(20, 21, 3, 5, palette.brownDark);
    c.rect(12, 10, 9, 2, palette.paperLight);
  }
}

function drawPlate(c) {
  shadow(c);
  c.ellipse(16, 18, 11, 7, palette.line);
  c.ellipse(16, 17, 10, 6, palette.paperLight);
  c.ellipse(16, 17, 6, 3, '#ead8aa');
}

function drawBowl(c, soup = '#a96534') {
  shadow(c);
  c.rect(7, 15, 18, 8, palette.line);
  c.rect(9, 16, 14, 5, palette.redDark);
  c.ellipse(16, 15, 10, 5, palette.line);
  c.ellipse(16, 14, 9, 4, soup);
}

function drawChickenEggBowl(c) {
  drawBowl(c, '#e8b94a');
  c.ellipse(13, 13, 4, 3, palette.paperLight);
  c.ellipse(13, 13, 2, 2, palette.gold);
  c.ellipse(19, 13, 5, 4, palette.line);
  c.ellipse(19, 12, 4, 3, '#b85b2d');
  c.rect(22, 15, 5, 2, palette.cream);
  c.rect(25, 14, 2, 2, palette.paperLight);
  c.rect(25, 17, 2, 2, palette.paperLight);
  c.line(16, 14, 22, 11, palette.brownDark);
}

function addSteam(c) {
  c.line(12, 8, 11, 5, '#ffffff99');
  c.line(16, 8, 17, 5, '#ffffff99');
  c.line(20, 8, 19, 5, '#ffffff99');
}

function drawBurger(c, beef = false) {
  shadow(c);
  c.ellipse(16, 12, 10, 5, palette.line);
  c.ellipse(16, 11, 9, 4, '#d9984e');
  c.rect(7, 15, 18, 3, beef ? '#6f2e25' : '#b45b2d');
  c.rect(8, 18, 16, 3, palette.green);
  c.ellipse(16, 22, 9, 4, palette.line);
  c.ellipse(16, 21, 8, 3, '#d9984e');
  c.set(12, 10, palette.paperLight);
  c.set(17, 9, palette.paperLight);
}

function drawMeal(c, id) {
  addSteam(c);
  if (id === 'grilled_veg') { drawPlate(c); drawVeg(c, true); return; }
  if (id === 'roasted_potato') { drawPlate(c); drawPotato(c, true); return; }
  if (id === 'roasted_carrot') { drawPlate(c); drawCarrot(c, true); return; }
  if (id === 'fried_egg') { drawEgg(c, true); return; }
  if (id === 'cooked_chicken' || id === 'big_plate_chicken') { drawMeat(c, 'chicken', true); return; }
  if (id === 'plain_steak') { drawSteak(c); return; }
  if (id === 'cooked_beef') { drawMeat(c, 'beef', true); return; }
  if (id === 'grilled_fish') { drawFish(c, true); return; }
  if (id === 'stir_fried_wheat') { drawPlate(c); drawWheat(c); return; }
  if (id === 'chicken_egg_bowl') { drawChickenEggBowl(c); return; }
  if (id === 'bread') {
    shadow(c);
    c.ellipse(16, 17, 10, 7, palette.line);
    c.ellipse(16, 16, 9, 6, '#c98342');
    c.rect(10, 13, 4, 2, '#eab56b');
    c.rect(16, 12, 4, 2, '#eab56b');
    return;
  }
  if (id === 'steamed_bun' || id === 'meat_bun') {
    drawPlate(c);
    c.ellipse(13, 16, 5, 5, palette.line);
    c.ellipse(13, 15, 4, 4, '#fff2d1');
    c.ellipse(20, 17, 5, 5, palette.line);
    c.ellipse(20, 16, 4, 4, '#fff2d1');
    if (id === 'meat_bun') c.rect(18, 15, 3, 2, '#8e3528');
    return;
  }
  if (id === 'cake') {
    shadow(c);
    c.framedRect(8, 13, 17, 10, '#f1c16d');
    c.rect(10, 12, 13, 4, palette.paperLight);
    c.rect(13, 9, 2, 4, palette.red);
    c.rect(12, 8, 4, 2, palette.yellow);
    return;
  }
  if (id === 'original_chicken') {
    shadow(c);
    c.ellipse(15, 20, 10, 4, palette.line);
    c.ellipse(15, 19, 9, 3, palette.paperLight);
    c.rect(20, 18, 7, 3, palette.line);
    c.rect(24, 16, 3, 3, palette.paperLight);
    c.rect(24, 21, 3, 3, palette.paperLight);
    c.rect(20, 19, 6, 1, palette.cream);
    c.ellipse(14, 16, 8, 7, palette.line);
    c.ellipse(14, 15, 7, 6, '#b95d2f');
    c.ellipse(10, 19, 5, 5, palette.line);
    c.ellipse(10, 18, 4, 4, '#d27a32');
    c.ellipse(18, 20, 6, 5, palette.line);
    c.ellipse(18, 19, 5, 4, '#c96d2f');
    c.rect(10, 12, 3, 2, '#f0a94a');
    c.rect(16, 13, 4, 2, '#e99a3f');
    c.set(13, 17, palette.yellow);
    c.set(18, 18, palette.yellow);
    c.set(8, 18, '#f0a94a');
    c.line(11, 21, 19, 15, palette.brownDark);
    return;
  }
  if (id === 'chicken_burger') { drawBurger(c, false); return; }
  if (id === 'beef_burger') { drawBurger(c, true); return; }

  const soup = id.includes('egg') ? '#e8b94a' : id.includes('veg') || id.includes('vegetable') ? '#6f8f42' : '#9b5a32';
  drawBowl(c, soup);
  if (id.includes('potato')) c.rect(11, 13, 4, 3, '#d2a45c');
  if (id.includes('carrot')) c.rect(18, 13, 4, 3, palette.orange);
  if (id.includes('chicken')) c.rect(13, 16, 5, 3, '#c56a2f');
  if (id.includes('beef')) c.rect(18, 16, 5, 3, '#713329');
  if (id.includes('fish')) c.rect(13, 13, 7, 2, palette.waterLight);
  if (id.includes('veg') || id.includes('vegetable')) c.rect(10, 14, 4, 3, palette.greenLight);
}

const drawers = {
  stone: c => drawRock(c),
  iron: c => drawOre(c, palette.iron, palette.ironDark, palette.ironLight),
  silver: c => drawOre(c, palette.silver, palette.silverDark, '#ffffff'),
  gold: c => drawOre(c, palette.gold, palette.goldDark, palette.yellow),
  wood: drawLog,
  flint: drawFlint,
  fruit: drawFruit,
  veg: drawVeg,
  potato: drawPotato,
  carrot: drawCarrot,
  sapling: drawSapling,
  wheat_seed: c => drawWheat(c, true),
  wheat: c => drawWheat(c, false),
  fish: drawFish,
  fisher_fish: drawFisherFish,
  egg: drawEgg,
  chicken: c => drawMeat(c, 'chicken', false),
  beef: c => drawMeat(c, 'beef', false),
  milk: drawMilk,
  wolf_fur: drawWolfFur,
  rod: c => drawTool(c, 'rod'),
  stone_axe: c => drawTool(c, 'stone_axe'),
  iron_sword: c => drawTool(c, 'iron_sword'),
  hammer: c => drawTool(c, 'hammer'),
  iron_pot: c => drawPot(c, false),
  iron_bucket: c => drawPot(c, true),
  toolbox: c => drawFacility(c, 'toolbox'),
  forge: c => drawFacility(c, 'forge'),
  chest: c => drawFacility(c, 'chest'),
  campfire: c => drawFacility(c, 'campfire'),
  oven: c => drawFacility(c, 'oven'),
  iron_plate: c => drawFacility(c, 'iron_plate'),
  building: c => drawFacility(c, 'building'),
  coin: c => drawCoin(c, false),
  silver_coin: c => drawCoin(c, true),
  page: drawPage,
  iron_sheet: c => drawSheet(c, palette.iron, palette.ironDark),
  silver_sheet: c => drawSheet(c, palette.silver, palette.silverDark),
  iron_silver_sheet: c => {
    drawSheet(c, palette.silver, palette.silverDark);
    c.rect(10, 17, 13, 4, palette.iron);
  },
  fruit_battery: drawBattery,
  water: drawWater,
};

const entityDrawers = {
  player: drawPlayer,
  spawn: drawSpawn,
  chicken: drawLiveChicken,
  cow: drawCow,
  wolf: drawWolf,
  liangtian_dog: drawLiangtianDog,
  tree: drawTree,
  bush: drawBush,
  treasure_chest: drawTreasureChest,
  bag: drawPaperBag,
  golden: drawGoldenBox,
  silver_box: drawSilverBox,
  crystal_ball: drawCrystalBall,
  shelter: drawShelter,
};

function drawFallback(c) {
  shadow(c);
  c.framedRect(8, 9, 16, 16, palette.paper);
  c.rect(12, 13, 8, 3, palette.gold);
  c.rect(12, 18, 8, 3, palette.brown);
}

function drawIcon(id) {
  const c = canvas();
  if (drawers[id]) drawers[id](c);
  else if (id === 'wood_plank' || id === 'stone_slab' || id === 'flour' || id === 'dough' || id === 'rich_dough' || id === 'cake_base' || id === 'bridge' || id === 'mill' || id === 'prep_table') drawProcessed(c, id);
  else if (id.includes('stew') || id.includes('egg') || id.includes('chicken') || id.includes('beef') || id.includes('potato') || id.includes('carrot') || id.includes('fish') || id.includes('burger') || id.includes('bun') || id === 'bread' || id === 'cake' || id === 'grilled_veg' || id === 'original_chicken' || id === 'stir_fried_wheat' || id === 'plain_steak') drawMeal(c, id);
  else drawFallback(c);
  return c;
}

fs.mkdirSync(ITEM_OUT_DIR, { recursive: true });
const items = loadItems();
const ids = Object.keys(items);
const iconFilter = process.env.ICON_IDS
  ? new Set(process.env.ICON_IDS.split(',').map(id => id.trim()).filter(Boolean))
  : null;
let itemCount = 0;
for (const id of ids) {
  if (iconFilter && !iconFilter.has(id)) continue;
  if (process.env.VERBOSE_ICONS) console.log(`Generating ${id}`);
  fs.writeFileSync(path.join(ITEM_OUT_DIR, `${id}.png`), pngBuffer(drawIcon(id)));
  itemCount++;
}

fs.mkdirSync(ENTITY_OUT_DIR, { recursive: true });
const entityIds = Object.keys(entityDrawers);
let entityCount = 0;
for (const id of entityIds) {
  if (iconFilter && !iconFilter.has(id)) continue;
  if (process.env.VERBOSE_ICONS) console.log(`Generating entity ${id}`);
  const c = canvas();
  entityDrawers[id](c);
  fs.writeFileSync(path.join(ENTITY_OUT_DIR, `${id}.png`), pngBuffer(c));
  entityCount++;
}

console.log(`Generated ${itemCount} item icons in ${path.relative(ROOT, ITEM_OUT_DIR)}`);
console.log(`Generated ${entityCount} entity icons in ${path.relative(ROOT, ENTITY_OUT_DIR)}`);
