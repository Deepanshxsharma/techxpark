import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Clock, ShieldCheck, CheckCircle, User, MapPin, Terminal,
  Gauge, CircleDot, Truck, Flag, Package
} from 'lucide-react';
import { useDemo } from '../context/DemoContext';
import TrackingAnimation from '../components/TrackingAnimation';

// ── Step configuration with icons ───────────────────────
const STEPS = [
  { id: 'Queued',      label: 'Queued',      desc: 'Request received',     icon: Package,    color: '#3B82F6' },
  { id: 'Assigned',    label: 'Assigned',    desc: 'Valet assigned',       icon: User,       color: '#6366F1' },
  { id: 'In Process',  label: 'In Process',  desc: 'Retrieving vehicle',   icon: Truck,      color: '#8B5CF6' },
  { id: 'Arriving',    label: 'Arriving',    desc: 'Approaching pickup',   icon: CircleDot,  color: '#F59E0B' },
  { id: 'Ready',       label: 'Ready',       desc: 'Vehicle arrived',      icon: Flag,       color: '#22C55E' },
];

// ── Status badge colors ─────────────────────────────────
const STATUS_BADGES = {
  'Queued':      'bg-blue-500/15 text-blue-400 border-blue-500/30',
  'Assigned':    'bg-indigo-500/15 text-indigo-400 border-indigo-500/30',
  'In Process':  'bg-purple-500/15 text-purple-400 border-purple-500/30',
  'Arriving':    'bg-amber-500/15 text-amber-400 border-amber-500/30',
  'Ready':       'bg-emerald-500/15 text-emerald-400 border-emerald-500/30',
};

