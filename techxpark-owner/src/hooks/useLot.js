import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { doc, onSnapshot, collection } from 'firebase/firestore';

export function useLot(lotId) {
  const [lotData, setLotData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!lotId) {
      setLoading(false);
      return;
    }

    const unsub = onSnapshot(
      doc(db, 'parking_locations', lotId),
      (docSnap) => {
        if (docSnap.exists()) {
          setLotData({ id: docSnap.id, ...docSnap.data() });
        } else {
          setError("Lot not found");
        }
        setLoading(false);
      },
      (err) => {
        console.error("Lot listener error:", err);
        setError(err.message);
        setLoading(false);
      }
    );

    return () => unsub();
  }, [lotId]);

  return { lotData, loading, error };
}

// Hook to fetch all parking lots for selection
export function useAllLots() {
  const [lots, setLots] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(
      collection(db, 'parking_locations'),
      (snapshot) => {
        const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        setLots(data);
        setLoading(false);
      },
      (err) => {
        console.error("All lots listener error:", err);
        setLoading(false);
      }
    );

    return () => unsub();
  }, []);

  return { lots, loading };
}
