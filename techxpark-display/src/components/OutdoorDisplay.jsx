import { useState, useEffect } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { format } from 'date-fns';

/* ═══════════════════════════════════════
   OUTDOOR LED BOARD (high contrast)
   Cycles through 3 views automatically
   ═══════════════════════════════════════ */
export default function OutdoorDisplay({ cfg, data }) {
    const { lot, floors, totalFree, totalOcc, pct } = data;
    const [view, setView] = useState(0);
    const [visible, setVisible] = useState(true);

    const durations = [cfg.v1, cfg.v2, cfg.v3];

    // Auto-cycle views with fade transition
    useEffect(() => {
        const d = durations[view] * 1000;
        const fadeOut = setTimeout(() => setVisible(false), d - 600);
        const next = setTimeout(() => {
            setView(prev => (prev + 1) % 3);
            setVisible(true);
        }, d);
        return () => { clearTimeout(fadeOut); clearTimeout(next); };
    }, [view, cfg.v1, cfg.v2, cfg.v3]);

    const isFull = totalFree === 0;
    const numColor = isFull ? '#FF3333' : totalFree <= 10 ? '#FFD700' : '#00FF88';
    const animClass = isFull ? '' : totalFree <= 5 ? 'urgent-pulse' : 'big-breathe';

    return (
        <div className="w-screen h-screen flex flex-col items-center justify-center text-white overflow-hidden"
            style={{ background: isFull && view === 0 ? '#450a0a' : '#000', transition: 'background 2s ease, opacity 500ms ease', opacity: visible ? 1 : 0 }}>

            {view === 0 && <ViewBigNumber lot={lot} totalFree={totalFree} numColor={numColor} animClass={animClass} isFull={isFull} />}
            {view === 1 && <ViewFloorBreakdown lot={lot} floors={floors} totalFree={totalFree} />}
            {view === 2 && <ViewQREntry lot={lot} />}
        </div>
    );
}

/* ─── VIEW 1: Big Number ─── */
function ViewBigNumber({ lot, totalFree, numColor, animClass, isFull }) {
    return (
        <div className="flex flex-col items-center gap-4">
            <OutdoorHeader name={lot?.name} />
            {isFull ? (
                <>
                    <div className="text-[18vw] font-black leading-none tracking-[-4px] text-red-500 urgent-pulse">FULL</div>
                    <div className="text-4xl font-bold text-white/60 mt-2">Parking is currently full</div>
                </>
            ) : (
                <>
                    <div className={`font-mono font-black leading-none tracking-[-4px] ${animClass}`}
                        style={{ fontSize: '22vw', color: numColor, textShadow: `0 0 60px ${numColor}40` }}>
                        {totalFree}
                    </div>
                    <div className="text-4xl font-bold text-white/60 tracking-wide uppercase">Spots Available</div>
                    {/* Dot indicators */}
                    <div className="flex gap-2 mt-2">
                        {Array.from({ length: Math.min(totalFree, 20) }).map((_, i) => (
                            <span key={i} className="w-4 h-4 rounded-full" style={{ background: numColor, opacity: 0.7 + i * 0.015 }} />
                        ))}
                    </div>
                    <div className="mt-4 text-3xl font-bold text-white/40">₹{lot?.price_per_hour ?? 50} PER HOUR</div>
                </>
            )}
        </div>
    );
}

/* ─── VIEW 2: Floor Breakdown ─── */
function ViewFloorBreakdown({ lot, floors, totalFree }) {
    return (
        <div className="w-full max-w-[85vw] flex flex-col items-center gap-6">
            <OutdoorHeader name={lot?.name} />
            <div className="w-full flex flex-col gap-5">
                {floors.map((f, i) => {
                    const pct = f.total ? Math.round(((f.total - f.free) / f.total) * 100) : 0;
                    const full = f.free === 0;
                    return (
                        <div key={i} className="flex items-center gap-6">
                            <span className="text-4xl font-extrabold w-[20vw] text-right uppercase shrink-0">{f.label}</span>
                            <div className="flex-1 h-10 rounded-full overflow-hidden" style={{ background: 'rgba(255,255,255,0.1)' }}>
                                <div className="h-full rounded-full transition-all duration-1000"
                                    style={{ width: `${pct}%`, background: full ? '#FF3333' : '#00FF88' }} />
                            </div>
                            <span className="font-mono text-5xl font-black w-[15vw] text-center"
                                style={{ color: full ? '#FF3333' : '#00FF88' }}>
                                {f.free}
                            </span>
                            <span className="text-2xl font-bold text-white/40 w-[8vw]">FREE</span>
                        </div>
                    );
                })}
            </div>
            <div className="mt-6 text-4xl font-bold">
                TOTAL: <span className="font-mono font-black text-5xl" style={{ color: '#00FF88' }}>{totalFree}</span> SPOTS FREE
            </div>
        </div>
    );
}

/* ─── VIEW 3: QR + Entry Info ─── */
function ViewQREntry({ lot }) {
    return (
        <div className="flex items-center gap-[8vw]">
            <div className="flex flex-col items-center gap-4">
                <OutdoorHeader name={lot?.name} />
                <div className="p-6 bg-white rounded-3xl">
                    <QRCodeSVG value="https://play.google.com/store/apps/details?id=com.techxpark.app&pcampaignid=web_share" size={280} bgColor="#fff" fgColor="#000" />
                </div>
            </div>
            <div className="flex flex-col gap-6">
                <div className="text-5xl font-extrabold">BOOK IN ADVANCE</div>
                <div className="text-3xl text-white/50 font-semibold">Scan to Download TechXPark App</div>
                <div className="mt-4 flex flex-col gap-4 text-3xl font-bold">
                    <div>➡️ ENTRY: Gate A <span className="text-white/40 ml-4">₹{lot?.price_per_hour ?? 50}/hour</span></div>
                    <div>⬅️ EXIT: Gate B <span className="text-white/40 ml-4">Open 24/7</span></div>
                </div>
                <div className="mt-4 text-2xl text-white/40">📞 Call for assistance</div>
            </div>
        </div>
    );
}

function OutdoorHeader({ name }) {
    return (
        <div className="flex items-center gap-4 mb-4">
            <span className="text-6xl">🅿️</span>
            <span className="text-5xl font-black tracking-tight">TECHXPARK</span>
            {name && <span className="text-3xl font-semibold text-white/50 ml-2">— {name}</span>}
        </div>
    );
}
