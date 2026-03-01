import { initializeApp } from "firebase/app";
import { getFirestore, enableIndexedDbPersistence } from "firebase/firestore";
import { getDatabase } from "firebase/database";

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

export const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const rtdb = getDatabase(app);

// Removed offline persistence temporarily for debugging
