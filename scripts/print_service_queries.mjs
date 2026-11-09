import { readFileSync } from 'fs';

const neonService = readFileSync('d:/project/eyoba-project/New folder/apk/lib/services/neon_database_service.dart', 'utf8');

const lines = neonService.split('\n');
for (let i = 1200; i < lines.length; i++) {
  if (lines[i].includes('executeSql')) {
    console.log(`Line ${i + 1}:`);
    for (let j = Math.max(0, i - 2); j < Math.min(lines.length, i + 30); j++) {
      console.log(`  ${lines[j]}`);
      if (lines[j].includes(');')) break;
    }
  }
}

