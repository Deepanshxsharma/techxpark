/**
 * useSimulation — State-driven vehicle retrieval simulation engine
 * 
 * Manages the full lifecycle of vehicle requests with randomized timings,
 * valet assignment, progress tracking, and system event logging.
 * 
 * Each vehicle transitions through:
 *   QUEUED → ASSIGNED → IN_PROCESS → ARRIVING → READY
 */
import { useState, useEffect, useCallback, useRef } from 'react';

// ── Valet Pool ──────────────────────────────────────────
const VALET_NAMES = [
  'Ravi Kumar', 'Amit Singh', 'Priya Sharma',
  'Vikram Rao', 'Sunil Verma', 'Deepak Joshi',
  'Rahul Nair', 'Karan Patel'
];

// ── Demo vehicle database ───────────────────────────────
const DEMO_VEHICLES = [
  { vehicle: 'MH01AB1234', phone: '9999999991', slot: 'A-12' },
  { vehicle: 'MH02CD5678', phone: '9999999992', slot: 'B-07' },
  { vehicle: 'MH03EF9012', phone: '9999999993', slot: 'C-03' },
  { vehicle: 'MH04GH3456', phone: '9999999994', slot: 'A-18' },
  { vehicle: 'MH05IJ7890', phone: '9999999995', slot: 'B-22' }
];

// ── Lifecycle phase durations (seconds) ─────────────────
// Each phase gets a random duration within this range.
const PHASE_DURATIONS = {
  QUEUED:     { min: 3,  max: 6  },
  ASSIGNED:   { min: 4,  max: 8  },
  IN_PROCESS: { min: 10, max: 20 },
  ARRIVING:   { min: 5,  max: 10 },
};

const STATUS_ORDER = ['Queued', 'Assigned', 'In Process', 'Arriving', 'Ready'];

