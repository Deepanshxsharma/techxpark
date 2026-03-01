import { useState, useEffect } from 'react';
import { db } from '../firebase';
import {
    collection, getDocs, addDoc, doc,
    updateDoc, serverTimestamp, query,
    where
} from 'firebase/firestore';
import { useAuth } from '../context/AuthContext';
import toast from 'react-hot-toast';
import { Search, X, ChevronRight, Check, MapPin, Building2, Car, DollarSign, Loader2, ArrowLeft, Send, CheckCircle2 } from 'lucide-react';

export default function AskAccessModal({ isOpen, onClose }) {
    const { user, userData, uid } = useAuth();
    const [lots, setLots] = useState([]);
    const [selectedLot, setSelectedLot] = useState(null);
    const [message, setMessage] = useState('');
    const [loading, setLoading] = useState(false);
    const [lotsLoading, setLotsLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [step, setStep] = useState(1);

    useEffect(() => {
        if (!isOpen) return;
        fetchLots();
        setSelectedLot(null);
        setMessage('');
        setSearch('');
        setStep(1);
    }, [isOpen]);

    const fetchLots = async () => {
        setLotsLoading(true);
        try {
            const snap = await getDocs(collection(db, 'parking_locations'));
            const allLots = snap.docs.map(d => ({ id: d.id, ...d.data() }));
            const sorted = allLots.sort((a, b) => {
                if (!a.isAssigned && b.isAssigned) return -1;
                if (a.isAssigned && !b.isAssigned) return 1;
                return (a.name || '').localeCompare(b.name || '');
            });
            setLots(sorted);
        } catch (err) {
            console.error('Fetch lots error:', err);
            toast.error('Failed to load parking lots');
        }
        setLotsLoading(false);
    };

    const filteredLots = lots.filter(lot =>
        (lot.name || '').toLowerCase().includes(search.toLowerCase()) ||
        (lot.address || '').toLowerCase().includes(search.toLowerCase())
    );

    const handleSubmit = async () => {
        if (!selectedLot) return;
        setLoading(true);
        try {
            const existing = await getDocs(
                query(
                    collection(db, 'access_requests'),
                    where('ownerId', '==', uid),
                    where('lotId', '==', selectedLot.id),
                    where('status', '==', 'pending')
                )
            );
            if (!existing.empty) {
                toast.error('You already have a pending request for this lot!');
                setLoading(false);
                return;
            }

            const reqRef = await addDoc(collection(db, 'access_requests'), {
                ownerId: uid,
                ownerName: userData?.name || 'Owner',
                ownerEmail: user?.email || '',
                ownerPhone: userData?.phone || '',
                lotId: selectedLot.id,
                lotName: selectedLot.name,
                status: 'pending',
                requestedAt: serverTimestamp(),
                reviewedAt: null,
                reviewedBy: null,
                rejectionReason: null,
                message: message.trim(),
                requestType: 'direct_request',
            });

            if (userData?.accessStatus !== 'approved') {
                await updateDoc(doc(db, 'users', uid), {
                    accessStatus: 'pending',
                    requestId: reqRef.id,
                });
            }

            setStep(3);
        } catch (err) {
            console.error('Request error:', err);
            toast.error('Failed to send request. Try again.');
        }
        setLoading(false);
    };

    if (!isOpen) return null;

    return (
        <div
            className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4"
            onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
        >
            <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col overflow-hidden animate-in fade-in zoom-in-95 duration-200">
                {/* Header */}
                <div className="px-6 py-5 border-b border-border flex items-center justify-between shrink-0">
                    <div>
                        <h2 className="text-lg font-bold text-text-primary tracking-tight">
                            {step === 1 && 'Request Lot Access'}
                            {step === 2 && 'Confirm Request'}
                            {step === 3 && 'Request Sent!'}
                        </h2>
                        <p className="text-sm text-text-secondary mt-0.5">
                            {step === 1 && 'Select a parking lot to manage'}
                            {step === 2 && 'Add a note and confirm'}
                            {step === 3 && 'Admin will review shortly'}
                        </p>
                    </div>
                    <button onClick={onClose} className="w-8 h-8 bg-bg-light rounded-full flex items-center justify-center text-text-tertiary hover:bg-surface-hover hover:text-text-primary transition-colors">
                        <X className="w-4 h-4" />
                    </button>
                </div>

                {/* Step indicator */}
                {step < 3 && (
                    <div className="px-6 pt-4 flex items-center gap-2 shrink-0">
                        {[1, 2].map(s => (
                            <div key={s} className="flex items-center gap-2 flex-1">
                                <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold transition-all shrink-0 ${step >= s ? 'bg-primary text-white' : 'bg-bg-light text-text-tertiary border border-border'}`}>
                                    {step > s ? <Check className="w-3.5 h-3.5" /> : s}
                                </div>
                                <span className={`text-xs font-semibold ${step >= s ? 'text-text-primary' : 'text-text-tertiary'}`}>
                                    {s === 1 ? 'Select Lot' : 'Confirm'}
                                </span>
                                {s < 2 && <div className={`flex-1 h-0.5 rounded ${step > s ? 'bg-primary' : 'bg-border'}`} />}
                            </div>
                        ))}
                    </div>
                )}

                {/* Content */}
                <div className="flex-1 overflow-y-auto px-6 py-4">
                    {/* STEP 1 */}
                    {step === 1 && (
                        <div>
                            <div className="relative mb-4">
                                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-tertiary" />
                                <input
                                    type="text"
                                    placeholder="Search by name or address..."
                                    value={search}
                                    onChange={e => setSearch(e.target.value)}
                                    className="w-full bg-bg-light border border-border rounded-xl pl-10 pr-4 py-2.5 text-sm font-medium text-text-primary outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all"
                                />
                            </div>

                            {lotsLoading ? (
                                <div className="flex justify-center py-12">
                                    <Loader2 className="w-6 h-6 text-primary animate-spin" />
                                </div>
                            ) : filteredLots.length === 0 ? (
                                <div className="text-center py-12">
                                    <MapPin className="w-8 h-8 text-text-tertiary mx-auto mb-3" />
                                    <p className="text-sm font-semibold text-text-secondary">No lots found</p>
                                    <p className="text-xs text-text-tertiary mt-1">Try a different search term</p>
                                </div>
                            ) : (
                                <div className="space-y-2">
                                    {filteredLots.map(lot => {
                                        const isCurrentLot = lot.id === userData?.assignedLotId;
                                        return (
                                            <button
                                                key={lot.id}
                                                onClick={() => { if (!isCurrentLot) setSelectedLot(lot); }}
                                                disabled={isCurrentLot}
                                                className={`w-full text-left p-4 rounded-xl border-2 transition-all ${isCurrentLot
                                                    ? 'border-success/30 bg-success/5 cursor-not-allowed opacity-70'
                                                    : selectedLot?.id === lot.id
                                                        ? 'border-primary bg-primary/5'
                                                        : 'border-border hover:border-primary/40 hover:bg-bg-light'
                                                    }`}
                                            >
                                                <div className="flex items-start justify-between gap-3">
                                                    <div className="flex-1 min-w-0">
                                                        <div className="flex items-center gap-2 mb-1">
                                                            <p className="font-bold text-text-primary text-sm truncate">{lot.name}</p>
                                                            {isCurrentLot && (
                                                                <span className="bg-success/10 text-success text-[10px] px-2 py-0.5 rounded-full font-bold shrink-0">Current</span>
                                                            )}
                                                        </div>
                                                        <p className="text-xs text-text-secondary truncate mb-2 flex items-center gap-1">
                                                            <MapPin className="w-3 h-3 shrink-0" /> {lot.address || 'No address'}
                                                        </p>
                                                        <div className="flex items-center gap-3 flex-wrap">
                                                            <span className="text-[11px] text-text-tertiary font-medium flex items-center gap-1">
                                                                <Building2 className="w-3 h-3" /> {lot.total_floors || 0} floors
                                                            </span>
                                                            <span className="text-[11px] text-text-tertiary font-medium flex items-center gap-1">
                                                                <Car className="w-3 h-3" /> {lot.total_slots || 0} slots
                                                            </span>
                                                            {lot.pricePerHour > 0 && (
                                                                <span className="text-[11px] text-text-tertiary font-medium">
                                                                    ₹{lot.pricePerHour}/hr
                                                                </span>
                                                            )}
                                                        </div>
                                                    </div>
                                                    <div className="flex flex-col items-end gap-1.5 shrink-0">
                                                        <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold ${lot.isAssigned ? 'bg-warning/10 text-warning' : 'bg-success/10 text-success'}`}>
                                                            {lot.isAssigned ? 'Has Manager' : 'Available'}
                                                        </span>
                                                        {selectedLot?.id === lot.id && (
                                                            <div className="w-5 h-5 bg-primary rounded-full flex items-center justify-center">
                                                                <Check className="w-3 h-3 text-white" />
                                                            </div>
                                                        )}
                                                    </div>
                                                </div>

                                                {lot.isAssigned && !isCurrentLot && selectedLot?.id === lot.id && (
                                                    <div className="mt-3 bg-warning/5 border border-warning/20 rounded-lg p-2.5">
                                                        <p className="text-[11px] text-warning font-medium">
                                                            ⚠️ This lot already has a manager. Admin will decide whether to reassign.
                                                        </p>
                                                    </div>
                                                )}
                                            </button>
                                        );
                                    })}
                                </div>
                            )}
                        </div>
                    )}

                    {/* STEP 2 */}
                    {step === 2 && selectedLot && (
                        <div className="space-y-5">
                            <div className="bg-primary/5 border border-primary/20 rounded-xl p-4">
                                <p className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider mb-2">Requesting Access To</p>
                                <p className="font-bold text-text-primary">{selectedLot.name}</p>
                                <p className="text-sm text-text-secondary mt-0.5">{selectedLot.address}</p>
                                <div className="flex gap-3 mt-2 text-[11px] text-text-tertiary font-medium">
                                    <span>{selectedLot.total_floors || 0} floors</span>
                                    <span>{selectedLot.total_slots || 0} slots</span>
                                    {selectedLot.pricePerHour > 0 && <span>₹{selectedLot.pricePerHour}/hr</span>}
                                </div>
                            </div>

                            <div className="bg-bg-light border border-border rounded-xl p-4">
                                <p className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider mb-2">Sending As</p>
                                <p className="text-sm font-bold text-text-primary">{userData?.name || 'Owner'}</p>
                                <p className="text-xs text-text-secondary">{user?.email}</p>
                                {userData?.phone && <p className="text-xs text-text-secondary">{userData.phone}</p>}
                            </div>

                            <div>
                                <label className="block text-sm font-bold text-text-primary mb-2">
                                    Message to Admin <span className="text-text-tertiary font-normal">(optional)</span>
                                </label>
                                <textarea
                                    value={message}
                                    onChange={e => setMessage(e.target.value)}
                                    placeholder="e.g. I have experience managing parking facilities and would like to manage this location..."
                                    maxLength={500}
                                    rows={4}
                                    className="w-full border border-border rounded-xl px-4 py-3 text-sm text-text-primary outline-none resize-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all"
                                />
                                <p className="text-xs text-text-tertiary text-right mt-1">{message.length}/500</p>
                            </div>
                        </div>
                    )}

                    {/* STEP 3 */}
                    {step === 3 && (
                        <div className="text-center py-6">
                            <div className="w-16 h-16 bg-success/10 rounded-full flex items-center justify-center mx-auto mb-4">
                                <CheckCircle2 className="w-8 h-8 text-success" />
                            </div>
                            <h3 className="text-xl font-bold text-text-primary mb-2">Request Sent!</h3>
                            <p className="text-text-secondary text-sm mb-6">
                                Your request for <strong>{selectedLot?.name}</strong> has been sent to the super admin.
                            </p>
                            <div className="bg-bg-light border border-border rounded-xl p-4 text-left space-y-2">
                                <p className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider mb-3">What happens next</p>
                                {['Request received by admin', 'Admin reviews your request', 'You get notified of decision', 'Access granted automatically'].map((item, i) => (
                                    <p key={i} className="text-sm text-text-secondary flex items-center gap-2">
                                        <span className={`w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold shrink-0 ${i === 0 ? 'bg-success/10 text-success' : 'bg-bg-light border border-border text-text-tertiary'}`}>{i + 1}</span>
                                        {item}
                                    </p>
                                ))}
                            </div>
                            <p className="text-xs text-text-tertiary mt-4">
                                If approved, your dashboard will update automatically — no refresh needed!
                            </p>
                        </div>
                    )}
                </div>

                {/* Footer */}
                <div className="px-6 py-4 border-t border-border flex gap-3 shrink-0">
                    {step === 1 && (
                        <>
                            <button onClick={onClose} className="flex-1 py-2.5 border border-border text-text-secondary rounded-xl font-semibold text-sm hover:bg-bg-light transition-colors">
                                Cancel
                            </button>
                            <button
                                onClick={() => { if (!selectedLot) { toast.error('Please select a parking lot'); return; } setStep(2); }}
                                disabled={!selectedLot}
                                className="flex-1 bg-primary text-white py-2.5 rounded-xl font-bold text-sm hover:bg-primary-dark transition-colors disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-1.5"
                            >
                                Next <ChevronRight className="w-4 h-4" />
                            </button>
                        </>
                    )}
                    {step === 2 && (
                        <>
                            <button onClick={() => setStep(1)} className="flex-1 py-2.5 border border-border text-text-secondary rounded-xl font-semibold text-sm hover:bg-bg-light transition-colors flex items-center justify-center gap-1.5">
                                <ArrowLeft className="w-4 h-4" /> Back
                            </button>
                            <button
                                onClick={handleSubmit}
                                disabled={loading}
                                className="flex-1 bg-primary text-white py-2.5 rounded-xl font-bold text-sm hover:bg-primary-dark transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-1.5"
                            >
                                {loading ? <><Loader2 className="w-4 h-4 animate-spin" /> Sending...</> : <><Send className="w-4 h-4" /> Send Request</>}
                            </button>
                        </>
                    )}
                    {step === 3 && (
                        <button onClick={onClose} className="w-full bg-primary text-white py-2.5 rounded-xl font-bold text-sm hover:bg-primary-dark transition-colors">
                            Done
                        </button>
                    )}
                </div>
            </div>
        </div>
    );
}
