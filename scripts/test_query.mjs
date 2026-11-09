import dotenv from 'dotenv';
import { neon } from '@neondatabase/serverless';

dotenv.config({ path: 'd:/project/eyoba-project/New folder/.env' });

async function run() {
  const url = process.env.DATABASE_URL;
  const host = new URL(url).hostname.replace('-pooler', '');
  const targetUrl = `https://${host}/sql`;

  // First fetch a product
  const sql = neon(url);
  const products = await sql`SELECT id, product_name, current_quantity, unit_price, cost_price FROM store_inventory LIMIT 1`;
  console.log('Sample product:', products[0]);

  if (!products.length) {
    console.log('No products found');
    return;
  }

  const prod = products[0];

  // Let's test the exact query from recordStockMovementDirect (Stock In):
  const query = `
    UPDATE store_inventory
    SET current_quantity = current_quantity + $1,
        cost_price = CASE WHEN $2 > 0 THEN $2 ELSE cost_price END,
        pcs_per_carton = CASE WHEN $3 > 0 THEN $3 ELSE pcs_per_carton END,
        supplier_name = COALESCE($4, supplier_name),
        last_transaction_date = $5,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = $6
    RETURNING *, (current_quantity - $1) AS previous_qty
  `;

  // Note: in Dart, [100.0, 200.0, 10.0, null, '2026-11-07', prod.id]
  const payload = {
    query,
    params: [10.0, 200.0, 10.0, null, '2026-11-07', prod.id]
  };

  const res = await fetch(targetUrl, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'neon-connection-string': url,
      'neon-raw-text-output': 'true'
    },
    body: JSON.stringify(payload)
  });

  const text = await res.text();
  console.log('Stock In status:', res.status, text);
}

run().catch(console.error);

