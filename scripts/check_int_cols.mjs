import dotenv from 'dotenv';
import { neon } from '@neondatabase/serverless';

dotenv.config({ path: 'd:/project/eyoba-project/New folder/.env' });
const sql = neon(process.env.DATABASE_URL);

async function run() {
  const intCols = await sql.query(`
    SELECT table_name, column_name, data_type, udt_name, ordinal_position
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND data_type IN ('integer', 'smallint', 'bigint')
    ORDER BY table_name, ordinal_position
  `);
  console.log('Integer columns in public schema:');
  console.table(intCols);
}

run().catch(console.error);

