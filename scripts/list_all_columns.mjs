import dotenv from 'dotenv';
import { neon } from '@neondatabase/serverless';

dotenv.config({ path: 'd:/project/eyoba-project/New folder/.env' });
const sql = neon(process.env.DATABASE_URL);

async function run() {
  const cols = await sql`
    SELECT table_name, column_name, ordinal_position, data_type, udt_name
    FROM information_schema.columns 
    WHERE table_schema = 'public'
    ORDER BY table_name, ordinal_position
  `;
  for (const c of cols) {
    console.log(`${c.table_name}.${c.column_name} (pos: ${c.ordinal_position}): ${c.data_type} (${c.udt_name})`);
  }
}

run().catch(console.error);

