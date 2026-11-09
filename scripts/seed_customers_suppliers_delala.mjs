import dotenv from 'dotenv';
import { neon } from '@neondatabase/serverless';
import { randomUUID } from 'crypto';

dotenv.config({ path: 'd:/project/eyoba-project/New folder/.env' });
const sql = neon(process.env.DATABASE_URL);

const STORE_RAYEY = 'store-1794218320972'; // ራእይ store
const STORE_CINEMA = 'store-1794218344775'; // ሲኒማራስ store

// 1. CUSTOMERS
const CUSTOMERS = [
  // Store 1: ራእይ store
  {
    storeId: STORE_RAYEY,
    name: 'Eyob Tesfaye',
    notes: 'Electrician - Gerji project',
    items: [
      { name: '12W Safari', unitPrice: 125, quantity: 50, sign: '+', cartons: 0.5, pcsPerCarton: 100, customType: 'Goods' },
      { name: 'switch', unitPrice: 180, quantity: 15, sign: '+', cartons: 0.125, pcsPerCarton: 120, customType: 'Goods' },
      { name: 'socket', unitPrice: 200, quantity: 15, sign: '+', cartons: 0.15, pcsPerCarton: 100, customType: 'Goods' },
      { name: '2.5 bmt', unitPrice: 3850, quantity: 2, sign: '+', cartons: 0.33, pcsPerCarton: 6, customType: 'Goods' },
      { name: 'Payment via CBE', unitPrice: 10000, quantity: 1, sign: '-', bank: 'CBE', customType: 'Payment' },
    ],
  },
  {
    storeId: STORE_RAYEY,
    name: 'Kassahun Construction',
    notes: 'Building Contractor - CMC site',
    items: [
      { name: '3W Effishent', unitPrice: 100, quantity: 100, sign: '+', cartons: 1, pcsPerCarton: 100, customType: 'Goods' },
      { name: '6W Effishent', unitPrice: 115, quantity: 100, sign: '+', cartons: 1, pcsPerCarton: 100, customType: 'Goods' },
      { name: 'switch double', unitPrice: 220, quantity: 20, sign: '+', cartons: 0.17, pcsPerCarton: 120, customType: 'Goods' },
      { name: '1.5 bmt', unitPrice: 2600, quantity: 4, sign: '+', cartons: 0.5, pcsPerCarton: 8, customType: 'Goods' },
      { name: 'Distribution Box 8-Way', unitPrice: 850, quantity: 2, sign: '+', cartons: 0.1, pcsPerCarton: 20, customType: 'Goods' },
      { name: 'Payment via Awash Bank', unitPrice: 20000, quantity: 1, sign: '-', bank: 'Awash Bank', customType: 'Payment' },
    ],
  },
  {
    storeId: STORE_RAYEY,
    name: 'Tadesse Retail Shop',
    notes: 'Merkato Retail Merchant',
    items: [
      { name: '5W Candel3000K', unitPrice: 85, quantity: 50, sign: '+', cartons: 0.5, pcsPerCarton: 100, customType: 'Goods' },
      { name: '5W Candel8000K', unitPrice: 85, quantity: 50, sign: '+', cartons: 0.5, pcsPerCarton: 100, customType: 'Goods' },
      { name: 'Circuit Breaker 16A', unitPrice: 240, quantity: 20, sign: '+', cartons: 0.17, pcsPerCarton: 120, customType: 'Goods' },
      { name: 'Insulation Tape', unitPrice: 160, quantity: 10, sign: '+', cartons: 0.2, pcsPerCarton: 50, customType: 'Goods' },
      { name: 'Payment via Telebirr', unitPrice: 10000, quantity: 1, sign: '-', bank: 'Telebirr', customType: 'Payment' },
    ],
  },

  // Store 2: ሲኒማራስ store
  {
    storeId: STORE_CINEMA,
    name: 'Dawit Electrical Contractor',
    notes: 'Commercial fit-out contractor',
    items: [
      { name: '12W Safari', unitPrice: 125, quantity: 40, sign: '+', cartons: 0.4, pcsPerCarton: 100, customType: 'Goods' },
      { name: '9W Effishent', unitPrice: 140, quantity: 30, sign: '+', cartons: 0.3, pcsPerCarton: 100, customType: 'Goods' },
      { name: '2.5 elusdy', unitPrice: 3500, quantity: 3, sign: '+', cartons: 0.5, pcsPerCarton: 6, customType: 'Goods' },
      { name: 'Circuit Breaker 32A', unitPrice: 550, quantity: 5, sign: '+', cartons: 0.08, pcsPerCarton: 60, customType: 'Goods' },
      { name: 'Payment via CBE', unitPrice: 15000, quantity: 1, sign: '-', bank: 'CBE', customType: 'Payment' },
    ],
  },
  {
    storeId: STORE_CINEMA,
    name: 'Bole Apartment Project',
    notes: 'Yared - Bole Bulbula site',
    items: [
      { name: '3W Effishent', unitPrice: 100, quantity: 60, sign: '+', cartons: 0.6, pcsPerCarton: 100, customType: 'Goods' },
      { name: 'socket double', unitPrice: 300, quantity: 40, sign: '+', cartons: 0.5, pcsPerCarton: 80, customType: 'Goods' },
      { name: 'switch double', unitPrice: 220, quantity: 30, sign: '+', cartons: 0.25, pcsPerCarton: 120, customType: 'Goods' },
      { name: 'LED Strip Light 50m', unitPrice: 2400, quantity: 2, sign: '+', cartons: 0.2, pcsPerCarton: 10, customType: 'Goods' },
      { name: 'Payment via Abyssinia Bank', unitPrice: 20000, quantity: 1, sign: '-', bank: 'Bank of Abyssinia', customType: 'Payment' },
    ],
  },
];

