
import { initializeApp } from "firebase/app";
import { getFirestore, collection, getDocs, query, where } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyBIzofvIykqBqdadR66B7vE2Tmsn32KLpE",
  authDomain: "techxpark-67c25.firebaseapp.com",
  projectId: "techxpark-67c25",
  storageBucket: "techxpark-67c25.firebasestorage.app",
  messagingSenderId: "457287100758",
  appId: "1:457287100758:web:d6ccaa715cee7ea8028ef7"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function checkAdmin() {
    console.log("Checking for admin user...");
    const q = query(collection(db, 'users'), where('email', '==', 'admin@techxpark.app'));
    const snapshot = await getDocs(q);
    
    if (snapshot.empty) {
        console.log("admin@techxpark.app NOT found in Firestore.");
    } else {
        snapshot.forEach(doc => {
            console.log(`Found User: ID=${doc.id}, Data:`, doc.data());
        });
    }
    process.exit(0);
}

checkAdmin().catch(e => { console.error(e); process.exit(1); });
