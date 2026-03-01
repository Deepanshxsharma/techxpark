import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, query, where, onSnapshot, orderBy, doc } from 'firebase/firestore';

export function useAccessRequest(lotId) {
    const [requests, setRequests] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        // We only fetch LOT-SPECIFIC pending access requests if lotId is given
        // This is typically for an "admin" checking specific lot requests, or if an owner
        // wanted to see requests for a lot (though owners usually just request one).
        if (!lotId) {
            setLoading(false);
            return;
        }

        const q = query(
            collection(db, 'access_requests'),
            where('lotId', '==', lotId),
            orderBy('requestedAt', 'desc')
        );

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
            setRequests(data);
            setLoading(false);
        }, (error) => {
            console.error("Error fetching access requests:", error);
            setLoading(false);
        });

        return unsubscribe;
    }, [lotId]);

    return { requests, loading };
}

// Hook for an owner to listen to their own single pending/rejected request
export function useOwnerRequest(requestId) {
    const [requestData, setRequestData] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!requestId) {
            setLoading(false);
            return;
        }

        const unsubscribe = onSnapshot(doc(db, 'access_requests', requestId), (docSnap) => {
            if (docSnap.exists()) {
                setRequestData({ id: docSnap.id, ...docSnap.data() });
            } else {
                setRequestData(null);
            }
            setLoading(false);
        }, (error) => {
            console.error("Error fetching owner request:", error);
            setLoading(false);
        });

        return unsubscribe;
    }, [requestId]);

    return { requestData, loading };
}

// Hook for Super Admin to listen to ALL active requests
export function useAllAccessRequests(statusFilter = 'all') {
    const [requests, setRequests] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        let q;
        if (statusFilter === 'all') {
            q = query(
                collection(db, 'access_requests'),
                orderBy('requestedAt', 'desc')
            );
        } else {
            q = query(
                collection(db, 'access_requests'),
                where('status', '==', statusFilter),
                orderBy('requestedAt', 'desc')
            );
        }

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
            setRequests(data);
            setLoading(false);
        }, (error) => {
            console.error("Error fetching all access requests:", error);
            setLoading(false);
        });

        return unsubscribe;
    }, [statusFilter]);

    return { requests, loading };
}
