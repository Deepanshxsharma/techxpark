const { initializeApp } = require('firebase/app');
const { getDatabase, ref, set } = require('firebase/database');

const firebaseConfig = {
  apiKey: "AIzaSyBIzofvIykqBqdadR66B7vE2Tmsn32KLpE",
  authDomain: "techxpark-67c25.firebaseapp.com",
  projectId: "techxpark-67c25",
  storageBucket: "techxpark-67c25.firebasestorage.app",
  messagingSenderId: "457287100758",
  appId: "1:457287100758:web:d6ccaa715cee7ea8028ef7",
  measurementId: "G-QFYGM34ZL9"
};

const app = initializeApp(firebaseConfig);
const rtdb = getDatabase(app);

// Simulate that slot F2A01 is available and F2A02 is occupied
const dummyData = {
    'lot1_F2A01': {
        taken: false,
        battery: 90,
        signal: -45,
        lastPing: Date.now(),
        lotId: '9G73d0FhORu7E9Kx1t4F', // Replace with an actual lot ID if needed
        slotId: 'F2A01'
    },
    'lot1_F2A02': {
        taken: true,
        battery: 85,
        signal: -50,
        lastPing: Date.now(),
        lotId: '9G73d0FhORu7E9Kx1t4F',
        slotId: 'F2A02'
    }
};

set(ref(rtdb, 'sensor_slots'), dummyData)
  .then(() => {
    console.log('Dummy sensor data injected');
    process.exit(0);
  })
  .catch((e) => {
    console.error('Error', e);
    process.exit(1);
  });
