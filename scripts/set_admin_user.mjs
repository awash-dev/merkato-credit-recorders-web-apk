import dotenv from 'dotenv';
import { neon } from '@neondatabase/serverless';
import crypto from 'node:crypto';
import { join } from 'node:path';

dotenv.config({ path: join(process.cwd(), '..', '.env') });
if (!process.env.DATABASE_URL) {
  dotenv.config({ path: join(process.cwd(), '.env') });
}

const sql = neon(process.env.DATABASE_URL);

function hashPasswordWithSalt(password) {
  const salt = Date.now().toString();
  const hash = crypto.createHash('sha256').update(salt + password).digest('hex');
  return `sha256:${salt}:${hash}`;
}

function verifyPassword(password, storedHash) {
  if (storedHash.startsWith('sha256:')) {
    const parts = storedHash.split(':');
    if (parts.length === 3) {
      const salt = parts[1];
      const expectedHash = parts[2];
      const actualHash = crypto.createHash('sha256').update(salt + password).digest('hex');
      return actualHash.toLowerCase() === expectedHash.toLowerCase();
    }
  }
  const plainHash = crypto.createHash('sha256').update(password).digest('hex');
  if (storedHash.toLowerCase() === plainHash.toLowerCase()) return true;
  return storedHash === password;
}

async function run() {
  console.log('--- Setting Admin User and Verifying DB ---');

  // 1. Ensure default stores exist
  await sql`
    INSERT INTO stores (id, name, code, created_at)
    VALUES 
      ('store_1', 'Merkato Store (መደብር 1 - መርካቶ)', 'MERKATO', ${Date.now()}),
      ('store_2', 'Bole Store (መደብር 2 - ቦሌ)', 'BOLE', ${Date.now()})
    ON CONFLICT (id) DO UPDATE SET 
      name = EXCLUDED.name,
      code = EXCLUDED.code;
  `;
  console.log('✓ Stores verified.');

  // 2. Clear conflicting phone numbers if any other user has 0911111111 or +251911111111
  await sql`
    DELETE FROM users 
    WHERE (phone = '0911111111' OR phone = '+251911111111') 
      AND id != 'usr_admin_1';
  `;

  // 3. Upsert Admin user
  const adminPassword = 'Admin@123';
  const adminHash = hashPasswordWithSalt(adminPassword);

  await sql`
    INSERT INTO users (id, name, email, phone, password_hash, role, store_id, active, created_at)
    VALUES (
      'usr_admin_1',
      'Admin',
      'admin@merkato.com',
      '0911111111',
      ${adminHash},
      'admin',
      NULL,
      true,
      ${Date.now()}
    )
    ON CONFLICT (id) DO UPDATE SET
      name = 'Admin',
      phone = '0911111111',
      password_hash = ${adminHash},
      role = 'admin',
      active = true;
  `;
  console.log('✓ Admin user upserted with phone 0911111111.');

  // 4. Verify user in DB
  const users = await sql`SELECT id, name, email, phone, role, active, password_hash FROM users WHERE phone = '0911111111'`;
  console.log('\nAdmin record in users table:');
  console.log(users);

  // 5. Test password verification
  const storedUser = users[0];
  const isMatch = verifyPassword('Admin@123', storedUser.password_hash);
  console.log(`\nPassword verification test for 'Admin@123': ${isMatch ? 'PASSED (MATCH)' : 'FAILED'}`);

  // 6. Check all tables in public schema
  const tables = await sql`
    SELECT table_name FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    ORDER BY table_name;
  `;
  console.log('\nAll public tables in database:');
  console.log(tables.map(t => t.table_name).join(', '));
}

run().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});