function randBetween(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function pickRandom(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function generatePhaseTimeline() {
  const queued    = randBetween(PHASE_DURATIONS.QUEUED.min, PHASE_DURATIONS.QUEUED.max);
  const assigned  = randBetween(PHASE_DURATIONS.ASSIGNED.min, PHASE_DURATIONS.ASSIGNED.max);
  const inProcess = randBetween(PHASE_DURATIONS.IN_PROCESS.min, PHASE_DURATIONS.IN_PROCESS.max);
  const arriving  = randBetween(PHASE_DURATIONS.ARRIVING.min, PHASE_DURATIONS.ARRIVING.max);

  return {
    Queued:       0,
    Assigned:     queued,
    'In Process': queued + assigned,
    Arriving:     queued + assigned + inProcess,
    Ready:        queued + assigned + inProcess + arriving,
  };
}

function formatLogTime(ts) {
  const d = new Date(ts);
  return d.toLocaleTimeString('en-IN', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

// ── Ding sound (tiny base64 sine wave) ──────────────────
const DING_AUDIO_SRC = 'data:audio/wav;base64,UklGRl9vT19teleXRlZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQ==';

function playDing() {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(880, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(1320, ctx.currentTime + 0.08);
    gain.gain.setValueAtTime(0.3, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.5);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.5);
  } catch (_) { /* ignore audio failures silently */ }
}

// ── The Hook ────────────────────────────────────────────
export default function useSimulation() {
  const [requests, setRequests] = useState(() => {
    try {
      const saved = localStorage.getItem('godrejSimRequests');
      return saved ? JSON.parse(saved) : [];
    } catch { return []; }
  });

  const [logs, setLogs] = useState([]);
  const [rushMode, setRushMode] = useState(false);
  const readyFiredRef = useRef(new Set());

  // ── Persist to localStorage ───────────────────────────
  useEffect(() => {
    localStorage.setItem('godrejSimRequests', JSON.stringify(requests));
  }, [requests]);

  // ── Cross-tab sync for Kiosk ──────────────────────────
  useEffect(() => {
    const handler = (e) => {
      if (e.key === 'godrejSimRequests' && e.newValue) {
        try { setRequests(JSON.parse(e.newValue)); } catch {}
      }
    };
    window.addEventListener('storage', handler);
    return () => window.removeEventListener('storage', handler);
  }, []);

  // ── Add a log entry ───────────────────────────────────
  const addLog = useCallback((message) => {
    const entry = { ts: Date.now(), message };
    setLogs(prev => [entry, ...prev].slice(0, 50));
  }, []);

  // ── Master tick (1 Hz) ────────────────────────────────
  useEffect(() => {
    const interval = setInterval(() => {
      setRequests(prev => {
        const now = Date.now();
        let changed = false;
        const multiplier = rushMode ? 3 : 1;

        const updated = prev.map(req => {
          if (req.status === 'Ready' || req.status === 'Completed') return req;

          const elapsedSecs = Math.floor((now - req.createdAt) / 1000) * multiplier;

          // Determine current phase
          let newStatus = req.status;
          const tl = req.timeline;
          if (elapsedSecs >= tl.Ready)          newStatus = 'Ready';
          else if (elapsedSecs >= tl.Arriving)  newStatus = 'Arriving';
          else if (elapsedSecs >= tl['In Process']) newStatus = 'In Process';
          else if (elapsedSecs >= tl.Assigned)  newStatus = 'Assigned';
          else                                  newStatus = 'Queued';

          // Calculate progress (0 → 100)
          // Progress only advances during In Process and Arriving phases
          let progress = 0;
          if (newStatus === 'Queued' || newStatus === 'Assigned') {
            progress = 0;
          } else if (newStatus === 'In Process') {
            const phaseStart = tl['In Process'];
            const phaseEnd = tl.Arriving;
            const phaseElapsed = elapsedSecs - phaseStart;
            const phaseDuration = phaseEnd - phaseStart;
            progress = Math.min(70, (phaseElapsed / phaseDuration) * 70); // 0 → 70%
          } else if (newStatus === 'Arriving') {
            const phaseStart = tl.Arriving;
            const phaseEnd = tl.Ready;
            const phaseElapsed = elapsedSecs - phaseStart;
            const phaseDuration = phaseEnd - phaseStart;
            progress = 70 + Math.min(30, (phaseElapsed / phaseDuration) * 30); // 70 → 100%
          } else if (newStatus === 'Ready') {
            progress = 100;
          }

          // Calculate remaining ETA
          const totalDuration = tl.Ready;
          const newRemaining = Math.max(0, totalDuration - elapsedSecs);

          if (newStatus !== req.status || Math.abs(progress - req.progress) > 0.5 || newRemaining !== req.remainingSecs) {
            changed = true;

            // Log status transitions
            if (newStatus !== req.status) {
              const logMessages = {
                'Assigned':   `Valet ${req.valetAssigned} assigned to ${req.vehicleNumber}`,
                'In Process': `Vehicle ${req.vehicleNumber} picked from slot ${req.slot}`,
                'Arriving':   `${req.vehicleNumber} approaching pickup point`,
                'Ready':      `✅ ${req.vehicleNumber} is ready for collection`
              };
              if (logMessages[newStatus]) {
                // Use setTimeout to avoid state update during render
                setTimeout(() => addLog(logMessages[newStatus]), 0);
              }

              // Play ding on Ready
              if (newStatus === 'Ready' && !readyFiredRef.current.has(req.id)) {
                readyFiredRef.current.add(req.id);
                setTimeout(() => playDing(), 200);
              }
            }

            return { ...req, status: newStatus, progress: Math.round(progress * 10) / 10, remainingSecs: newRemaining };
          }
          return req;
        });

        return changed ? updated : prev;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, [rushMode, addLog]);

  // ── Create a new request ──────────────────────────────
  const createRequest = useCallback((searchTerm) => {
    const clean = searchTerm.trim().toUpperCase();
    const vehicleObj = DEMO_VEHICLES.find(v =>
      v.vehicle.toUpperCase() === clean || v.phone === clean
    );

    if (!vehicleObj) {
      throw new Error('Vehicle not found in demo data. Try MH01AB1234 or 9999999991');
    }

    const timeline = generatePhaseTimeline();
    const totalEtaSecs = timeline.Ready;
    const valet = pickRandom(VALET_NAMES);

    const newReq = {
      id: Math.random().toString(36).substring(2, 9),
      vehicleNumber: vehicleObj.vehicle,
      phone: vehicleObj.phone,
      slot: vehicleObj.slot,
      status: 'Queued',
      progress: 0,
      valetAssigned: valet,
      initialEtaSecs: totalEtaSecs,
      remainingSecs: totalEtaSecs,
      timeline,
      createdAt: Date.now(),
    };

    setRequests(prev => [...prev, newReq]);
    addLog(`New request: ${vehicleObj.vehicle} from slot ${vehicleObj.slot}`);
    return newReq.id;
  }, [addLog]);

  // ── Mark completed ────────────────────────────────────
  const markCompleted = useCallback((id) => {
    setRequests(prev => prev.map(r =>
      r.id === id ? { ...r, status: 'Completed', progress: 100, remainingSecs: 0 } : r
    ));
    const req = requests.find(r => r.id === id);
    if (req) addLog(`${req.vehicleNumber} collected — session closed`);
  }, [requests, addLog]);

  // ── Clear all ─────────────────────────────────────────
  const clearAll = useCallback(() => {
    setRequests([]);
    setLogs([]);
    readyFiredRef.current.clear();
    addLog('System reset — all requests cleared');
  }, [addLog]);

  // ── Toggle rush mode ──────────────────────────────────
  const toggleRushMode = useCallback(() => {
    setRushMode(prev => !prev);
  }, []);

  return {
    requests,
    logs,
    rushMode,
    createRequest,
    markCompleted,
    clearAll,
    toggleRushMode,
    DEMO_VEHICLES,
  };
}
