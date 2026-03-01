import { useState, useEffect, useRef } from 'react';
import { db, rtdb } from '../firebase';
import { doc, onSnapshot, collection } from 'firebase/firestore';
import { ref, onValue } from 'firebase/database';

/**
 * Live Firestore + RTDB listener.
 * Returns { lot, slots, floors, totalFree, totalOcc, loading, offline }
 */
export default function useLotData(lotId) {
  const [lot, setLot] = useState(null);
  const [fsSlots, setFsSlots] = useState([]);
  const [sensorData, setSensorData] = useState({});
  const [loading, setLoading] = useState(true);
  const [offline, setOffline] = useState(false);
  const prevSlots = useRef(new Map());
  const [changedSlots, setChangedSlots] = useState(new Map()); // slotId -> 'freed' | 'taken'
  const [slots, setSlots] = useState([]);

  // ── Lot document listener
  useEffect(() => {
    if (!lotId) return;
    const unsub = onSnapshot(
      doc(db, 'parking_locations', lotId),
      snap => { if (snap.exists()) { setLot({ id: snap.id, ...snap.data() }); setOffline(false); } },
      () => setOffline(true),
    );
    return unsub;
  }, [lotId]);

  // ── Firestore Slots collection listener
  useEffect(() => {
    if (!lotId) return;
    const unsub = onSnapshot(
      collection(db, 'parking_locations', lotId, 'slots'),
      snap => {
        setFsSlots(snap.docs.map(d => ({ id: d.id, ...d.data() })));
        setOffline(false);
      },
      () => setOffline(true),
    );
    return unsub;
  }, [lotId]);

  // ── RTDB Sensor listener (live overrides)
  useEffect(() => {
    if (!lotId) return;
    const sensorsRef = ref(rtdb, 'sensor_slots');
    const unsub = onValue(sensorsRef, (snap) => {
        const data = snap.val() || {};
        // Filter RTDB sensors that belong to this lot
        const lotSensors = {};
        Object.keys(data).forEach(sensorId => {
            const s = data[sensorId];
            const parts = sensorId.split('_');
            const sidLotId = s.lotId || s.parkingLocationId || (parts.length > 1 ? parts[0] : '');
            
            if (sidLotId === lotId) {
                // Determine slot ID. It might be explicitly defined as bay/slotId, or part of the ID string.
                const slotIdStr = s.slotId || s.bay || (parts.length > 1 ? parts.slice(1).join('_') : sensorId);
                lotSensors[slotIdStr] = s;
                // Some sensors are just named identically to the slot ID itself, support that too
                lotSensors[sensorId] = s; 
            }
        });
        setSensorData(lotSensors);
    });
    return () => unsub();
  }, [lotId]);

  // ── Combine Firestore Base Data + RTDB Live Status
  useEffect(() => {
    if (fsSlots.length === 0) return;

    const merged = fsSlots.map(s => {
        // Find matching sensor
        // Try strict ID match, or match by bay field if present
        const sensor = sensorData[s.id] || sensorData[s.bay];
        
        let isTaken = s.taken === true || s.isOccupied === true; // Base Firestore status

        // Override if live RTDB sensor data exists
        if (sensor && typeof sensor.taken === 'boolean') {
            isTaken = sensor.taken;
        }

        return { ...s, status: isTaken ? 'occupied' : 'available' };
    });

    // Detect changes
    const changes = new Map();
    merged.forEach(s => {
      const prev = prevSlots.current.get(s.id);
      if (prev) {
        if (prev === 'occupied' && s.status === 'available') changes.set(s.id, 'freed');
        if (prev === 'available' && s.status === 'occupied') changes.set(s.id, 'taken');
      }
    });

    // Update prev mapping
    const m = new Map();
    merged.forEach(s => m.set(s.id, s.status));
    prevSlots.current = m;

    setSlots(merged);
    setLoading(false);
    if (changes.size > 0) setChangedSlots(changes);

  }, [fsSlots, sensorData]);

  // Clear change animations after 3s
  useEffect(() => {
    if (changedSlots.size === 0) return;
    const t = setTimeout(() => setChangedSlots(new Map()), 3500);
    return () => clearTimeout(t);
  }, [changedSlots]);

  // ── Derived data (calculated every render to ensure sync with `slots`)
  const floors = groupByFloor(slots);
  const totalFree = slots.filter(s => s.status === 'available').length;
  const totalOcc = slots.filter(s => s.status === 'occupied').length;
  const pct = slots.length ? Math.round((totalOcc / slots.length) * 100) : 0;

  return { lot, slots, floors, totalFree, totalOcc, pct, loading, offline, changedSlots };
}

function groupByFloor(slots) {
  const map = {};
  slots.forEach(s => {
    const f = s.floor ?? s.floorIndex ?? 0;
    const label = s.floorName ?? (f === 0 ? 'Ground Floor' : f > 0 ? `Floor ${f}` : `Basement ${Math.abs(f)}`);
    if (!map[f]) map[f] = { index: f, label, slots: [], free: 0, total: 0 };
    map[f].slots.push(s);
    map[f].total++;
    if (s.status === 'available') map[f].free++;
  });
  return Object.values(map).sort((a, b) => a.index - b.index);
}