export default function TrackingPage() {
  const { requestId } = useParams();
  const navigate = useNavigate();
  const { requests, logs, markCompleted } = useDemo();
  const [lastUpdated, setLastUpdated] = useState('just now');
  const [showLogs, setShowLogs] = useState(false);

  const request = requests.find(r => r.id === requestId);

  // "Last updated" ticker
  useEffect(() => {
    const interval = setInterval(() => {
      if (!request) return;
      const secsAgo = Math.floor((Date.now() - request.createdAt) / 1000);
      if (secsAgo < 5) setLastUpdated('just now');
      else if (secsAgo < 60) setLastUpdated(`${secsAgo}s ago`);
      else setLastUpdated(`${Math.floor(secsAgo / 60)}m ago`);
    }, 1000);
    return () => clearInterval(interval);
  }, [request]);

  // ── Not found ─────────────────────────────────────────
  if (!request) {
    return (
      <div className="min-h-screen bg-[#0A0F1E] flex flex-col items-center justify-center p-6 text-white font-poppins">
        <p className="text-xl text-slate-400">Request not found or expired.</p>
        <button onClick={() => navigate('/')} className="mt-6 text-indigo-400 hover:text-indigo-300 transition-colors">Go Home</button>
      </div>
    );
  }

  // ── Derived state ─────────────────────────────────────
  const m = Math.floor(request.remainingSecs / 60);
  const s = request.remainingSecs % 60;
  const isReady = request.status === 'Ready';
  const isCompleted = request.status === 'Completed';
  const isMoving = request.status === 'In Process' || request.status === 'Arriving';
  const isUrgent = !isReady && request.remainingSecs < 60;
  const timerColor = isReady ? 'text-emerald-400' : isUrgent ? 'text-orange-400' : 'text-indigo-400';
  const currentStepIndex = STEPS.findIndex(st => st.id === request.status);
  const vehicleLogs = logs.filter(l => l.message.includes(request.vehicleNumber));

  // ── Completed state ───────────────────────────────────
  if (isCompleted) {
    return (
      <div className="min-h-screen bg-[#0A0F1E] flex flex-col items-center justify-center p-6 text-white font-poppins relative overflow-hidden">
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_50%,rgba(34,197,94,0.08),transparent_70%)]" />
        <motion.div initial={{ scale: 0.8, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} className="relative z-10 flex flex-col items-center text-center">
          <div className="w-24 h-24 bg-emerald-500/15 text-emerald-400 rounded-full flex items-center justify-center mb-6 ring-2 ring-emerald-500/20">
            <CheckCircle size={48} />
          </div>
          <h1 className="text-4xl font-bold mb-3">Journey Complete</h1>
          <p className="text-slate-400 mb-10">Thank you for visiting Godrej BKC.</p>
          <button onClick={() => navigate('/')} className="bg-slate-800 hover:bg-slate-700 text-white px-8 py-4 rounded-xl font-semibold transition-all border border-slate-700/50">
            Return Home
          </button>
        </motion.div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0A0F1E] flex flex-col font-poppins text-white relative overflow-hidden">

      {/* ── Deep background with gradient + grid ──────── */}
      <div className="absolute inset-0 pointer-events-none">
        {/* Radial gradient center glow */}
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_50%_0%,rgba(99,102,241,0.08),transparent_60%)]" />
        {/* Subtle grid texture */}
        <div className="absolute inset-0 opacity-[0.03]" style={{
          backgroundImage: 'linear-gradient(rgba(255,255,255,0.05) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.05) 1px, transparent 1px)',
          backgroundSize: '40px 40px'
        }} />
        {/* Ambient orbs */}
        <div className="absolute top-20 left-1/4 w-[500px] h-[500px] bg-indigo-600/5 rounded-full blur-3xl animate-pulse" style={{ animationDuration: '5s' }} />
        <div className="absolute bottom-40 right-1/5 w-[400px] h-[400px] bg-emerald-500/4 rounded-full blur-3xl animate-pulse" style={{ animationDuration: '7s' }} />
        {/* Vignette */}
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_50%_50%,transparent_50%,rgba(10,15,30,0.6)_100%)]" />
      </div>

      {/* ═══════════════ TOP BAR ══════════════════════ */}
      <div className="relative z-10 flex items-center justify-between px-5 pt-5 pb-2">
        {/* LIVE badge */}
        <div className="flex items-center gap-2 bg-slate-800/60 backdrop-blur-md px-3 py-1.5 rounded-full border border-slate-700/40">
          <div className="relative">
            <div className="w-2 h-2 rounded-full bg-emerald-400" />
            <div className="absolute inset-0 w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
          </div>
          <span className="text-[10px] font-bold text-emerald-400 uppercase tracking-[0.2em]">Live</span>
        </div>

        <span className="text-[10px] text-slate-600 font-medium tracking-wide">
          Updated {lastUpdated}
        </span>

        <button
          onClick={() => setShowLogs(!showLogs)}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full border text-[10px] font-bold uppercase tracking-[0.15em] transition-all ${
            showLogs
              ? 'bg-indigo-500/15 border-indigo-500/40 text-indigo-400'
              : 'bg-slate-800/60 border-slate-700/40 text-slate-500 hover:text-slate-300 hover:border-slate-600/60'
          }`}
        >
          <Terminal size={11} />
          Logs
        </button>
      </div>

      {/* ═══════════════ ANIMATION AREA ══════════════ */}
      <div className="relative z-10 px-4 pt-3 pb-4">
        <div className="relative rounded-2xl overflow-hidden border border-slate-700/30 bg-gradient-to-b from-slate-800/40 to-slate-900/60 backdrop-blur-sm shadow-2xl shadow-black/20">
          {/* Glassmorphism inner glow */}
          <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/5 via-transparent to-emerald-500/3 pointer-events-none" />
          {/* Vignette inside animation */}
          <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_50%_50%,transparent_40%,rgba(10,15,30,0.4)_100%)] pointer-events-none" />

          {/* Label */}
          <div className="relative z-10 flex items-center justify-center gap-2 pt-4 pb-1">
            <Gauge size={13} className="text-indigo-400" />
            <span className="text-[10px] font-bold text-indigo-400/80 uppercase tracking-[0.2em]">Live Vehicle Movement</span>
          </div>

          {/* The animation component */}
          <div className="relative z-10 px-3 pb-4">
            <TrackingAnimation status={request.status} progress={request.progress} />
          </div>
        </div>
      </div>

      {/* ═══════════════ CONTENT AREA ════════════════ */}
      <div className="flex-1 relative z-10 rounded-t-[28px] border-t border-slate-700/30 bg-[#0D1225]/95 backdrop-blur-md p-5 flex flex-col">

        {/* ── ETA Hero ────────────────────────────────── */}
        <div className="text-center mb-5">
          {isReady ? (
            <motion.div initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }}>
              <h1 className="text-3xl font-bold text-emerald-400 mb-1">Vehicle is Ready!</h1>
              <p className="text-emerald-400/50 text-sm">Please proceed to the pickup point</p>
            </motion.div>
          ) : (
            <>
              <p className="text-slate-600 font-semibold mb-1 uppercase tracking-[0.2em] text-[10px] flex items-center justify-center gap-1.5">
                <Clock size={11} /> Estimated Arrival
              </p>
              <motion.div
                key={request.remainingSecs}
                initial={{ opacity: 0.7, scale: 0.98 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.3 }}
                className={`text-5xl font-bold tracking-tight font-mono ${timerColor} tabular-nums`}
              >
                {m}:{s.toString().padStart(2, '0')}
              </motion.div>
            </>
          )}
        </div>

        {/* ── Vehicle Info Card ───────────────────────── */}
        <div className="bg-slate-800/40 backdrop-blur-sm border border-slate-700/30 rounded-2xl p-4 mb-5">
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-xl font-bold font-mono tracking-wider text-white">{request.vehicleNumber}</h3>
            <span className={`text-[11px] font-bold px-3 py-1 rounded-full border ${STATUS_BADGES[request.status] || STATUS_BADGES['Queued']}`}>
              {request.status}
            </span>
          </div>
          <div className="grid grid-cols-3 gap-3">
            <div className="bg-slate-900/50 rounded-xl p-2.5 text-center border border-slate-800/50">
              <p className="text-[9px] text-slate-600 uppercase tracking-wider font-bold mb-0.5">Slot</p>
              <p className="text-sm font-bold text-white flex items-center justify-center gap-1">
                <MapPin size={11} className="text-indigo-400" />{request.slot}
              </p>
            </div>
            <div className="bg-slate-900/50 rounded-xl p-2.5 text-center border border-slate-800/50">
              <p className="text-[9px] text-slate-600 uppercase tracking-wider font-bold mb-0.5">Valet</p>
              <p className="text-sm font-bold text-white flex items-center justify-center gap-1">
                <User size={11} className="text-indigo-400" />{request.valetAssigned?.split(' ')[0] || '—'}
              </p>
            </div>
            <div className="bg-slate-900/50 rounded-xl p-2.5 text-center border border-slate-800/50">
              <p className="text-[9px] text-slate-600 uppercase tracking-wider font-bold mb-0.5">Progress</p>
              <p className={`text-sm font-bold font-mono tabular-nums ${isReady ? 'text-emerald-400' : 'text-indigo-400'}`}>
                {Math.round(request.progress)}%
              </p>
            </div>
          </div>

          {/* Progress bar integrated inside info card */}
          <div className="mt-3">
            <div className="h-1.5 bg-slate-900/80 rounded-full overflow-hidden">
              <motion.div
                className="h-full rounded-full"
                style={{
                  background: isReady
                    ? 'linear-gradient(90deg, #22C55E, #4ADE80)'
                    : 'linear-gradient(90deg, #6366F1, #818CF8, #A5B4FC)',
                }}
                initial={false}
                animate={{ width: `${request.progress}%` }}
                transition={{ duration: 1, ease: 'easeOut' }}
              />
            </div>
          </div>
        </div>

        {/* ── 5-Step Stepper ──────────────────────────── */}
        <div className="w-full max-w-md mx-auto mb-5">
          <div className="relative">
            {/* Vertical connecting line */}
            <div className="absolute left-[17px] top-5 bottom-5 w-[2px] bg-slate-800/80" />

            <div className="space-y-3">
              {STEPS.map((step, index) => {
                const isPast = index < currentStepIndex;
                const isCurrent = index === currentStepIndex;
                const isFuture = index > currentStepIndex;
                const StepIcon = step.icon;

                return (
                  <motion.div
                    key={step.id}
                    initial={false}
                    animate={{
                      opacity: isFuture ? 0.25 : 1,
                      x: isCurrent ? 4 : 0,
                    }}
                    transition={{ duration: 0.4, ease: 'easeOut' }}
                    className="relative flex items-center gap-4 pl-11"
                  >
                    {/* Node circle */}
                    <div
                      className="absolute left-0 w-9 h-9 rounded-full flex items-center justify-center border-2 transition-all duration-500"
                      style={{
                        borderColor: isPast || isCurrent ? step.color : '#1E293B',
                        backgroundColor: isPast ? step.color : '#0A0F1E',
                        boxShadow: isCurrent ? `0 0 16px ${step.color}40` : 'none',
                      }}
                    >
                      {isPast ? (
                        <CheckCircle className="w-4 h-4 text-white" />
                      ) : isCurrent ? (
                        <motion.div
                          animate={{ scale: [1, 1.4, 1], opacity: [1, 0.5, 1] }}
                          transition={{ repeat: Infinity, duration: 2 }}
                        >
                          <StepIcon className="w-4 h-4" style={{ color: step.color }} />
                        </motion.div>
                      ) : (
                        <StepIcon className="w-3.5 h-3.5 text-slate-700" />
                      )}
                    </div>

                    {/* Text */}
                    <div>
                      <h4 className={`font-bold text-sm ${isCurrent ? 'text-white' : isPast ? 'text-slate-300' : 'text-slate-600'}`}>
                        {step.label}
                        {isCurrent && step.id === 'Assigned' && request.valetAssigned && (
                          <span className="ml-2 text-xs font-normal text-indigo-400">— {request.valetAssigned}</span>
                        )}
                      </h4>
                      <p className="text-[11px] text-slate-600">{step.desc}</p>
                    </div>
                  </motion.div>
                );
              })}
            </div>
          </div>
        </div>

        {/* ── System Logs ─────────────────────────────── */}
        <AnimatePresence>
          {showLogs && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              className="overflow-hidden mb-5"
            >
              <div className="bg-[#080C18] border border-slate-800/60 rounded-xl p-4 font-mono text-xs max-h-44 overflow-y-auto">
                <div className="flex items-center gap-2 mb-3">
                  <Terminal size={12} className="text-indigo-400" />
                  <span className="text-indigo-400/80 font-bold text-[10px] uppercase tracking-[0.2em]">System Log — {request.vehicleNumber}</span>
                </div>
                {vehicleLogs.length === 0 ? (
                  <p className="text-slate-700">Waiting for events…</p>
                ) : (
                  vehicleLogs.map((log, i) => (
                    <motion.div
                      key={i}
                      initial={{ opacity: 0, x: -10 }}
                      animate={{ opacity: 1, x: 0 }}
                      transition={{ delay: i * 0.05 }}
                      className="flex gap-3 py-1.5 text-slate-500 border-b border-slate-800/30 last:border-0"
                    >
                      <span className="text-slate-700 shrink-0 tabular-nums">
                        [{new Date(log.ts).toLocaleTimeString('en-IN', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' })}]
                      </span>
                      <span className="text-slate-400">{log.message}</span>
                    </motion.div>
                  ))
                )}
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* ── Action Button ───────────────────────────── */}
        <div className="mt-auto">
          <button
            onClick={() => markCompleted(request.id)}
            className={`w-full font-semibold py-4 rounded-xl shadow-lg transition-all active:scale-[0.98] flex items-center justify-center text-lg gap-2.5 border ${
              isReady
                ? 'bg-emerald-600 hover:bg-emerald-500 text-white shadow-emerald-500/15 border-emerald-500/30'
                : 'bg-indigo-600 hover:bg-indigo-500 text-white shadow-indigo-500/15 border-indigo-500/30'
            }`}
          >
            <ShieldCheck size={22} />
            {isReady ? 'Collect Vehicle' : 'Car Received'}
          </button>
        </div>
      </div>
    </div>
  );
}
