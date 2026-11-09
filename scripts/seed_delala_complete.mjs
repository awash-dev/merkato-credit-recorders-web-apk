import dotenv from 'dotenv';
import { neon } from '@neondatabase/serverless';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';

dotenv.config({ path: fileURLToPath(new URL('../.env', import.meta.url)) });

const connStr = process.env.DATABASE_URL || process.env.NEON_CONNECTION_STRING;
if (!connStr) {
  console.error('Missing DATABASE_URL: set it in .env');
  process.exit(1);
}

const sql = neon(connStr);

const STORE_RAYEY = 'store-1794218320972';    // ራእይ store
const STORE_CINEMA = 'store-1794218344775';   // ሲኒማራስ store

const DELALAS = [
  // ራእይ store
  {
    storeId: STORE_RAYEY,
    name: 'Dawit Delala',
    amharicName: 'ደላላ ዳዊት',
    phone: '0911223344',
    entries: [
      { product: '12W Safari', pieces: 100, unitPrice: 5, sign: 1, type: 'commission' },
      { product: 'switch', pieces: 50, unitPrice: 8, sign: 1, type: 'commission' },
      { product: '2.5 bmt', pieces: 4, unitPrice: 50, sign: 1, type: 'commission' },
      { product: 'Commission Payout (Telebirr)', pieces: 1, unitPrice: 800, sign: -1, type: 'payout' },
    ],
  },
  {
    storeId: STORE_RAYEY,
    name: 'Kassahun Broker',
    amharicName: 'ደላላ ካሳሁን',
    phone: '0912334455',
    entries: [
      { product: '6W Effishent', pieces: 80, unitPrice: 6, sign: 1, type: 'commission' },
      { product: 'socket double', pieces: 40, unitPrice: 10, sign: 1, type: 'commission' },
      { product: 'Commission Payout (Cash)', pieces: 1, unitPrice: 500, sign: -1, type: 'payout' },
    ],
  },
  // ሲኒማራስ store
  {
    storeId: STORE_CINEMA,
    name: 'Mohammed Delala',
    amharicName: 'ደላላ መሀመድ',
    phone: '0913445566',
    entries: [
      { product: '3W Effishent', pieces: 120, unitPrice: 5, sign: 1, type: 'commission' },
      { product: 'Circuit Breaker 16A', pieces: 30, unitPrice: 10, sign: 1, type: 'commission' },
      { product: 'LED Strip Light 50m', pieces: 3, unitPrice: 50, sign: 1, type: 'commission' },
      { product: 'Commission Payout (CBE)', pieces: 1, unitPrice: 700, sign: -1, type: 'payout' },
    ],
  },
  {
    storeId: STORE_CINEMA,
    name: 'Mulugeta Broker',
    amharicName: 'ደላላ ሙሉጌታ',
    phone: '0914556677',
    entries: [
      { product: '2.5 elusdy', pieces: 5, unitPrice: 40, sign: 1, type: 'commission' },
      { product: 'switch', pieces: 60, unitPrice: 7, sign: 1, type: 'commission' },
      { product: 'Commission Payout (Telebirr)', pieces: 1, unitPrice: 400, sign: -1, type: 'payout' },
    ],
  },
];

async function main() {
  console.log('--- Starting Complete Delala Seeding ---');

  // 1. Ensure required schema columns exist
  await sql`ALTER TABLE delala_entries ADD COLUMN IF NOT EXISTS operation_type VARCHAR(20) DEFAULT 'item_cash'`;
  await sql`ALTER TABLE delala_entries ADD COLUMN IF NOT EXISTS notes TEXT`;

  // 2. Clean previous Delala seed entries to prevent duplicates
  const names = DELALAS.map(d => d.name);
  await sql`DELETE FROM delala_entries WHERE delala_name = ANY(${names})`;
  await sql`DELETE FROM delala_accounts WHERE account_name = ANY(${names})`;
  await sql`DELETE FROM brokers WHERE full_name = ANY(${names})`;
  await sql`DELETE FROM ledger_records WHERE type = 'delala' AND title = ANY(${names})`;

  const now = Date.now();

  for (const d of DELALAS) {
    const brokerId = randomUUID();
    const accId = randomUUID();
    const storeLabel = d.storeId === STORE_RAYEY ? 'ራእይ store' : 'ሲኒማራስ store';

    // A. Insert into brokers
    await sql`
      INSERT INTO brokers (
        id, full_name, phone, store_id, status, created_at, updated_at
      ) VALUES (
        ${brokerId}::uuid, ${d.name}, ${d.phone}, ${d.storeId}, 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      )
    `;

    // B. Insert into delala_entries & calculate net balance
    let balance = 0;
    const ledgerLineItems = [];

    for (let i = 0; i < d.entries.length; i++) {
      const e = d.entries[i];
      const entryId = randomUUID();
      const total = Number((e.pieces * e.unitPrice).toFixed(2));
      balance += e.sign * total;

      await sql`
        INSERT INTO delala_entries (
          id, store_id, delala_name, product_name, pieces, unit_price, total, 
          sign, transaction_date, operation_type, created_at, updated_at
        ) VALUES (
          ${entryId}::uuid, ${d.storeId}, ${d.name}, ${e.product}, ${e.pieces}, ${e.unitPrice}, ${total},
          ${e.sign}, '2026-11-09', ${e.type}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        )
      `;

      ledgerLineItems.push({
        id: `item-delala-${now}-${i + 1}`,
        name: e.product,
        unitPrice: e.unitPrice,
        quantity: e.pieces,
        sign: e.sign > 0 ? '+' : '-',
        cartons: 0,
        pcsPerCarton: 1,
        packagingUnit: 'Pcs',
        customType: e.sign > 0 ? 'Commission' : 'Payout',
      });
    }

    // C. Insert into delala_accounts
    await sql`
      INSERT INTO delala_accounts (
        id, broker_id, store_id, account_name, current_balance, created_at, updated_at
      ) VALUES (
        ${accId}::uuid, ${brokerId}::uuid, ${d.storeId}, ${d.name}, ${balance}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      )
    `;

    // D. Insert into ledger_records (for party tab in Flutter & Web)
    const recId = `rec-delala-${now}-${Math.floor(Math.random() * 1000)}`;
    await sql`
      INSERT INTO ledger_records (
        id, type, title, date, notes, items, store_id, created_at, updated_at
      ) VALUES (
        ${recId}, 'delala', ${d.name}, '2026-11-09',
        ${'Broker commission and payouts for electrical items (' + storeLabel + ')'},
        ${JSON.stringify(ledgerLineItems)},
        ${d.storeId}, ${now.toString()}, ${now.toString()}
      )
    `;

    console.log(`✓ Seeded ${d.name} (${storeLabel}):`);
    console.log(`   - ${d.entries.length} delala_entries`);
    console.log(`   - 1 broker & delala_account record (Net Balance: ETB ${balance})`);
    console.log(`   - 1 ledger_records (type='delala')`);
  }

  console.log('\n--- Complete Delala Seeding Finished Successfully! ---');
}

main().catch(err => {
  console.error('Delala seeding error:', err);
  process.exit(1);
});
