
import { initializeApp } from "firebase/app";
import { getAuth, signInWithEmailAndPassword } from "firebase/auth";

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

const passwords = ["techxpark123", "password", "owner123", "admin123"];

async function testPasswords() {
    for (const pwd of passwords) {
        try {
            console.log(`Testing password: ${pwd}`);
            await signInWithEmailAndPassword(auth, "review@techxpark.app", pwd);
            console.log(`✅ SUCCESS! The password is: ${pwd}`);
            process.exit(0);
        } catch (e) {
            console.log(`❌ Failed: ${pwd}`);
        }
    }
    console.log("None of the common passwords worked.");
    process.exit(1);
}

testPasswords();
