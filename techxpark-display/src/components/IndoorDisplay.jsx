import { useState, useEffect, useMemo } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { format } from 'date-fns';
import useWeather, { WeatherIcon } from '../hooks/useWeather';
import useTicker from '../hooks/useTicker';

/* ═══════════════════════════════════════
   INDOOR TV DISPLAY (16:9 landscape)
   ═══════════════════════════════════════ */
export default function IndoorDisplay({ cfg, data }) {
    const { lot, slots, floors, totalFree, totalOcc, pct, changedSlots } = data;
    const weather = useWeather(lot?.latitude, lot?.longitude);
    const { tickerText, addMessage } = useTicker(totalFree, lot?.name);
    const [clock, setClock] = useState(new Date());
    const [activeFloor, setActiveFloor] = useState(0);

    // Live clock
    useEffect(() => {
        const id = setInterval(() => setClock(new Date()), 1000);
        return () => clearInterval(id);
    }, []);

    // Auto-cycle floors
    useEffect(() => {
        if (!cfg.cycle || floors.length <= 1) return;
        const id = setInterval(() => {
            setActiveFloor(prev => (prev + 1) % floors.length);
        }, cfg.cycleTime * 1000);
        return () => clearInterval(id);
    }, [cfg.cycle, cfg.cycleTime, floors.length]);

    // Ticker messages from slot changes
    useEffect(() => {
        changedSlots.forEach((type, slotId) => {
            if (type === 'freed') addMessage(`🟢 Slot ${slotId} just became available`);
            else addMessage(`🔴 Slot ${slotId} is now taken`);
        });
    }, [changedSlots, addMessage]);

    const urgency = pct < 50 ? 'calm' : pct < 80 ? 'filling' : pct < 95 ? 'almost' : 'full';
    const headerBg = { calm: '#2845D6', filling: '#D97706', almost: '#DC2626', full: '#7F1D1D' }[urgency];

    const currentFloor = floors[activeFloor] || floors[0] || { slots: [], free: 0, total: 0, label: 'Ground' };
    const floorSlots = cfg.floor !== 'all'
        ? slots.filter(s => String(s.floor ?? s.floorIndex) === cfg.floor)
        : currentFloor.slots;

    const gridCols = floorSlots.length > 60 ? 10 : floorSlots.length > 30 ? 8 : 6;

    return (
        <div className="w-screen h-screen flex flex-col" style={{ background: 'var(--bg)' }}>
            {/* ─── TOP BAR ─── */}
            <div className="flex items-center justify-between px-6 shrink-0" style={{ height: '5vh', background: headerBg, transition: 'background 2s ease' }}>
                <div className="flex items-center gap-3">
                    <span className="text-2xl">🅿️</span>
                    <div>
                        <div className="text-white font-extrabold text-base leading-tight">{lot?.name || 'TechXPark'}</div>
                        <div className="text-white/60 text-xs">{lot?.address || ''}</div>
                    </div>
                </div>

                <div className="flex items-center gap-4">
                    <AvailabilityPill totalFree={totalFree} totalOcc={totalOcc} pct={pct} />
                </div>

                <div className="flex items-center gap-4">
                    {weather && (
                        <div className="flex items-center gap-2 text-white/80 text-xs">
                            <WeatherIcon code={weather.icon} />
                            <span className="font-mono font-bold">{weather.temp}°C</span>
                        </div>
                    )}
                    <div className="text-right">
                        <div className="font-mono text-2xl font-bold text-white leading-none">{format(clock, 'h:mm a')}</div>
                        <div className="text-white/60 text-xs">{format(clock, 'EEEE, d MMMM')}</div>
                    </div>
                    <div className="flex items-center gap-1.5">
                        <span className="w-2 h-2 rounded-full bg-green-400 live-dot" />
                        <span className="text-green-300 text-xs font-bold tracking-wider">LIVE</span>
                    </div>
                </div>
            </div>

            {/* ─── MAIN CONTENT ─── */}
            <div className="flex flex-1 min-h-0">
                {/* ─── LEFT PANEL ─── */}
                <div className="shrink-0 flex flex-col gap-4 p-4 overflow-hidden" style={{ width: '17vw', background: 'var(--surface)', borderRight: '1px solid var(--border)' }}>
                    <SectionLabel>FLOORS</SectionLabel>
                    <div className="flex flex-col gap-2 flex-1 overflow-auto">
                        {floors.map((f, i) => (
                            <FloorCard key={i} floor={f} isActive={i === activeFloor} onClick={() => setActiveFloor(i)} />
                        ))}
                    </div>

                    <Divider />
                    <SectionLabel>PARKING RATES</SectionLabel>
                    <div className="flex flex-col gap-1.5 text-sm">
                        <PriceRow icon="🕐" label="Hourly" price={`₹${lot?.price_per_hour ?? 50}/hr`} />
                        <PriceRow icon="📅" label="Daily" price={`₹${lot?.daily_rate ?? 300}/day`} />
                        <PriceRow icon="📆" label="Monthly" price={`₹${lot?.monthly_rate ?? '2,000'}/mo`} />
                    </div>

                    <Divider />
                    <SectionLabel>ACCESS</SectionLabel>
                    <div className="flex flex-col gap-1 text-xs" style={{ color: 'var(--text-secondary)' }}>
                        <div>➡️ ENTRY — Gate A, Level G</div>
                        <div>⬅️ EXIT — Gate B, Level G</div>
                        <div>🕐 Open 24/7</div>
                    </div>
                </div>

                {/* ─── CENTER SLOT GRID ─── */}
                <div className="flex-1 flex flex-col min-w-0 p-4">
                    {/* Floor tabs */}
                    {floors.length > 1 && (
                        <div className="flex gap-2 mb-3 shrink-0 overflow-hidden">
                            {floors.map((f, i) => (
                                <button key={i} onClick={() => setActiveFloor(i)}
                                    className="px-3 py-1.5 rounded-lg text-xs font-bold transition-all duration-300 border-none outline-none"
                                    style={{
                                        background: i === activeFloor ? '#2845D6' : f.free === 0 ? 'rgba(239,68,68,0.15)' : 'var(--surface)',
                                        color: i === activeFloor ? '#fff' : f.free === 0 ? '#EF4444' : 'var(--text-secondary)',
                                    }}>
                                    {f.label} <span className="font-mono ml-1">({f.free === 0 ? 'FULL' : `${f.free} free`})</span>
                                </button>
                            ))}
                        </div>
                    )}

                    {/* Cycle progress bar */}
                    {cfg.cycle && floors.length > 1 && (
                        <div className="w-full h-0.5 rounded-full mb-2 shrink-0" style={{ background: 'var(--border)' }}>
                            <div className="h-full rounded-full bg-primary" style={{ animation: `cycleProgress ${cfg.cycleTime}s linear infinite` }} />
                        </div>
                    )}

                    {/* Grid */}
                    <div className="flex-1 grid gap-2 content-start overflow-hidden" style={{ gridTemplateColumns: `repeat(${gridCols}, 1fr)` }}>
                        {floorSlots.map(slot => (
                            <SlotTile key={slot.id} slot={slot} change={changedSlots.get(slot.id)} />
                        ))}
                    </div>

                    {/* Legend */}
                    <div className="flex items-center justify-center gap-6 pt-2 text-xs font-semibold shrink-0" style={{ color: 'var(--text-secondary)' }}>
                        <span><span className="inline-block w-3 h-3 rounded-sm mr-1.5" style={{ background: 'var(--slot-avail-bg)', border: '1.5px solid #22C55E' }} /> Available</span>
                        <span><span className="inline-block w-3 h-3 rounded-sm mr-1.5" style={{ background: 'var(--slot-occ-bg)', border: '1.5px solid #EF4444' }} /> Occupied</span>
                        <span>⚡ EV</span>
                        <span>♿ Accessible</span>
                    </div>
                </div>

                {/* ─── RIGHT PANEL ─── */}
                {cfg.qr && (
                    <div className="shrink-0 flex flex-col gap-4 p-4 overflow-hidden" style={{ width: '18vw', background: 'var(--surface)', borderLeft: '1px solid var(--border)' }}>
                        <SectionLabel>BOOK VIA APP</SectionLabel>
                        <div className="text-xs mb-1" style={{ color: 'var(--text-secondary)' }}>Scan to reserve your spot</div>
                        <div className="mx-auto p-3 bg-white rounded-2xl border-[3px] border-primary" style={{ boxShadow: '0 8px 32px rgba(40,69,214,0.2)' }}>
                            <QRCodeSVG value="https://play.google.com/store/apps/details?id=com.techxpark.app&pcampaignid=web_share" size={140} bgColor="#fff" fgColor="#0D1117" />
                        </div>
                        <div className="text-center text-xs font-bold" style={{ color: 'var(--text-secondary)' }}>Download TechXPark</div>

                        <Divider />
                        <SectionLabel>TODAY'S STATS</SectionLabel>
                        <div className="flex flex-col gap-1.5 text-sm">
                            <StatRow icon="📋" label="Total Spots" value={slots.length} />
                            <StatRow icon="🟢" label="Available" value={totalFree} color="#22C55E" />
                            <StatRow icon="🔴" label="Occupied" value={totalOcc} color="#EF4444" />
                            <StatRow icon="📊" label="Occupancy" value={`${pct}%`} />
                        </div>

                        <Divider />
                        <SectionLabel>HOW TO PARK</SectionLabel>
                        <div className="flex flex-col gap-2 text-xs" style={{ color: 'var(--text-secondary)' }}>
                            <StepCard n={1} text="Scan QR code to book" />
                            <StepCard n={2} text="Drive to your assigned slot" />
                            <StepCard n={3} text="Park and enjoy!" />
                        </div>

                        <Divider />
                        <div className="text-xs" style={{ color: 'var(--text-secondary)' }}>
                            <div className="font-bold">📞 Need Help?</div>
                            <div>Call facility management</div>
                        </div>
                    </div>
                )}
            </div>

            {/* ─── BOTTOM TICKER ─── */}
            {cfg.ticker && <TickerBar text={tickerText} lotName={lot?.name} clock={clock} />}
        </div>
    );
}

