import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, query, where, onSnapshot } from 'firebase/firestore';

export function useBookings(lotId) {
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!lotId) {
      setLoading(false);
      return;
    }

    const q = query(
      collection(db, 'bookings'),
      where('parkingId', '==', lotId)
    );

    const unsub = onSnapshot(q, (snapshot) => {
      const data = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setBookings(data);
      setLoading(false);
    });

    return () => unsub();
  }, [lotId]);

  return { bookings, loading };
}
