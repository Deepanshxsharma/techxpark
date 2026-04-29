/**
 * Godrej BKC Seed Data Script
 * Run with: node scripts/seed-godrej.js
 * 
 * Seeds zones, lifters, settings, and sample employees
 * into Firestore for initial setup.
 */

const admin = require('firebase-admin');

// Use existing service account or default credentials
admin.initializeApp({
  projectId: 'techxpark-67c25'
});

const db = admin.firestore();

async function seed() {
  console.log('🚀 Seeding Godrej BKC data...\n');

  // ── 1. Zones ──────────────────────────────
  const zones = [
    {
      id: 'zone_b1',
      name: 'B1 Zone (Basement 1)',
      code: 'B1',
      baseEtaMinutes: 12,
      totalLifters: 3,
      activeLifters: 3,
      nonCollectionTimeoutMinutes: 15,
      isActive: true,
    },
    {
      id: 'zone_b2',
      name: 'B2 Zone (Basement 2)',
      code: 'B2',
      baseEtaMinutes: 18,
      totalLifters: 2,
      activeLifters: 2,
      nonCollectionTimeoutMinutes: 15,
      isActive: true,
    },
  ];

  for (const zone of zones) {
    const { id, ...data } = zone;
    await db.collection('godrej_zones').doc(id).set(data);
    console.log(`  ✅ Zone: ${data.name}`);
  }

  // ── 2. Lifters ────────────────────────────
  const lifters = [
    { id: 'lifter_1', name: 'Ramesh Kumar', phone: '+919876543211', zoneId: 'zone_b1', status: 'idle', isActive: true, currentRequestId: null, breakdownNote: '' },
    { id: 'lifter_2', name: 'Sunil Patil', phone: '+919876543212', zoneId: 'zone_b1', status: 'idle', isActive: true, currentRequestId: null, breakdownNote: '' },
    { id: 'lifter_3', name: 'Deepak Yadav', phone: '+919876543213', zoneId: 'zone_b1', status: 'idle', isActive: true, currentRequestId: null, breakdownNote: '' },
    { id: 'lifter_4', name: 'Manoj Singh', phone: '+919876543214', zoneId: 'zone_b2', status: 'idle', isActive: true, currentRequestId: null, breakdownNote: '' },
    { id: 'lifter_5', name: 'Ajay Sharma', phone: '+919876543215', zoneId: 'zone_b2', status: 'idle', isActive: true, currentRequestId: null, breakdownNote: '' },
  ];

  for (const lifter of lifters) {
    const { id, ...data } = lifter;
    await db.collection('godrej_lifters').doc(id).set(data);
    console.log(`  ✅ Lifter: ${data.name} (${data.zoneId})`);
  }

  // ── 3. Settings ───────────────────────────
  await db.collection('godrej_settings').doc('global').set({
    defaultBaseEtaMinutes: 15,
    nonCollectionTimeoutMinutes: 15,
    smsEnabled: false,
    emailEnabled: false,
    maintenanceMode: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log('  ✅ Settings: global config');

  // ── 4. Sample Employees ───────────────────
  const employees = [
    { name: 'Priya Mehta', phone: '+919821000001', email: 'priya@godrejbkc.com', flatNumber: '1201', wing: 'A', vehicleNumber: 'MH02AB1234', vehicleModel: 'Honda City', isActive: true, totalRequests: 0 },
    { name: 'Vikram Shah', phone: '+919821000002', email: 'vikram@godrejbkc.com', flatNumber: '803', wing: 'B', vehicleNumber: 'MH04CD5678', vehicleModel: 'Hyundai Creta', isActive: true, totalRequests: 0 },
    { name: 'Ananya Desai', phone: '+919821000003', email: 'ananya@godrejbkc.com', flatNumber: '1502', wing: 'A', vehicleNumber: 'MH01EF9012', vehicleModel: 'Maruti Swift', isActive: true, totalRequests: 0 },
    { name: 'Rohan Joshi', phone: '+919821000004', email: 'rohan@godrejbkc.com', flatNumber: '604', wing: 'C', vehicleNumber: 'MH03GH3456', vehicleModel: 'Tata Nexon', isActive: true, totalRequests: 0 },
    { name: 'Sneha Kapoor', phone: '+919821000005', email: 'sneha@godrejbkc.com', flatNumber: '901', wing: 'B', vehicleNumber: 'MH02IJ7890', vehicleModel: 'Kia Seltos', isActive: true, totalRequests: 0 },
  ];

  for (const emp of employees) {
    await db.collection('godrej_employees').add({
      ...emp,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  ✅ Employee: ${emp.name} — ${emp.vehicleNumber}`);
  }

  console.log('\n🎉 Seed complete! All Godrej BKC data has been loaded.');
  process.exit(0);
}

seed().catch(err => {
  console.error('❌ Seed failed:', err);
  process.exit(1);
});