/* ═══ Sub-Components ═══ */

function AvailabilityPill({ totalFree, totalOcc, pct }) {
    const tint = pct < 50 ? 'rgba(34,197,94,0.2)' : pct < 80 ? 'rgba(245,158,11,0.2)' : 'rgba(239,68,68,0.2)';
    return (
        <div className="flex items-center gap-4 px-4 py-1.5 rounded-full" style={{ background: tint }}>
            <span className="flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-green-400" />
                <span className="font-mono text-3xl font-black text-white leading-none">{totalFree}</span>
                <span className="text-white/70 text-sm font-semibold">Available</span>
            </span>
            <span className="w-px h-8 bg-white/20" />
            <span className="flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-red-400" />
                <span className="font-mono text-3xl font-black text-white leading-none">{totalOcc}</span>
                <span className="text-white/70 text-sm font-semibold">Occupied</span>
            </span>
        </div>
    );
}

function FloorCard({ floor, isActive, onClick }) {
    const full = floor.free === 0;
    const pct = floor.total ? Math.round(((floor.total - floor.free) / floor.total) * 100) : 0;
    const barColor = pct > 90 ? '#EF4444' : pct > 70 ? '#F59E0B' : '#22C55E';
    return (
        <div onClick={onClick} className="p-2.5 rounded-xl transition-all duration-300"
            style={{
                background: isActive ? 'rgba(40,69,214,0.08)' : full ? 'rgba(239,68,68,0.06)' : 'transparent',
                border: isActive ? '1.5px solid #2845D6' : '1.5px solid var(--border)',
            }}>
            <div className="flex justify-between items-baseline">
                <span className="text-lg font-extrabold" style={{ color: 'var(--text-primary)' }}>{floor.label}</span>
                <div className="flex items-center gap-1.5">
                    <span className="font-mono text-xl font-black" style={{ color: full ? '#EF4444' : '#22C55E' }}>{floor.free}</span>
                    {full && <span className="text-[10px] font-bold text-red-500 bg-red-500/10 px-1.5 py-0.5 rounded blink">FULL</span>}
                    {!full && <span className="text-xs" style={{ color: 'var(--text-secondary)' }}>free</span>}
                </div>
            </div>
            <div className="mt-1.5 h-1.5 rounded-full overflow-hidden" style={{ background: 'var(--border)' }}>
                <div className="h-full rounded-full transition-all duration-1000" style={{ width: `${pct}%`, background: barColor }} />
            </div>
            <div className="text-[10px] mt-0.5 text-right font-semibold" style={{ color: 'var(--text-secondary)' }}>{pct}% full</div>
        </div>
    );
}

