import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { db } from '../firebase/config';
import { collection, query, where, getDocs } from 'firebase/firestore';

const ParkingContext = createContext();

export const useParking = () => useContext(ParkingContext);

// ── Saved parking shape ─────────────────────────────────
function getSavedParking() {
  try {
    const raw = localStorage.getItem('selectedParking');
    return raw ? JSON.parse(raw) : null;
  } catch { return null; }
}

export const ParkingProvider = ({ children }) => {
  const [selectedParking, setSelectedParking] = useState(getSavedParking);
  const [locations, setLocations] = useState([]);
  const [loading, setLoading] = useState(true);

  // ── Fetch from Firestore ──────────────────────────────
  useEffect(() => {
    let cancelled = false;

    async function fetchLocations() {
      setLoading(true);
      try {
        const q = query(
          collection(db, 'parking_locations'),
          where('isActive', '==', true)
        );
        const snap = await getDocs(q);
        if (!cancelled) {
          const locs = snap.docs.map(d => ({ id: d.id, ...d.data() }));
          setLocations(locs);
        }
      } catch (err) {
        console.warn('Firestore parking_locations fetch failed, using fallback data:', err.message);
        // Fallback demo data so the app works without Firestore seeding
        if (!cancelled) {
          setLocations([
            {
              id: 'godrej-bkc',
              name: 'Godrej BKC',
              address: 'Bandra Kurla Complex, Mumbai',
              imageUrl: '',
              available_slots: 78,
              total_slots: 120,
              isActive: true,
            },
            {
              id: 'bhutani-62',
              name: 'Bhutani 62 Avenue',
              address: 'Sector 62, Noida',
              imageUrl: '',
              available_slots: 45,
              total_slots: 80,
              isActive: true,
            },
            {
              id: 'dlf-cyber-city',
              name: 'DLF Cyber City',
              address: 'Gurgaon, Haryana',
              imageUrl: '',
              available_slots: 12,
              total_slots: 200,
              isActive: true,
            },
            {
              id: 'world-trade-center',
              name: 'World Trade Center',
              address: 'Lower Parel, Mumbai',
              imageUrl: '',
              available_slots: 0,
              total_slots: 150,
              isActive: true,
            },
          ]);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    fetchLocations();
    return () => { cancelled = true; };
  }, []);

  // ── Select parking ────────────────────────────────────
  const selectParking = useCallback((parking) => {
    const saved = { id: parking.id, name: parking.name, address: parking.address };
    localStorage.setItem('selectedParking', JSON.stringify(saved));
    setSelectedParking(saved);
  }, []);

  // ── Change location (clear selection) ─────────────────
  const clearParking = useCallback(() => {
    localStorage.removeItem('selectedParking');
    setSelectedParking(null);
  }, []);

  return (
    <ParkingContext.Provider value={{ selectedParking, locations, loading, selectParking, clearParking }}>
      {children}
    </ParkingContext.Provider>
  );
};
