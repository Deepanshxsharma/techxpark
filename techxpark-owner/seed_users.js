
import { initializeApp } from "firebase/app";
import { getAuth, createUserWithEmailAndPassword, signInWithEmailAndPassword } from "firebase/auth";
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
const auth = getAuth(app);
const db = getFirestore(app);

const usersToCreate = [
    {
        email: 'owner@techxpark.in',
        password: 'owner123',
        role: 'owner',
        name: 'TechXPark Owner',
        assignedLotId: '1',
        accessStatus: 'approved'
    },
    {
        email: 'admin@techxpark.app',
        password: 'admin123',
        role: 'admin',
        name: 'Super Admin'
    }
];

async function createUsers() {
    for (const user of usersToCreate) {
        try {
            console.log(`Attempting to create/update user: ${user.email}`);
            
            let userCredential;
            try {
                userCredential = await createUserWithEmailAndPassword(auth, user.email, user.password);
                console.log(`✅ Auth user created for ${user.email}`);
            } catch (e) {
                if (e.code === 'auth/email-already-in-use') {
                    console.log(`ℹ️ Auth user already exists for ${user.email}, logging in to update Firestore...`);
                    userCredential = await signInWithEmailAndPassword(auth, user.email, user.password);
                } else {
                    throw e;
                }
            }

            const uid = userCredential.user.uid;
            
            // Prepare Firestore data
            const firestoreData = {
                email: user.email,
                role: user.role,
                name: user.name,
                uid: uid,
                updatedAt: new Date()
            };
            
            if (user.assignedLotId) firestoreData.assignedLotId = user.assignedLotId;
            if (user.accessStatus) firestoreData.accessStatus = user.accessStatus;

            await setDoc(doc(db, 'users', uid), firestoreData, { merge: true });
            console.log(`✅ Firestore document updated for ${user.email} (UID: ${uid})`);

        } catch (error) {
            console.error(`❌ Error processing ${user.email}:`, error.message);
        }
    }
    process.exit(0);
}

createUsers();
