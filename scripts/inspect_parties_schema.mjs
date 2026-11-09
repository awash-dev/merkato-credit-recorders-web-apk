import dotenv from 'dotenv';
import { neon } from '@neondatabase/serverless';

dotenv.config({ path: 'd:/project/eyoba-project/New folder/.env' });
const sql = neon(process.env.DATABASE_URL);

async function main() {
  const lrCols = await sql`SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'ledger_records'`;
  console.log('ledger_records columns:', lrCols.map(c => `${c.column_name} (${c.data_type})`));

  const ltCols = await sql`SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'ledger_transactions'`;
  console.log('ledger_transactions columns:', ltCols.map(c => `${c.column_name} (${c.data_type})`));

  const deCols = await sql`SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'delala_entries'`;
  console.log('delala_entries columns:', deCols.map(c => `${c.column_name} (${c.data_type})`));

  const daCols = await sql`SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'delala_accounts'`;
  console.log('delala_accounts columns:', daCols.map(c => `${c.column_name} (${c.data_type})`));

  const sampleLr = await sql`SELECT * FROM ledger_records LIMIT 2`;
  console.log('Sample ledger_records:', JSON.stringify(sampleLr, null, 2));

  const sampleDe = await sql`SELECT * FROM delala_entries LIMIT 2`;
  console.log('Sample delala_entries:', JSON.stringify(sampleDe, null, 2));
}

main().catch(console.error);

