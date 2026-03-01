const { initializeApp } = require('firebase/app');
const { getFirestore, collection, getDocs } = require('firebase/firestore');
const { getDatabase, ref, get } = require('firebase/database');

const firebaseConfig = {
  apiKey: "AIzaSyBIzofvIykqBqdadR66B7vE2Tmsn32KLpE",
  authDomain: "techxpark-67c25.firebaseapp.com",
  projectId: "techxpark-67c25",
  storageBucket: "techxpark-67c25.firebasestorage.app",
  messagingSenderId: "457287100758",
  appId: "1:457287100758:web:d6ccaa715cee7ea8028ef7",
  measurementId: "G-QFYGM34ZL9",
  databaseURL: "https://techxpark-67c25-default-rtdb.asia-southeast1.firebasedatabase.app"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const rtdb = getDatabase(app);

async function inspectData() {
    console.log('--- Inspecting Firestore Slots (gardenia_apartment_parking) ---');
    try {
        const snap = await getDocs(collection(db, 'parking_locations', 'gardenia_apartment_parking', 'slots'));
        const slots = snap.docs.map(d => ({ id: d.id, ...d.data() }));
        console.log(`Found ${slots.length} slots. First 2:`, slots.slice(0, 2));
    } catch (e) {
        console.error('Firestore Error:', e.message);
    }

    console.log('\n--- Inspecting RTDB sensor_slots ---');
    try {
        const snap = await get(ref(rtdb, 'sensor_slots'));
        const sensors = snap.val() || {};
        const sensorIds = Object.keys(sensors);
        console.log(`Found ${sensorIds.length} sensors. First 2:`);
        sensorIds.slice(0, 2).forEach(id => console.log(id, sensors[id]));
        
        // Let's see if any belong to gardenia
        const gardeniaSensors = sensorIds.filter(id => {
            const s = sensors[id];
            const parts = id.split('_');
            const sidLotId = s.lotId || s.parkingLocationId || (parts.length > 1 ? parts[0] : '');
            return sidLotId === 'gardenia_apartment_parking';
        });
        console.log(`\nFound ${gardeniaSensors.length} sensors matching 'gardenia_apartment_parking'`);
    } catch (e) {
        console.error('RTDB Error:', e.message);
    }
    
    process.exit(0);
}

inspectData();
