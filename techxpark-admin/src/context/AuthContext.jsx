import React, { createContext, useState, useEffect, useContext } from 'react';
import { auth, db } from '../firebase';
import {
    onAuthStateChanged,
    signInWithEmailAndPassword,
    signOut,
    setPersistence,
    browserLocalPersistence
} from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';

export const AuthContext = createContext();

export function AuthProvider({ children }) {
    const [user, setUser] = useState(null);
    const [adminData, setAdminData] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        // Set persistence to Local so login survives refresh
        setPersistence(auth, browserLocalPersistence)
            .catch(err => console.error("Auth persistence error:", err));

        const unsubscribe = onAuthStateChanged(auth, async (currentUser) => {
            if (currentUser) {
                setUser(currentUser);
                // Fetch the user's document from Firestore to check role
                try {
                    const userDoc = await getDoc(doc(db, 'users', currentUser.uid));
                    if (userDoc.exists()) {
                        setAdminData(userDoc.data());
                    } else {
                        setAdminData(null);
                    }
                } catch (error) {
                    console.error("Error fetching user data:", error);
                    setAdminData(null);
                }
            } else {
                setUser(null);
                setAdminData(null);
            }
            setLoading(false);
        });

        return () => unsubscribe();
    }, []);

    const login = (email, password) => {
        return signInWithEmailAndPassword(auth, email, password);
    };

    const logout = () => {
        return signOut(auth);
    };

    const value = {
        user,
        adminData,
        loading,
        login,
        logout
    };

    return (
        <AuthContext.Provider value={value}>
            {children}
        </AuthContext.Provider>
    );
}
