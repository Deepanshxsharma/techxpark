import { createContext, useContext, useState, useEffect } from 'react';
import { auth, db } from '../firebase';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { doc, onSnapshot } from 'firebase/firestore';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
    const [user, setUser] = useState(null);
    const [userData, setUserData] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        let unsubDoc = null;

        const unsubAuth = onAuthStateChanged(auth, (firebaseUser) => {
            // Clean up previous doc listener
            if (unsubDoc) unsubDoc();

            if (firebaseUser) {
                setUser(firebaseUser);

                // CRITICAL: Use onSnapshot NOT getDoc
                // This auto-updates when admin approves owner's request in real time
                unsubDoc = onSnapshot(
                    doc(db, 'users', firebaseUser.uid),
                    (snap) => {
                        if (snap.exists()) {
                            setUserData({
                                uid: firebaseUser.uid,
                                ...snap.data()
                            });
                        } else {
                            // Document doesn't exist yet — treat as new user with no status
                            setUserData({
                                uid: firebaseUser.uid,
                                role: 'owner',
                                accessStatus: 'none',
                                assignedLotId: null,
                            });
                        }
                        setLoading(false);
                    },
                    (error) => {
                        console.error('Firestore listener error:', error);
                        setLoading(false);
                    }
                );
            } else {
                setUser(null);
                setUserData(null);
                setLoading(false);
            }
        });

        return () => {
            unsubAuth();
            if (unsubDoc) unsubDoc();
        };
    }, []);

    const logout = async () => {
        await signOut(auth);
        setUser(null);
        setUserData(null);
    };

    const value = {
        user,
        userData,
        ownerData: userData,
        loading,
        logout,
        // Convenience getters
        uid: user?.uid || null,
        role: userData?.role || null,
        accessStatus: userData?.accessStatus || 'none',
        lotId: userData?.assignedLotId || null,
        isLoggedIn: !!user,
        isApproved: userData?.accessStatus === 'approved',
    };

    return (
        <AuthContext.Provider value={value}>
            {children}
        </AuthContext.Provider>
    );
}

export const useAuth = () => {
    const ctx = useContext(AuthContext);
    if (!ctx) throw new Error('useAuth must be used within AuthProvider');
    return ctx;
};
