import dotenv from 'dotenv';
import { neon } from '@neondatabase/serverless';

dotenv.config({ path: 'd:/project/eyoba-project/New folder/.env' });
const sql = neon(process.env.DATABASE_URL);

async function run() {
  const tables = ['store_inventory', 'stock_movements', 'ledger_records', 'ledger_transactions'];
  for (const t of tables) {
    const cols = await sql.query(`
      SELECT column_name, data_type, udt_name, is_nullable
      FROM information_schema.columns 
      WHERE table_name = '${t}'
      ORDER BY ordinal_position
    `);
    console.log(`=== TABLE: ${t} ===`);
    for (const c of cols) {
      console.log(`  ${c.column_name}: ${c.data_type} (${c.udt_name}) [nullable: ${c.is_nullable}]`);
    }
  }
}

run().catch(console.error);

