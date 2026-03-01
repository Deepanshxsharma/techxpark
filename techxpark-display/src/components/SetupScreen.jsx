import { useState, useEffect } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { db } from '../firebase';
import { collection, getDocs } from 'firebase/firestore';

/**
 * Setup screen shown when no ?lot= param is present.
 * Lets the user pick a lot and generate the display URL.
 */
export default function SetupScreen() {
    const [lots, setLots] = useState([]);
    const [selectedLot, setSelectedLot] = useState('');
    const [mode, setMode] = useState('indoor');
    const [generated, setGenerated] = useState('');

    useEffect(() => {
        getDocs(collection(db, 'parking_locations')).then(snap => {
            const fetchedLots = snap.docs.map(d => ({ id: d.id, name: d.data().name }));
            setLots(fetchedLots);
        }).catch(err => {
            console.error('[SetupScreen] Error fetching lots:', err);
        });
    }, []);

    const generate = () => {
        if (!selectedLot) return;
        const base = window.location.origin;
        const url = `${base}/?lot=${selectedLot}&mode=${mode}`;
        setGenerated(url);
    };

    return (
        <div className="w-screen h-screen flex items-center justify-center" style={{ background: 'linear-gradient(135deg, #050A18 0%, #0D1321 50%, #1a1a2e 100%)', cursor: 'auto' }}>
            <div className="w-full max-w-lg p-8 rounded-3xl" style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', backdropFilter: 'blur(20px)' }}>
                <div className="text-center mb-8">
                    <div className="text-5xl mb-4">🅿️</div>
                    <h1 className="text-3xl font-black text-white tracking-tight">TechXPark Display</h1>
                    <p className="text-white/40 mt-2 text-sm">Configure your parking display screen</p>
                </div>

                <div className="flex flex-col gap-5">
                    {/* Lot selector */}
                    <div>
                        <label className="text-xs font-bold text-white/50 uppercase tracking-wider mb-1.5 block">Select Parking Lot</label>
                        <select value={selectedLot} onChange={e => setSelectedLot(e.target.value)}
                            className="w-full p-3 rounded-xl bg-white/5 text-white border border-white/10 outline-none text-sm font-semibold focus:border-primary transition" style={{ cursor: 'pointer' }}>
                            <option value="">— Choose a lot —</option>
                            {lots.map(l => <option key={l.id} value={l.id}>{l.name}</option>)}
                        </select>
                    </div>

                    {/* Mode toggle */}
                    <div>
                        <label className="text-xs font-bold text-white/50 uppercase tracking-wider mb-1.5 block">Display Mode</label>
                        <div className="flex gap-2">
                            {['indoor', 'outdoor'].map(m => (
                                <button key={m} onClick={() => setMode(m)}
                                    className="flex-1 py-2.5 rounded-xl text-sm font-bold transition-all"
                                    style={{
                                        background: mode === m ? '#2845D6' : 'rgba(255,255,255,0.05)',
                                        color: mode === m ? '#fff' : 'rgba(255,255,255,0.5)',
                                        border: mode === m ? '1.5px solid #2845D6' : '1.5px solid rgba(255,255,255,0.1)',
                                        cursor: 'pointer',
                                    }}>
                                    {m === 'indoor' ? '🖥️ Indoor TV' : '📺 Outdoor LED'}
                                </button>
                            ))}
                        </div>
                    </div>

                    {/* Generate button */}
                    <button onClick={() => {
                        if (!selectedLot) return;
                        window.location.href = `${window.location.origin}/?lot=${selectedLot}&mode=${mode}`;
                    }}
                        className="w-full py-3.5 rounded-xl text-white font-bold text-sm transition-all"
                        style={{ background: selectedLot ? '#2845D6' : 'rgba(255,255,255,0.05)', cursor: selectedLot ? 'pointer' : 'not-allowed', opacity: selectedLot ? 1 : 0.5 }}>
                        Start Display
                    </button>
                </div>
            </div>
        </div>
    );
}
