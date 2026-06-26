const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const TEXT_EXTENSIONS = new Set(['.css', '.html', '.js', '.json', '.md', '.txt']);
const SKIP_DIRS = new Set(['.git', 'node_modules']);

const checks = [
  { label: 'replacement character', pattern: /\uFFFD/ },
  { label: 'four or more consecutive question marks', pattern: /\?{4,}/ },
  {
    label: 'suspiciously dense question marks',
    pattern: /(?:\?(?:\s|[，。！？、；：,.!?:;()[\]{}<>"'`|+\-=/*\\])*){12,}/,
  },
];

function walk(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  return entries.flatMap(entry => {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name)) return [];
      return walk(fullPath);
    }
    return entry.isFile() && TEXT_EXTENSIONS.has(path.extname(entry.name).toLowerCase())
      ? [fullPath]
      : [];
  });
}

function lineAndColumn(text, index) {
  const before = text.slice(0, index);
  const lines = before.split(/\r?\n/);
  return { line: lines.length, column: lines[lines.length - 1].length + 1 };
}

const findings = [];

for (const file of walk(ROOT)) {
  const text = fs.readFileSync(file, 'utf8');
  for (const check of checks) {
    const match = check.pattern.exec(text);
    if (!match) continue;
    const pos = lineAndColumn(text, match.index);
    findings.push({
      file: path.relative(ROOT, file),
      label: check.label,
      line: pos.line,
      column: pos.column,
    });
  }
}

if (findings.length) {
  console.error('Suspicious text encoding markers found:');
  findings.forEach(finding => {
    console.error(`- ${finding.file}:${finding.line}:${finding.column} ${finding.label}`);
  });
  process.exit(1);
}

console.log('No suspicious text encoding markers found.');
