import dotenv from 'dotenv';
import { neon } from '@neondatabase/serverless';

dotenv.config({ path: 'd:/project/eyoba-project/New folder/.env' });
const sql = neon(process.env.DATABASE_URL);

async function run() {
  const prods = await sql`SELECT id, product_name, pcs_per_carton, unit_price, cost_price, current_quantity, minimum_stock, quantity_cartons FROM store_inventory`;
  console.log('All products in store_inventory:');
  console.table(prods);
}

run().catch(console.error);

