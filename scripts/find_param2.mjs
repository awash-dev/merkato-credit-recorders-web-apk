import { readFileSync } from 'fs';

// 1. Check apk/lib/services/neon_database_service.dart
const neonService = readFileSync('d:/project/eyoba-project/New folder/apk/lib/services/neon_database_service.dart', 'utf8');

// Find all executeSql calls and see what $2 is
const executeSqlMatches = neonService.matchAll(/executeSql\s*\(\s*(['"`][\s\S]*?['"`])\s*,\s*(\[[\s\S]*?\])\s*\)/g);
console.log('=== NeonDatabaseService queries with params ===');
for (const match of executeSqlMatches) {
  const query = match[1];
  const params = match[2];
  if (query.includes('$2')) {
    console.log('--- QUERY ---');
    console.log(query.trim().slice(0, 200));
    console.log('--- PARAMS ---');
    console.log(params.trim());
  }
}
