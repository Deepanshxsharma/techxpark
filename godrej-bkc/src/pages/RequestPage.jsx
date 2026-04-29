import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { Car, Search, ArrowRight, CheckCircle2, MessageSquare } from 'lucide-react';
import { useDemo } from '../context/DemoContext';

export default function RequestPage() {
  const navigate = useNavigate();
  const { createRequest } = useDemo();
  
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  
  // Simulated SMS state
  const [showSMS, setShowSMS] = useState(false);
  const [createdReqId, setCreatedReqId] = useState(null);

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!searchTerm) return;

    setLoading(true);
    setError('');

    // Simulate network delay
    setTimeout(() => {
      try {
        const id = createRequest(searchTerm);
        setCreatedReqId(id);
        setShowSMS(true);
        setLoading(false);
      } catch (err) {
        setError(err.message);
        setLoading(false);
      }
    }, 800);
  };

  const handleContinue = () => {
    navigate(`/track/${createdReqId}`);
  };

  return (
    <div className="min-h-screen bg-slate-900 flex flex-col p-6 text-white font-poppins relative">
      <div className="absolute top-1/4 -right-1/4 w-96 h-96 bg-blue-500/10 rounded-full blur-3xl pointer-events-none" />
      
      <div className="w-full max-w-md mx-auto pt-12 flex-1 flex flex-col z-10">
        <div className="mb-10">
          <h1 className="text-3xl font-bold mb-2">Find your vehicle</h1>
          <p className="text-slate-400">Enter phone or vehicle number</p>
        </div>

        <form onSubmit={handleSubmit} className="flex-1">
          <div className="mb-6">
            <div className="relative">
              <span className="absolute inset-y-0 left-0 flex items-center pl-4 text-slate-500">
                <Search size={20} />
              </span>
              <input
                type="text"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                placeholder="e.g. MH01AB1234 or 9999999991"
                className="w-full bg-slate-800 text-white pl-12 pr-4 h-16 rounded-2xl border border-slate-700 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 outline-none transition-all text-lg shadow-inner"
              />
            </div>
            {error && (
              <motion.p 
                initial={{ opacity: 0, y: -5 }} animate={{ opacity: 1, y: 0 }}
                className="text-orange-400 text-sm mt-3 flex items-center gap-1"
              >
                {error}
              </motion.p>
            )}
          </div>

          <button 
            type="submit" 
            disabled={loading || !searchTerm}
            className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:bg-slate-700 disabled:text-slate-500 text-white font-semibold py-4 rounded-xl shadow-lg shadow-indigo-500/20 transition-all flex items-center justify-center text-lg gap-2 mt-4"
          >
            {loading ? (
              <div className="w-6 h-6 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            ) : (
              <>
                Request Vehicle
                <ArrowRight size={20} />
              </>
            )}
          </button>
        </form>
      </div>

      {/* Simulated SMS Popup Modal */}
      <AnimatePresence>
        {showSMS && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-6"
          >
            <motion.div 
              initial={{ scale: 0.9, y: 20 }}
              animate={{ scale: 1, y: 0 }}
              className="bg-slate-800 w-full max-w-sm rounded-3xl p-6 shadow-2xl border border-slate-700"
            >
              <div className="w-16 h-16 bg-indigo-500/20 text-indigo-400 rounded-full flex items-center justify-center mx-auto mb-4">
                <CheckCircle2 size={32} />
              </div>
              <h2 className="text-2xl font-bold text-center mb-2">Request Created</h2>
              <p className="text-slate-400 text-center mb-6">A valet has been queued for your vehicle.</p>
              
              <div className="bg-slate-900 rounded-xl p-4 mb-6 border border-slate-700 border-l-4 border-l-indigo-500">
                <div className="flex items-center gap-2 text-slate-400 text-xs font-semibold uppercase mb-2">
                  <MessageSquare size={14} /> SMS Simulator
                </div>
                <p className="text-sm leading-relaxed">
                  Your car retrieval request is confirmed. A valet will be assigned shortly.<br/>
                  Track live: <span className="text-indigo-400 break-all cursor-pointer select-all">
                    https://app.com/track/{createdReqId}
                  </span>
                </p>
              </div>

              <button 
                onClick={handleContinue}
                className="w-full bg-indigo-600 hover:bg-indigo-500 text-white font-semibold py-4 rounded-xl shadow-lg shadow-indigo-500/20"
              >
                Track Now
              </button>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
