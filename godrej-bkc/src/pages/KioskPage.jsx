import React from 'react';
import { useDemo } from '../context/DemoContext';
import { CarFront, Clock, CheckCircle, User, Zap } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import TrackingAnimation from '../components/TrackingAnimation';

export default function KioskPage() {
  const { requests, rushMode, toggleRushMode } = useDemo();

  const activeRequests = requests
    .filter(r => r.status !== 'Completed')
    .sort((a, b) => a.remainingSecs - b.remainingSecs);

  return (
    <div className="min-h-screen bg-slate-900 text-white font-poppins flex flex-col md:flex-row overflow-hidden">
      
      {/* ── Left Panel: Branding + QR ────────────────── */}
      <div className="w-full md:w-1/3 bg-slate-800 p-10 flex flex-col justify-between border-r border-slate-700 z-10 shadow-2xl relative">
        <div className="absolute top-0 right-0 w-64 h-64 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none" />
        
        <div>
          <div className="flex items-center gap-4 mb-8">
            <div className="w-16 h-16 rounded-2xl bg-indigo-600 flex items-center justify-center shadow-lg shadow-indigo-500/20">
              <CarFront size={32} className="text-white" />
            </div>
            <h1 className="text-3xl font-bold tracking-tight">Godrej BKC</h1>
          </div>
          
          <h2 className="text-4xl font-extrabold mb-4 leading-tight">
            Smart Vehicle <br/>Retrieval List
          </h2>
          <p className="text-xl text-slate-400 mb-6">Scan the code or visit the portal to request your car.</p>

          {/* Rush mode toggle */}
          <button
            onClick={toggleRushMode}
            className={`flex items-center gap-2 px-4 py-2 rounded-full text-sm font-bold transition-all ${
              rushMode
                ? 'bg-orange-500/20 text-orange-400 border border-orange-500/40'
                : 'bg-slate-700 text-slate-400 border border-slate-600 hover:text-slate-200'
            }`}
          >
            <Zap size={16} />
            {rushMode ? 'Rush Mode ON' : 'Rush Mode'}
          </button>
        </div>

        <div className="bg-white p-6 rounded-3xl w-full max-w-xs mx-auto shadow-2xl transition-transform hover:scale-105">
          <img 
            src="https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=https://app.com" 
            alt="QR Code" 
            className="w-full h-auto rounded-xl"
          />
          <p className="text-slate-900 font-bold text-center mt-4">app.com</p>
        </div>
      </div>

      {/* ── Right Panel: Live Queue ──────────────────── */}
      <div className="w-full md:w-2/3 p-10 flex flex-col h-screen relative">
        <div className="absolute bottom-0 left-0 w-[500px] h-[500px] bg-emerald-500/5 rounded-full blur-3xl pointer-events-none" />

        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <h3 className="text-2xl font-bold flex items-center gap-3">
            <Clock className="text-indigo-400" /> Live Queue
            {/* LIVE badge */}
            <div className="flex items-center gap-1.5 ml-3 bg-slate-800 px-3 py-1 rounded-full border border-slate-700">
              <div className="relative">
                <div className="w-2 h-2 rounded-full bg-emerald-400" />
                <div className="absolute inset-0 w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
              </div>
              <span className="text-[11px] font-bold text-emerald-400 uppercase tracking-widest">Live</span>
            </div>
          </h3>

          <div className="flex items-center gap-4 text-sm font-medium">
            <span className="flex items-center gap-2"><div className="w-3 h-3 rounded-full bg-indigo-500"></div> Active</span>
            <span className="flex items-center gap-2"><div className="w-3 h-3 rounded-full bg-emerald-500 animate-pulse"></div> Ready</span>
          </div>
        </div>

        {/* Queue List */}
        <div className="flex-1 overflow-y-auto space-y-4 pr-4 custom-scrollbar">
          <AnimatePresence>
            {activeRequests.length === 0 ? (
              <motion.div 
                initial={{ opacity: 0 }} animate={{ opacity: 1 }}
                className="w-full h-64 flex flex-col items-center justify-center text-slate-500 border-2 border-dashed border-slate-700 rounded-3xl"
              >
                <CarFront size={48} className="mb-4 opacity-50" />
                <p className="text-xl font-medium">Queue is empty</p>
              </motion.div>
            ) : (
              activeRequests.map(req => {
                const isReady = req.status === 'Ready';
                const m = Math.floor(req.remainingSecs / 60);
                const s = req.remainingSecs % 60;
                const minStr = m > 0 ? `${m}m ` : '';
                const secStr = `${s.toString().padStart(2, '0')}s`;

                // Status badge color
                const badgeColors = {
                  'Queued':      'bg-slate-700 text-slate-300',
                  'Assigned':    'bg-indigo-500/20 text-indigo-400',
                  'In Process':  'bg-purple-500/20 text-purple-400',
                  'Arriving':    'bg-amber-500/20 text-amber-400',
                  'Ready':       'bg-emerald-500/20 text-emerald-400',
                };

                return (
                  <motion.div 
                    key={req.id}
                    layout
                    initial={{ opacity: 0, x: 20 }}
                    animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0, scale: 0.95 }}
                    transition={{ duration: 0.4 }}
                    className="bg-slate-800 border border-slate-700/50 rounded-2xl p-5 shadow-xl"
                  >
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center gap-4">
                        <div className="bg-slate-900 px-4 py-2 rounded-lg border border-slate-700 shadow-inner">
                          <span className="text-xl font-bold font-mono tracking-wider">{req.vehicleNumber}</span>
                        </div>
                        <div>
                          <span className={`inline-block px-3 py-1 rounded-full text-xs font-bold ${badgeColors[req.status] || 'bg-slate-700 text-slate-300'}`}>
                            {req.status}
                          </span>
                          <p className="text-slate-500 text-sm mt-1 flex items-center gap-1">
                            <User size={12} /> {req.valetAssigned || '—'} · Slot {req.slot}
                          </p>
                        </div>
                      </div>

                      <div className="text-right">
                        {isReady ? (
                          <div className="flex items-center gap-2 text-emerald-400 bg-emerald-500/10 px-5 py-2 rounded-full font-bold text-lg">
                            <CheckCircle size={22} />
                            COLLECT
                          </div>
                        ) : (
                          <div className="flex flex-col items-end">
                            <span className="text-slate-500 text-[10px] font-semibold uppercase tracking-wider mb-0.5">ETA</span>
                            <span className="text-3xl font-bold font-mono tracking-tight text-white tabular-nums">
                              {minStr}{secStr}
                            </span>
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Mini tracking animation */}
                    <TrackingAnimation status={req.status} progress={req.progress} mini={true} />
                  </motion.div>
                );
              })
            )}
          </AnimatePresence>
        </div>
      </div>
    </div>
  );
}
