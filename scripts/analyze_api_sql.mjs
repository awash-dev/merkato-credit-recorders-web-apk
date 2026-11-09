import { readFileSync } from 'fs';

const code = readFileSync('d:/project/eyoba-project/New folder/src/lib/api.ts', 'utf8');

// Match sql`...` template literals
// In JS, template literals can span multiple lines.
const regex = /sql`([\s\S]*?)`/g;
let match;
let count = 0;
while ((match = regex.exec(code)) !== null) {
  count++;
  const rawSql = match[1];
  // Count how many ${...} in rawSql
  const parts = rawSql.split(/\$\{/);
  if (parts.length > 2) { // has at least $1 and $2
    // The second parameter is the expression in parts[1] up to the matching }
    const expr2 = parts[2].split('}')[0].trim();
    const context = rawSql.replace(/\s+/g, ' ').trim().slice(0, 150);
    console.log(`Query #${count} at char ${match.index}:`);
    console.log(`  Context: ${context}`);
    console.log(`  Param $2 expr: ${expr2}`);
  }
}

