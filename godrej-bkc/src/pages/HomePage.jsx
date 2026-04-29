import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { CarFront, MapPin, ArrowRight, RefreshCw } from 'lucide-react';
import { useParking } from '../context/ParkingContext';

export default function HomePage() {
  const navigate = useNavigate();
  const { selectedParking, clearParking } = useParking();

  return (
    <div className="min-h-screen bg-[#0A0F1E] flex flex-col items-center justify-center p-6 text-white font-poppins relative overflow-hidden">
      {/* Background */}
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_50%_30%,rgba(99,102,241,0.08),transparent_60%)]" />
        <div className="absolute bottom-0 left-0 w-full h-1/2 bg-[radial-gradient(ellipse_at_50%_100%,rgba(16,185,129,0.05),transparent_60%)]" />
      </div>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6 }}
        className="relative z-10 w-full max-w-md"
      >
        {/* Selected parking badge */}
        {selectedParking && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            className="flex items-center justify-center gap-2 mb-8"
          >
            <div className="flex items-center gap-2 bg-slate-800/60 backdrop-blur-sm px-4 py-2 rounded-full border border-slate-700/40">
              <MapPin size={14} className="text-indigo-400 shrink-0" />
              <span className="text-sm font-medium text-slate-300 truncate max-w-[200px]">{selectedParking.name}</span>
              <button
                onClick={clearParking}
                className="ml-1 p-1 rounded-full hover:bg-slate-700/50 text-slate-500 hover:text-slate-300 transition-all"
                title="Change Location"
              >
                <RefreshCw size={12} />
              </button>
            </div>
          </motion.div>
        )}

        <div className="flex space-x-3 mb-6 justify-center">
          <div className="bg-slate-800/60 p-4 rounded-2xl shadow-xl shadow-black/20 border border-slate-700/30">
            <CarFront size={48} className="text-indigo-400" />
          </div>
        </div>

        <h1 className="text-4xl font-bold text-center mb-3 tracking-tight">Smart Vehicle Retrieval</h1>
        <p className="text-slate-400 text-center mb-8 text-lg">Request your car and track ETA in real-time.</p>

        <button
          onClick={() => navigate('/request')}
          className="w-full bg-indigo-600 hover:bg-indigo-500 text-white font-semibold py-4 px-8 rounded-xl shadow-lg shadow-indigo-500/20 transition-all active:scale-[0.98] flex items-center justify-center text-lg gap-2.5 border border-indigo-500/30"
        >
          Get My Car
          <ArrowRight size={20} />
        </button>
      </motion.div>
    </div>
  );
}
