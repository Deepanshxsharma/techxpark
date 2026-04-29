import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { MapPin, Car, ChevronRight, Loader2, Building2 } from 'lucide-react';
import { useParking } from '../context/ParkingContext';

/**
 * ParkingSelectionModal — Full-screen overlay for first-time parking location selection.
 * Fetches active locations from Firestore via ParkingContext.
 */
export default function ParkingSelectionModal() {
  const { locations, loading, selectParking } = useParking();
  const [selectedId, setSelectedId] = useState(null);
  const [confirming, setConfirming] = useState(false);

  const handleSelect = (parking) => {
    setSelectedId(parking.id);
    setConfirming(true);

    // Slight delay for micro-interaction feel
    setTimeout(() => {
      selectParking(parking);
    }, 600);
  };

  const getSlotBadge = (loc) => {
    const available = loc.available_slots ?? 0;
    if (available === 0) return { text: 'Full', color: 'bg-red-500/20 text-red-400 border-red-500/30' };
    if (available < 20)  return { text: `${available} left`, color: 'bg-orange-500/20 text-orange-400 border-orange-500/30' };
    return { text: `${available} available`, color: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30' };
  };

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-50 bg-slate-950/95 backdrop-blur-xl flex flex-col items-center justify-center p-6 font-poppins text-white overflow-y-auto"
    >
      {/* Ambient glow */}
      <div className="absolute top-0 left-1/3 w-[400px] h-[400px] bg-indigo-600/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute bottom-0 right-1/4 w-[300px] h-[300px] bg-emerald-500/8 rounded-full blur-3xl pointer-events-none" />

      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.1 }}
        className="relative z-10 text-center mb-10 max-w-lg"
      >
        <div className="mx-auto w-16 h-16 rounded-2xl bg-indigo-600/20 border border-indigo-500/30 flex items-center justify-center mb-5">
          <Building2 size={32} className="text-indigo-400" />
        </div>
        <h1 className="text-3xl md:text-4xl font-bold tracking-tight mb-3">Select Parking Location</h1>
        <p className="text-slate-400 text-lg">Choose your parking facility to continue</p>
      </motion.div>

      {/* Grid */}
      <div className="relative z-10 w-full max-w-3xl">
        {loading ? (
          /* Skeleton loading */
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {[1, 2, 3, 4].map(i => (
              <div key={i} className="bg-slate-800/50 rounded-2xl p-6 animate-pulse border border-slate-700/30">
                <div className="flex items-center gap-4">
                  <div className="w-14 h-14 rounded-xl bg-slate-700/50" />
                  <div className="flex-1 space-y-2">
                    <div className="h-4 bg-slate-700/50 rounded w-3/4" />
                    <div className="h-3 bg-slate-700/30 rounded w-1/2" />
                  </div>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <AnimatePresence>
              {locations.map((loc, i) => {
                const badge = getSlotBadge(loc);
                const isFull = (loc.available_slots ?? 0) === 0;
                const isSelected = selectedId === loc.id;

                return (
                  <motion.button
                    key={loc.id}
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.15 + i * 0.08 }}
                    onClick={() => !isFull && handleSelect(loc)}
                    disabled={isFull || confirming}
                    className={`
                      group relative w-full text-left rounded-2xl p-5 border transition-all duration-300 outline-none
                      ${isSelected
                        ? 'bg-indigo-600/20 border-indigo-500/60 shadow-lg shadow-indigo-500/10 scale-[1.02]'
                        : isFull
                          ? 'bg-slate-800/30 border-slate-700/20 opacity-50 cursor-not-allowed'
                          : 'bg-slate-800/50 border-slate-700/40 hover:bg-slate-800/80 hover:border-slate-600/60 hover:shadow-xl hover:shadow-black/20 hover:scale-[1.01] active:scale-[0.99]'
                      }
                    `}
                  >
                    <div className="flex items-center gap-4">
                      {/* Icon/Image */}
                      <div className={`w-14 h-14 rounded-xl flex items-center justify-center shrink-0 transition-colors ${isSelected ? 'bg-indigo-500/20' : 'bg-slate-700/50 group-hover:bg-slate-700/80'}`}>
                        {loc.imageUrl ? (
                          <img src={loc.imageUrl} alt={loc.name} className="w-full h-full rounded-xl object-cover" />
                        ) : (
                          <Car size={24} className={isSelected ? 'text-indigo-400' : 'text-slate-400'} />
                        )}
                      </div>

                      {/* Info */}
                      <div className="flex-1 min-w-0">
                        <h3 className="font-bold text-white text-base truncate">{loc.name}</h3>
                        <p className="text-slate-400 text-sm flex items-center gap-1 mt-0.5 truncate">
                          <MapPin size={12} className="shrink-0" /> {loc.address}
                        </p>
                        {/* Slots badge */}
                        <span className={`inline-block mt-2 text-[11px] font-bold px-2.5 py-0.5 rounded-full border ${badge.color}`}>
                          {badge.text}
                        </span>
                      </div>

                      {/* Arrow */}
                      {!isFull && (
                        <ChevronRight size={20} className={`shrink-0 transition-transform duration-300 ${isSelected ? 'text-indigo-400 translate-x-1' : 'text-slate-600 group-hover:text-slate-400 group-hover:translate-x-1'}`} />
                      )}
                    </div>

                    {/* Selection animation overlay */}
                    {isSelected && confirming && (
                      <motion.div
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        className="absolute inset-0 bg-indigo-600/10 rounded-2xl flex items-center justify-center backdrop-blur-sm"
                      >
                        <Loader2 size={24} className="text-indigo-400 animate-spin" />
                      </motion.div>
                    )}
                  </motion.button>
                );
              })}
            </AnimatePresence>
          </div>
        )}
      </div>

      {/* Footer */}
      <motion.p
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.6 }}
        className="relative z-10 text-slate-600 text-xs mt-10 text-center"
      >
        You can change your parking location anytime from settings
      </motion.p>
    </motion.div>
  );
}