// 2. SUPPLIERS
const SUPPLIERS = [
  // Store 1: ራእይ store
  {
    storeId: STORE_RAYEY,
    name: 'Safari Trading',
    notes: 'LED bulb importer & distributor',
    items: [
      { name: '12W Safari', unitPrice: 95, quantity: 200, sign: '+', cartons: 2, pcsPerCarton: 100, customType: 'Goods' },
      { name: '5W Candel3000K', unitPrice: 65, quantity: 100, sign: '+', cartons: 1, pcsPerCarton: 100, customType: 'Goods' },
      { name: 'Payment via CBE Transfer', unitPrice: 20000, quantity: 1, sign: '-', bank: 'CBE', customType: 'Payment' },
    ],
  },
  {
    storeId: STORE_RAYEY,
    name: 'BMT Cable Industries',
    notes: 'Domestic pure copper cable manufacturer',
    items: [
      { name: '2.5 bmt', unitPrice: 3200, quantity: 10, sign: '+', cartons: 1.67, pcsPerCarton: 6, customType: 'Goods' },
      { name: '1.5 bmt', unitPrice: 2100, quantity: 10, sign: '+', cartons: 1.25, pcsPerCarton: 8, customType: 'Goods' },
      { name: 'Payment via Awash Bank', unitPrice: 40000, quantity: 1, sign: '-', bank: 'Awash Bank', customType: 'Payment' },
    ],
  },

  // Store 2: ሲኒማራስ store
  {
    storeId: STORE_CINEMA,
    name: 'Effishent Lighting Wholesale',
    notes: 'Direct importer of Effishent downlights',
    items: [
      { name: '3W Effishent', unitPrice: 75, quantity: 150, sign: '+', cartons: 1.5, pcsPerCarton: 100, customType: 'Goods' },
      { name: '6W Effishent', unitPrice: 90, quantity: 100, sign: '+', cartons: 1, pcsPerCarton: 100, customType: 'Goods' },
      { name: '9W Effishent', unitPrice: 110, quantity: 50, sign: '+', cartons: 0.5, pcsPerCarton: 100, customType: 'Goods' },
      { name: 'Payment via CBE', unitPrice: 20000, quantity: 1, sign: '-', bank: 'CBE', customType: 'Payment' },
    ],
  },
  {
    storeId: STORE_CINEMA,
    name: 'Chint Electric Ethiopia',
    notes: 'Industrial switchgear & breakers dealer',
    items: [
      { name: 'Circuit Breaker 16A', unitPrice: 180, quantity: 100, sign: '+', cartons: 0.83, pcsPerCarton: 120, customType: 'Goods' },
      { name: 'Circuit Breaker 32A', unitPrice: 420, quantity: 30, sign: '+', cartons: 0.5, pcsPerCarton: 60, customType: 'Goods' },
      { name: 'Distribution Box 8-Way', unitPrice: 650, quantity: 10, sign: '+', cartons: 0.5, pcsPerCarton: 20, customType: 'Goods' },
      { name: 'Payment via Telebirr Business', unitPrice: 25000, quantity: 1, sign: '-', bank: 'Telebirr', customType: 'Payment' },
    ],
  },
];

// 3. DELALA (Brokers)
const DELALAS = [
  // Store 1: ራእይ store
  {
    storeId: STORE_RAYEY,
    name: 'Dawit Delala',
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
    phone: '0912334455',
    entries: [
      { product: '6W Effishent', pieces: 80, unitPrice: 6, sign: 1, type: 'commission' },
      { product: 'socket double', pieces: 40, unitPrice: 10, sign: 1, type: 'commission' },
      { product: 'Commission Payout (Cash)', pieces: 1, unitPrice: 500, sign: -1, type: 'payout' },
    ],
  },

  // Store 2: ሲኒማራስ store
  {
    storeId: STORE_CINEMA,
    name: 'Mohammed Delala',
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
    phone: '0914556677',
    entries: [
      { product: '2.5 elusdy', pieces: 5, unitPrice: 40, sign: 1, type: 'commission' },
      { product: 'switch', pieces: 60, unitPrice: 7, sign: 1, type: 'commission' },
      { product: 'Commission Payout (Telebirr)', pieces: 1, unitPrice: 400, sign: -1, type: 'payout' },
    ],
  },
];

