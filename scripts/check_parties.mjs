import dotenv from 'dotenv';
import { neon } from '@neondatabase/serverless';

dotenv.config({ path: 'd:/project/eyoba-project/New folder/.env' });
const sql = neon(process.env.DATABASE_URL);

async function main() {
  const bCols = await sql`SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'brokers'`;
  console.log('brokers columns:', bCols.map(c => `${c.column_name} (${c.data_type})`));

  const brokers = await sql`SELECT * FROM brokers LIMIT 5`;
  console.log('brokers:', brokers);
}

main().catch(console.error);
