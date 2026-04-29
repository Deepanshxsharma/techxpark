/**
 * Create Godrej BKC Staff Accounts
 * Run with: node scripts/create-godrej-staff.js
 * 
 * Creates operator and admin users in Firebase Auth
 * and sets their role in Firestore.
 */

const admin = require('firebase-admin');

admin.initializeApp({
  projectId: 'techxpark-67c25'
});

const auth = admin.auth();
const db = admin.firestore();

const STAFF_ACCOUNTS = [
  {
    email: 'admin@godrejbkc.com',
    password: 'Godrej@2026',
    displayName: 'Godrej Admin',
    role: 'admin',
  },
  {
    email: 'operator@godrejbkc.com',
    password: 'Operator@2026',
    displayName: 'B1 Zone Operator',
    role: 'operator',
  },
  {
    email: 'deepansh@techxpark.com',
    password: 'Admin@2026',
    displayName: 'Deepansh (Super Admin)',
    role: 'superadmin',
  },
];

async function createStaff() {
  console.log('🔐 Creating Godrej BKC Staff Accounts...\n');

  for (const staff of STAFF_ACCOUNTS) {
    try {
      // Check if user already exists
      let user;
      try {
        user = await auth.getUserByEmail(staff.email);
        console.log(`  ⚠️  ${staff.email} already exists (uid: ${user.uid})`);
      } catch (e) {
        // User doesn't exist, create it
        user = await auth.createUser({
          email: staff.email,
          password: staff.password,
          displayName: staff.displayName,
          emailVerified: true,
        });
        console.log(`  ✅ Created: ${staff.email} (uid: ${user.uid})`);
      }

      // Set role in Firestore
      await db.collection('users').doc(user.uid).set({
        email: staff.email,
        name: staff.displayName,
        role: staff.role,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      console.log(`     Role: ${staff.role}\n`);

    } catch (err) {
      console.error(`  ❌ Failed for ${staff.email}:`, err.message);
    }
  }

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('Staff Login Credentials:');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  for (const staff of STAFF_ACCOUNTS) {
    console.log(`  ${staff.role.toUpperCase().padEnd(12)} ${staff.email}  /  ${staff.password}`);
  }
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  process.exit(0);
}

createStaff().catch(err => {
  console.error('❌ Script failed:', err);
  process.exit(1);
});
