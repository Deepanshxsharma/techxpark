import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, onSnapshot } from 'firebase/firestore';

export function useSlots(lotId) {
  const [slots, setSlots] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!lotId) {
      setLoading(false);
      return;
    }

    const unsub = onSnapshot(
      collection(db, `parking_locations/${lotId}/slots`),
      (snapshot) => {
        const data = snapshot.docs.map(doc => ({
          id: doc.id, // e.g. "A12"
          ...doc.data()
        }));
        setSlots(data);
        setLoading(false);
      }
    );

    return () => unsub();
  }, [lotId]);

  return { slots, loading };
}
