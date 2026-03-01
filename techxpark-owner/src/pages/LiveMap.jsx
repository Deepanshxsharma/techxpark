import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useSlots } from '../hooks/useSlots';
import { Car, AlertTriangle, RadioReceiver, X, Check } from 'lucide-react';
import { db } from '../firebase';
import { doc, updateDoc } from 'firebase/firestore';
import { toast } from 'react-hot-toast';
import { Link } from 'react-router-dom';
import Button from '../components/ui/Button';

export default function LiveMap() {
    const { ownerData } = useAuth();
    const lotId = ownerData?.assignedLotId;
    const { slots, loading } = useSlots(lotId);

    const [selectedFloor, setSelectedFloor] = useState(1);
    const [selectedSlot, setSelectedSlot] = useState(null);

    // Sync selected slot data as it changes in Firestore
    const syncedSelectedSlot = slots.find(s => s.id === selectedSlot?.id) || selectedSlot;

    if (loading) return (
        <div className="flex h-[calc(100vh-8rem)] items-center justify-center">
            <div className="w-10 h-10 border-4 border-primary border-t-transparent rounded-full animate-spin"></div>
        </div>
    );

    const floors = [...new Set(slots.map(s => s.floor))].sort((a, b) => a - b);
    const activeFloor = floors.length > 0 && !floors.includes(selectedFloor) ? floors[0] : selectedFloor;

    const floorSlots = slots.filter(s => s.floor === activeFloor);

    // Divide slots roughly into left and right columns for the driving lane
    const midIndex = Math.ceil(floorSlots.length / 2);
    const leftSlots = floorSlots.slice(0, midIndex);
    const rightSlots = floorSlots.slice(midIndex);

    const handleMarkStatus = async (slotId, newStatus) => {
        try {
            const slotRef = doc(db, `parking_locations/${lotId}/slots`, slotId);
            await updateDoc(slotRef, { taken: newStatus });
            toast.success(`Slot marked as ${newStatus ? 'Occupied' : 'Free'}`);
        } catch (error) {
            console.error(error);
            toast.error("Failed to update slot status");
        }
    };

    return (
        <div className="flex flex-col h-[calc(100vh-6rem)] w-full overflow-hidden relative animate-in fade-in slide-in-from-bottom-2 duration-300">

            <div className="flex flex-1 gap-6 overflow-hidden max-w-[1400px] mx-auto w-full">

                {/* Main Content Area */}
                <div className="flex-1 flex flex-col min-w-0">

                    {/* Floor Tabs */}
                    <div className="flex items-center gap-2 mb-6 overflow-x-auto pb-2 scrollbar-none">
                        {floors.map(f => {
                            const floorFree = slots.filter(s => s.floor === f && !s.taken).length;
                            const isFull = floorFree === 0;
                            const isActive = activeFloor === f;

                            return (
                                <button
                                    key={f}
                                    onClick={() => setSelectedFloor(f)}
                                    className={`
                                        flex items-center gap-3 px-4 py-2 rounded-full text-sm font-semibold transition-all whitespace-nowrap shrink-0
                                        ${isActive
                                            ? 'bg-primary text-white shadow-primary'
                                            : 'bg-surface border border-border text-text-secondary hover:bg-surface-hover hover:text-text-primary'
                                        }
                                    `}
                                >
                                    <span>Level {f === 0 ? 'G' : f < 0 ? `B${Math.abs(f)}` : f}</span>
                                    <div className="flex items-center gap-1.5 opacity-90">
                                        <span className={`w-1.5 h-1.5 rounded-full ${isFull ? (isActive ? 'bg-white' : 'bg-error') : (isActive ? 'bg-white' : 'bg-success')}`}></span>
                                        <span className={`text-[11px] ${isActive ? 'text-white/90' : 'text-text-tertiary'}`}>
                                            {isFull ? 'Full' : `${floorFree} free`}
                                        </span>
                                    </div>
                                </button>
                            );
                        })}
                    </div>

                    {/* Dark Asphalt Grid Container */}
                    <div className="flex-1 bg-[#0D1321] rounded-[16px] p-6 md:p-10 overflow-y-auto relative shadow-[inset_0_2px_8px_rgba(0,0,0,0.3)]">

                        {floorSlots.length === 0 ? (
                            <div className="flex items-center justify-center h-full text-white/40">
                                No slots configured for this level.
                            </div>
                        ) : (
                            <div className="max-w-3xl mx-auto flex h-full min-h-[500px]">

                                {/* Left Column */}
                                <div className="flex-1 flex flex-wrap gap-4 content-start justify-end pr-4">
                                    {leftSlots.map(slot => <SlotTile key={slot.id} slot={slot} isSelected={syncedSelectedSlot?.id === slot.id} onClick={() => setSelectedSlot(slot)} />)}
                                </div>

                                {/* Center Driving Lane */}
                                <div className="w-[80px] shrink-0 relative flex justify-center">
                                    {/* Dashed line */}
                                    <div className="absolute top-0 bottom-0 border-r-[2px] border-dashed border-white/10"></div>

                                    {/* Direction Arrows */}
                                    <div className="absolute top-0 bottom-0 flex flex-col justify-around py-12 text-white/5">
                                        {[...Array(5)].map((_, i) => (
                                            <svg key={i} width="24" height="24" viewBox="0 0 24 24" fill="none" className="rotate-180" opacity="0.5">
                                                <path d="M12 5V19M12 5L6 11M12 5L18 11" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                                            </svg>
                                        ))}
                                    </div>
                                </div>

                                {/* Right Column */}
                                <div className="flex-1 flex flex-wrap gap-4 content-start pl-4">
                                    {rightSlots.map(slot => <SlotTile key={slot.id} slot={slot} isSelected={syncedSelectedSlot?.id === slot.id} onClick={() => setSelectedSlot(slot)} />)}
                                </div>

                            </div>
                        )}

                    </div>
                </div>

                {/* Right Side Drawer */}
                {syncedSelectedSlot && (
                    <div className="w-[360px] shrink-0 bg-white border-l border-border shadow-[-8px_0_32px_rgba(0,0,0,0.08)] rounded-l-2xl absolute right-0 top-0 bottom-0 z-20 flex flex-col animate-[slideInRight_300ms_cubic-bezier(0.32,0.72,0,1)]">
                        <div className="p-5 border-b border-bg-light flex justify-between items-center bg-surface">
                            <div>
                                <h3 className="text-lg font-bold text-text-primary tracking-tight">Slot {syncedSelectedSlot.id}</h3>
                                <div className="text-xs font-semibold text-text-tertiary uppercase tracking-[0.8px] mt-1">
                                    Level {syncedSelectedSlot.floor}
                                </div>
                            </div>
                            <button
                                onClick={() => setSelectedSlot(null)}
                                className="text-text-tertiary hover:text-text-primary hover:bg-surface-hover w-8 h-8 rounded-full flex items-center justify-center transition-colors"
                            >
                                <X className="w-5 h-5" />
                            </button>
                        </div>

                        <div className="p-5 flex-1 overflow-y-auto space-y-6">
                            {/* Status Section */}
                            <div>
                                <h4 className="text-[11px] font-bold text-text-tertiary uppercase tracking-[0.8px] mb-3">Current Status</h4>
                                {syncedSelectedSlot.taken ? (
                                    <div className="flex items-center gap-2 bg-error-bg text-error-text px-3 py-2 rounded-lg border border-error/20 font-semibold text-sm">
                                        <div className="w-2 h-2 rounded-full bg-error"></div>
                                        Occupied
                                    </div>
                                ) : (
                                    <div className="flex items-center gap-2 bg-success-bg text-success-text px-3 py-2 rounded-lg border border-success/20 font-semibold text-sm">
                                        <span className="relative flex h-2 w-2">
                                            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-success opacity-75"></span>
                                            <span className="relative inline-flex rounded-full h-2 w-2 bg-success"></span>
                                        </span>
                                        Available
                                    </div>
                                )}
                            </div>

                            <div className="h-px bg-border w-full"></div>

                            {/* Sensor Section */}
                            <div>
                                <h4 className="text-[11px] font-bold text-text-tertiary uppercase tracking-[0.8px] mb-3">Hardware Sensor</h4>
                                {syncedSelectedSlot.sensorId ? (
                                    <div className="bg-bg-light border border-border rounded-xl p-4 space-y-3">
                                        <div className="flex justify-between items-center">
                                            <span className="text-sm font-medium text-text-secondary">Sensor ID</span>
                                            <span className="font-mono text-[13px] font-bold text-text-primary bg-white px-2 py-0.5 rounded border border-border">
                                                {syncedSelectedSlot.sensorId}
                                            </span>
                                        </div>
                                        <div className="flex justify-between items-center">
                                            <span className="text-sm font-medium text-text-secondary">Battery</span>
                                            <div className="flex items-center gap-2">
                                                <div className="w-16 h-1.5 bg-slate-200 rounded-full overflow-hidden">
                                                    <div className="bg-success h-full w-[85%]"></div>
                                                </div>
                                                <span className="font-mono text-xs font-semibold text-text-primary">85%</span>
                                            </div>
                                        </div>
                                    </div>
                                ) : (
                                    <div className="bg-bg-light border border-border rounded-xl p-6 text-center flex flex-col items-center">
                                        <div className="w-10 h-10 bg-white rounded-full border border-border flex items-center justify-center mb-3">
                                            <RadioReceiver className="w-5 h-5 text-text-tertiary" />
                                        </div>
                                        <p className="text-sm font-medium text-text-secondary">No hardware mapped</p>
                                    </div>
                                )}
                            </div>
                        </div>

                        {/* Actions fixed at bottom */}
                        <div className="p-5 border-t border-bg-light bg-surface space-y-3">
                            {syncedSelectedSlot.sensorId ? (
                                <Button variant="secondary" className="w-full text-error hover:text-error hover:bg-error-bg hover:border-error/30" onClick={() => toast("Disconnect coming soon")}>
                                    Disconnect Sensor
                                </Button>
                            ) : (
                                <Button variant="secondary" className="w-full text-primary hover:text-primary-dark hover:bg-info-bg hover:border-primary/30" onClick={() => toast("Connect wizard coming soon")}>
                                    Map Hardware Sensor
                                </Button>
                            )}

                            {syncedSelectedSlot.taken ? (
                                <Button variant="danger" className="w-full" onClick={() => handleMarkStatus(syncedSelectedSlot.id, false)}>
                                    Mark as Free
                                </Button>
                            ) : (
                                <Button variant="primary" className="w-full" onClick={() => handleMarkStatus(syncedSelectedSlot.id, true)}>
                                    Mark as Occupied
                                </Button>
                            )}
                        </div>
                    </div>
                )}
            </div>

            {/* Custom Animations required for LiveMap */}
            <style dangerouslySetInnerHTML={{
                __html: `
                @keyframes slideInRight {
                    from { transform: translateX(100%); }
                    to { transform: translateX(0); }
                }
            `}} />
        </div>
    );
}