async function seed() {
  console.log('Ensuring schema columns for delala_entries...');
  await sql`ALTER TABLE delala_entries ADD COLUMN IF NOT EXISTS operation_type VARCHAR(20) DEFAULT 'item_cash'`;
  await sql`ALTER TABLE delala_entries ADD COLUMN IF NOT EXISTS notes TEXT`;

  // Clean previous seed entries
  await sql`DELETE FROM ledger_records WHERE id LIKE 'rec-cust-%' OR id LIKE 'rec-supp-%'`;
  await sql`DELETE FROM delala_entries WHERE delala_name IN ('Dawit Delala', 'Kassahun Broker', 'Mohammed Delala', 'Mulugeta Broker')`;
  await sql`DELETE FROM delala_accounts WHERE account_name IN ('Dawit Delala', 'Kassahun Broker', 'Mohammed Delala', 'Mulugeta Broker')`;
  await sql`DELETE FROM brokers WHERE full_name IN ('Dawit Delala', 'Kassahun Broker', 'Mohammed Delala', 'Mulugeta Broker')`;

  console.log('Seeding Customers, Suppliers, and Delala for both stores...\n');
  const now = Date.now();

  // 1. Seed Customers into ledger_records
  console.log('=== 1. SEEDING CUSTOMERS ===');
  for (const c of CUSTOMERS) {
    const recId = `rec-cust-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
    const lineItems = c.items.map((it, idx) => ({
      id: `item-${Date.now()}-${idx + 1}`,
      name: it.name,
      unitPrice: it.unitPrice,
      quantity: it.quantity,
      sign: it.sign,
      customType: it.customType ?? 'Goods',
      cartons: it.cartons ?? 1,
      pcsPerCarton: it.pcsPerCarton ?? 1,
      packagingUnit: it.pcsPerCarton && it.pcsPerCarton > 1 ? 'Pcs' : 'Pcs',
      bank: it.bank,
      date: '2026-11-09',
    }));

    await sql`
      INSERT INTO ledger_records (
        id, type, title, date, notes, items, store_id, created_at, updated_at
      ) VALUES (
        ${recId}, 'customer', ${c.name}, '2026-11-09', ${c.notes}, 
        ${JSON.stringify(lineItems)}, ${c.storeId}, ${now.toString()}, ${now.toString()}
      )
    `;
    console.log(`✓ Customer: ${c.name} (${c.storeId === STORE_RAYEY ? 'ራእይ' : 'ሲኒማራስ'}) - ${c.items.length} entries`);
  }

  // 2. Seed Suppliers into ledger_records
  console.log('\n=== 2. SEEDING SUPPLIERS ===');
  for (const s of SUPPLIERS) {
    const recId = `rec-supp-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
    const lineItems = s.items.map((it, idx) => ({
      id: `item-${Date.now()}-${idx + 1}`,
      name: it.name,
      unitPrice: it.unitPrice,
      quantity: it.quantity,
      sign: it.sign,
      customType: it.customType ?? 'Goods',
      cartons: it.cartons ?? 1,
      pcsPerCarton: it.pcsPerCarton ?? 1,
      packagingUnit: it.pcsPerCarton && it.pcsPerCarton > 1 ? 'Pcs' : 'Pcs',
      bank: it.bank,
      date: '2026-11-09',
    }));

    await sql`
      INSERT INTO ledger_records (
        id, type, title, date, notes, items, store_id, created_at, updated_at
      ) VALUES (
        ${recId}, 'supplier', ${s.name}, '2026-11-09', ${s.notes}, 
        ${JSON.stringify(lineItems)}, ${s.storeId}, ${now.toString()}, ${now.toString()}
      )
    `;
    console.log(`✓ Supplier: ${s.name} (${s.storeId === STORE_RAYEY ? 'ራእይ' : 'ሲኒማራስ'}) - ${s.items.length} entries`);
  }

  // 3. Seed Delala into brokers, delala_accounts, and delala_entries
  console.log('\n=== 3. SEEDING DELALA (BROKERS) ===');
  for (const d of DELALAS) {
    const brokerId = randomUUID();
    await sql`
      INSERT INTO brokers (
        id, full_name, phone, store_id, status, created_at, updated_at
      ) VALUES (
        ${brokerId}::uuid, ${d.name}, ${d.phone}, ${d.storeId}, 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      )
    `;

    let balance = 0;
    for (const e of d.entries) {
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
    }

    const accId = randomUUID();
    await sql`
      INSERT INTO delala_accounts (
        id, broker_id, store_id, account_name, current_balance, created_at, updated_at
      ) VALUES (
        ${accId}::uuid, ${brokerId}::uuid, ${d.storeId}, ${d.name}, ${balance}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      )
    `;

    console.log(`✓ Delala: ${d.name} (${d.storeId === STORE_RAYEY ? 'ራእይ' : 'ሲኒማራስ'}) - ${d.entries.length} entries, Balance: ETB ${balance}`);
  }

  console.log('\n✓ ALL Customers, Suppliers, and Delalas seeded successfully for both stores!');
}

seed().catch(err => {
  console.error('Seeding error:', err);
  process.exit(1);
});