function SlotTile({ slot, change }) {
    const avail = slot.status === 'available';
    const isEv = slot.type === 'ev';
    const isDisabled = slot.type === 'disabled';
    const animClass = change === 'freed' ? 'slot-just-free' : change === 'taken' ? 'slot-just-occ' : avail ? 'slot-avail' : '';

    return (
        <div className={`rounded-xl flex flex-col items-center justify-center transition-all duration-500 ${animClass}`}
            style={{
                aspectRatio: '5/6',
                background: avail ? 'var(--slot-avail-bg)' : 'var(--slot-occ-bg)',
                border: avail ? '2px solid rgba(34,197,94,0.45)' : '2px solid rgba(239,68,68,0.45)',
            }}>
            <div className="text-[10px] font-semibold leading-none mb-0.5" style={{ color: avail ? 'var(--slot-avail-text)' : 'var(--slot-occ-text)' }}>
                {isEv ? '⚡ EV' : isDisabled ? '♿' : ''}{slot.id}
            </div>
            {avail
                ? <div className="text-2xl font-black" style={{ color: isEv ? '#8B5CF6' : 'var(--slot-avail-text)' }}>P</div>
                : <div className="text-xl" style={{ color: 'var(--slot-occ-text)' }}>🚗</div>}
        </div>
    );
}

