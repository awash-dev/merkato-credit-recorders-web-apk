import { readFileSync, readdirSync, statSync } from 'fs';
import { join } from 'path';

function findFiles(dir, exts) {
  let results = [];
  for (const f of readdirSync(dir)) {
    const p = join(dir, f);
    if (f === 'node_modules' || f === '.git' || f === 'build' || f === '.dart_tool') continue;
    const s = statSync(p);
    if (s.isDirectory()) {
      results = results.concat(findFiles(p, exts));
    } else if (exts.some(ext => p.endsWith(ext))) {
      results.push(p);
    }
  }
  return results;
}

const files = [
  ...findFiles('d:/project/eyoba-project/New folder/apk/lib', ['.dart']),
  ...findFiles('d:/project/eyoba-project/New folder/src', ['.ts', '.tsx']),
  ...findFiles('d:/project/eyoba-project/New folder/api', ['.ts']),
];

for (const f of files) {
  const content = readFileSync(f, 'utf8');
  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.includes('$2') || line.includes('executeSql') || line.includes('recordStockMovement')) {
      console.log(`${f}:${i + 1}: ${line.trim()}`);
    }
  }
}

