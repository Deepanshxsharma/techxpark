import { initializeApp } from "firebase/app";
import { getFirestore, doc, setDoc } from "firebase/firestore";

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

async function makeOwner() {
    const uid = 'ETAOqBKpoVdsEpcCyfzdNClZFF83';
    console.log("Updating role for:", uid);
    
    await setDoc(doc(db, 'users', uid), {
        email: 'review@techxpark.app',
        role: 'owner',
        name: 'Review Account',
        assignedLotId: '1'
    }, { merge: true });
    
    console.log("SUCCESSFULLY UPDATED ROLE");
    process.exit(0);
}

makeOwner().catch(e => { console.error(e); process.exit(1); });