function TickerBar({ text, lotName, clock }) {
    const doubled = `${text}    •    ${text}    •    `;
    const len = doubled.length;
    const dur = Math.max(20, len * 0.35);
    return (
        <div className="shrink-0 flex items-center overflow-hidden" style={{ height: '3.5vh', background: '#0A0F1E', borderTop: '1px solid rgba(255,255,255,0.1)' }}>
            <div className="flex items-center gap-2 px-4 shrink-0">
                <span className="w-2 h-2 rounded-full bg-red-500 live-dot" />
                <span className="text-red-400 text-xs font-bold tracking-wide">LIVE UPDATES</span>
                <span className="w-px h-4 bg-white/10" />
            </div>
            <div className="flex-1 overflow-hidden">
                <div className="ticker-track text-sm font-medium text-white/70" style={{ '--ticker-duration': `${dur}s` }}>
                    <span className="pr-8">{doubled}</span>
                    <span className="pr-8">{doubled}</span>
                </div>
            </div>
            <div className="flex items-center gap-3 px-4 shrink-0">
                <span className="text-white/50 text-xs font-semibold">{lotName}</span>
                <span className="font-mono text-xs text-white/70 font-bold">{format(clock, 'h:mm:ss a')}</span>
            </div>
        </div>
    );
}

/* ─── Shared small components ─── */
function SectionLabel({ children }) {
    return <div className="text-[10px] font-bold tracking-[1.5px] uppercase" style={{ color: 'var(--text-secondary)' }}>{children}</div>;
}

function Divider() {
    return <div className="my-1" style={{ borderTop: '1px solid var(--border)' }} />;
}

function PriceRow({ icon, label, price }) {
    return (
        <div className="flex items-center justify-between">
            <span style={{ color: 'var(--text-secondary)' }}>{icon} {label}</span>
            <span className="font-mono font-bold text-primary">{price}</span>
        </div>
    );
}

function StatRow({ icon, label, value, color }) {
    return (
        <div className="flex items-center justify-between">
            <span style={{ color: 'var(--text-secondary)' }}>{icon} {label}</span>
            <span className="font-mono font-bold" style={{ color: color || 'var(--text-primary)' }}>{value}</span>
        </div>
    );
}

function StepCard({ n, text }) {
    return (
        <div className="flex items-center gap-2 p-2 rounded-lg" style={{ background: 'var(--bg)' }}>
            <span className="w-5 h-5 rounded-full bg-primary text-white text-[10px] font-bold flex items-center justify-center shrink-0">{n}</span>
            <span>{text}</span>
        </div>
    );
}
