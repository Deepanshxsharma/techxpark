import { useState, useCallback } from 'react';
import { db, rtdb } from '../firebase';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { ref, get, set, serverTimestamp } from 'firebase/database';

export function useSensors(lotId) {
  const [loading, setLoading] = useState(false);

  // Hook to simulate pinging a real-time sensor
  const pingSensor = useCallback(async (sensorId) => {
    setLoading(true);
    try {
      // Create/Read from Realtime DB to simulate IoT response log
      const sensorRef = ref(rtdb, `sensor_slots/${sensorId}`);
      const snapshot = await get(sensorRef);
      
      let statusData;
      if (snapshot.exists()) {
        statusData = snapshot.val();
      } else {
        // Missing hardware context, pretend it works for demo
        statusData = { status: 'offline', battery: 0, signal: 0 };
      }

      setLoading(false);
      return statusData;
    } catch (err) {
      console.error("Ping error:", err);
      setLoading(false);
      throw err;
    }
  }, []);

  // Hook to map a sensor to a Firestore node
  const linkSensorToSlot = useCallback(async (sensorId, slotId) => {
    setLoading(true);
    try {
      // 1. Write the sensor link to firestore slot
      await setDoc(doc(db, `parking_locations/${lotId}/slots`, slotId), {
         sensorId: sensorId
      }, { merge: true });

      // 2. Write to unified sensor map
      await setDoc(doc(db, `slot_sensors/${lotId}`, slotId), {
         sensorId: sensorId
      }, { merge: true });

      setLoading(false);
      return true;
    } catch (err) {
      console.error("Linking error:", err);
      setLoading(false);
      throw err;
    }
  }, [lotId]);

  return { pingSensor, linkSensorToSlot, loading };
}
