import dotenv from 'dotenv';
import { neon } from '@neondatabase/serverless';

dotenv.config({ path: 'd:/project/eyoba-project/New folder/.env' });
const sql = neon(process.env.DATABASE_URL);

async function run() {
  const dups = await sql`
    SELECT LOWER(TRIM(product_name)) as name, COALESCE(store_id, '') as store, COUNT(*) as cnt
    FROM store_inventory
    WHERE is_deleted IS NULL OR is_deleted = false
    GROUP BY LOWER(TRIM(product_name)), COALESCE(store_id, '')
    HAVING COUNT(*) > 1
  `;
  console.log('Duplicate products count:', dups.length);
  if (dups.length > 0) {
    console.table(dups);
  }
}

run().catch(console.error);