function SlotTile({ slot, isSelected, onClick }) {

    // Base classes
    const baseClasses = "relative w-[60px] h-[80px] rounded-lg border-[1.5px] transition-all duration-150 ease-in-out flex flex-col items-center justify-center shrink-0";

    // Status classes
    let statusClasses = "";
    if (isSelected) {
        statusClasses = "bg-primary border-white shadow-[0_0_0_3px_rgba(40,69,214,0.3),0_0_20px_rgba(40,69,214,0.4)] z-10 scale-105 cursor-pointer";
    } else if (slot.taken) {
        statusClasses = "bg-[#E5393B1A] border-[#E5393B4D] cursor-default opacity-80";
    } else {
        statusClasses = "bg-[#FFFFFF0A] border-[#FFFFFF26] hover:bg-[#2845D626] hover:border-[#2845D6] hover:scale-105 cursor-pointer";
    }

    return (
        <div onClick={() => !slot.taken && onClick()} className={`${baseClasses} ${statusClasses}`}>
            {/* Top Label */}
            <div className={`absolute top-1 text-center font-mono text-[11px] leading-none ${isSelected ? 'text-white font-bold' : 'text-white/40'}`}>
                {slot.id}
            </div>

            {/* Sensor Dot */}
            {slot.sensorId ? (
                <div className="absolute top-1.5 right-1.5 w-1.5 h-1.5 rounded-full bg-[#4ADE80]"></div>
            ) : (
                <div className="absolute top-1.5 right-1.5 w-1.5 h-1.5 rounded-full bg-[#FFFFFF26]"></div>
            )}

            {/* Content Icon */}
            <div className="mt-3">
                {isSelected ? (
                    <Check className="w-6 h-6 text-white" strokeWidth={3} />
                ) : slot.taken ? (
                    <Car className="w-6 h-6 text-[#EF4444]" strokeWidth={2.5} />
                ) : (
                    <span className="font-mono font-bold text-lg text-[#4ADE80]">P</span>
                )}
            </div>
        </div>
    );
}
