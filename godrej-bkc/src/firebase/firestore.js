import { db } from './config';
import {
  collection, doc, getDoc, getDocs, addDoc, updateDoc, deleteDoc,
  query, where, orderBy, onSnapshot, serverTimestamp, Timestamp,
  limit, writeBatch
} from 'firebase/firestore';

// ─── Collection References ────────────────────────
export const zonesRef = collection(db, 'godrej_zones');
export const liftersRef = collection(db, 'godrej_lifters');
export const requestsRef = collection(db, 'godrej_requests');
export const employeesRef = collection(db, 'godrej_employees');
export const notificationsRef = collection(db, 'godrej_notifications');
export const settingsRef = collection(db, 'godrej_settings');

// ─── Zones ────────────────────────────────────────
export const getZones = async () => {
  const snap = await getDocs(zonesRef);
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

export const getZone = async (zoneId) => {
  const snap = await getDoc(doc(db, 'godrej_zones', zoneId));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
};

export const updateZone = async (zoneId, data) => {
  await updateDoc(doc(db, 'godrej_zones', zoneId), {
    ...data,
    updatedAt: serverTimestamp()
  });
};

export const subscribeToZones = (callback) => {
  return onSnapshot(zonesRef, (snap) => {
    callback(snap.docs.map(d => ({ id: d.id, ...d.data() })));
  });
};

// ─── Lifters ──────────────────────────────────────
export const getLiftersByZone = async (zoneId) => {
  const q = query(liftersRef, where('zoneId', '==', zoneId));
  const snap = await getDocs(q);
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

export const updateLifter = async (lifterId, data) => {
  await updateDoc(doc(db, 'godrej_lifters', lifterId), {
    ...data,
    lastUpdated: serverTimestamp()
  });
};

export const subscribeToLifters = (zoneId, callback) => {
  const q = query(liftersRef, where('zoneId', '==', zoneId));
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map(d => ({ id: d.id, ...d.data() })));
  });
};

export const subscribeToAllLifters = (callback) => {
  return onSnapshot(liftersRef, (snap) => {
    callback(snap.docs.map(d => ({ id: d.id, ...d.data() })));
  });
};

// ─── Requests ─────────────────────────────────────
export const getRequest = async (requestId) => {
  const snap = await getDoc(doc(db, 'godrej_requests', requestId));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
};

export const subscribeToRequest = (requestId, callback) => {
  return onSnapshot(doc(db, 'godrej_requests', requestId), (snap) => {
    if (snap.exists()) {
      callback({ id: snap.id, ...snap.data() });
    }
  });
};

export const subscribeToActiveRequests = (zoneId, callback) => {
  const q = query(
    requestsRef,
    where('zoneId', '==', zoneId),
    where('status', 'in', ['queued', 'in_process', 'ready']),
    orderBy('requestedAt', 'asc')
  );
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map(d => ({ id: d.id, ...d.data() })));
  });
};

export const subscribeToAllActiveRequests = (callback) => {
  const q = query(
    requestsRef,
    where('status', 'in', ['queued', 'in_process', 'ready']),
    orderBy('requestedAt', 'asc')
  );
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map(d => ({ id: d.id, ...d.data() })));
  });
};

export const getRecentRequests = async (limitCount = 20) => {
  const q = query(requestsRef, orderBy('requestedAt', 'desc'), limit(limitCount));
  const snap = await getDocs(q);
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

export const subscribeToRecentRequests = (limitCount, callback) => {
  const q = query(requestsRef, orderBy('requestedAt', 'desc'), limit(limitCount));
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map(d => ({ id: d.id, ...d.data() })));
  });
};

export const getRequestsByDateRange = async (startDate, endDate) => {
  const q = query(
    requestsRef,
    where('requestedAt', '>=', Timestamp.fromDate(startDate)),
    where('requestedAt', '<=', Timestamp.fromDate(endDate)),
    orderBy('requestedAt', 'desc')
  );
  const snap = await getDocs(q);
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

export const updateRequest = async (requestId, data) => {
  await updateDoc(doc(db, 'godrej_requests', requestId), data);
};

export const checkDuplicateRequest = async (vehicleNumber) => {
  const q = query(
    requestsRef,
    where('vehicleNumber', '==', vehicleNumber),
    where('status', 'in', ['queued', 'in_process', 'ready'])
  );
  const snap = await getDocs(q);
  if (snap.empty) return null;
  return { id: snap.docs[0].id, ...snap.docs[0].data() };
};

// ─── Employees ────────────────────────────────────
export const getEmployees = async () => {
  const snap = await getDocs(employeesRef);
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

export const getEmployeeByPhone = async (phone) => {
  const q = query(employeesRef, where('phone', '==', phone));
  const snap = await getDocs(q);
  if (snap.empty) return null;
  return { id: snap.docs[0].id, ...snap.docs[0].data() };
};

export const addEmployee = async (data) => {
  return await addDoc(employeesRef, {
    ...data,
    isActive: true,
    totalRequests: 0,
    createdAt: serverTimestamp()
  });
};

export const updateEmployee = async (empId, data) => {
  await updateDoc(doc(db, 'godrej_employees', empId), data);
};

export const deleteEmployee = async (empId) => {
  await deleteDoc(doc(db, 'godrej_employees', empId));
};

// ─── Notifications ────────────────────────────────
export const getNotifications = async (limitCount = 50) => {
  const q = query(notificationsRef, orderBy('sentAt', 'desc'), limit(limitCount));
  const snap = await getDocs(q);
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

export const subscribeToNotifications = (limitCount, callback) => {
  const q = query(notificationsRef, orderBy('sentAt', 'desc'), limit(limitCount));
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map(d => ({ id: d.id, ...d.data() })));
  });
};

// ─── Settings ─────────────────────────────────────
export const getSettings = async () => {
  const snap = await getDoc(doc(db, 'godrej_settings', 'global'));
  return snap.exists() ? snap.data() : null;
};

export const updateSettings = async (data) => {
  await updateDoc(doc(db, 'godrej_settings', 'global'), {
    ...data,
    lastUpdatedAt: serverTimestamp()
  });
};

export const subscribeToSettings = (callback) => {
  return onSnapshot(doc(db, 'godrej_settings', 'global'), (snap) => {
    if (snap.exists()) callback(snap.data());
  });
};

// ─── User Roles ───────────────────────────────────
export const getUserRole = async (uid) => {
  const snap = await getDoc(doc(db, 'users', uid));
  return snap.exists() ? snap.data().role : null;
};

// ─── Utilities ────────────────────────────────────
export { serverTimestamp, Timestamp, writeBatch, doc, db };
