import { useState, useEffect } from 'react';
import { db } from '../../firebase';
import {
    collection, getDocs, addDoc, doc,
    updateDoc, serverTimestamp, query, where
} from 'firebase/firestore';
import { useAuth } from '../../context/AuthContext';
import toast from 'react-hot-toast';

export default function RequestAccessScreen() {
    const { user, userData, logout } = useAuth();
    const [lots, setLots] = useState([]);
    const [selectedLot, setSelectedLot] = useState(null);
    const [message, setMessage] = useState('');
    const [loading, setLoading] = useState(false);
    const [lotsLoading, setLotsLoading] = useState(true);

    // Fetch ONLY unassigned lots
    useEffect(() => {
        const fetchLots = async () => {
            try {
                const snap = await getDocs(
                    query(
                        collection(db, 'parking_locations'),
                        where('isAssigned', '!=', true)
                    )
                );
                const available = snap.docs.map(d => ({ id: d.id, ...d.data() }));
                setLots(available);
            } catch (err) {
                // Fallback: fetch all and filter client-side
                try {
                    const snap = await getDocs(collection(db, 'parking_locations'));
                    const available = snap.docs
                        .map(d => ({ id: d.id, ...d.data() }))
                        .filter(l => !l.isAssigned);
                    setLots(available);
                } catch (err2) {
                    console.error('Failed to fetch lots:', err2);
                    toast.error('Failed to load parking lots');
                }
            }
            setLotsLoading(false);
        };
        fetchLots();
    }, []);

    const handleSubmit = async () => {
        if (!selectedLot) {
            toast.error('Please select a parking lot');
            return;
        }
        if (!user) {
            toast.error('Not authenticated');
            return;
        }
        setLoading(true);
        try {
            // 1. Create access request document
            const reqRef = await addDoc(
                collection(db, 'access_requests'),
                {
                    ownerId: user.uid,
                    ownerName: userData?.name || 'Owner',
                    ownerEmail: user.email || '',
                    ownerPhone: userData?.phone || '',
                    lotId: selectedLot.id,
                    lotName: selectedLot.name,
                    status: 'pending',
                    requestedAt: serverTimestamp(),
                    reviewedAt: null,
                    reviewedBy: null,
                    rejectionReason: null,
                    message: message.trim(),
                }
            );

            // 2. Update owner's user document
            await updateDoc(
                doc(db, 'users', user.uid),
                {
                    accessStatus: 'pending',
                    requestId: reqRef.id,
                }
            );

            toast.success('Request submitted successfully!');
            // AuthContext onSnapshot will auto-detect the status change and show PendingScreen
        } catch (error) {
            console.error('Submit error:', error);
            toast.error('Failed to submit. Try again.');
        }
        setLoading(false);
    };

    return (
        <div className="min-h-screen bg-[#F4F6FB] flex items-center justify-center p-4">
            <div className="bg-white rounded-3xl shadow-xl w-full max-w-lg p-8">

                {/* Header */}
                <div className="text-center mb-8">
                    <div className="w-16 h-16 bg-[#2845D6] rounded-2xl flex items-center justify-center mx-auto mb-4 text-3xl">
                        🅿️
                    </div>
                    <h1 className="text-2xl font-black text-[#0D1117] tracking-tight">
                        Request Lot Access
                    </h1>
                    <p className="text-[#5C6B8A] text-sm mt-2">
                        Select the parking lot you manage and submit a request to the admin
                    </p>
                </div>

                {/* Lot Selector */}
                <div className="mb-5">
                    <label className="block text-sm font-bold text-[#0D1117] mb-2">
                        Select Your Parking Lot
                    </label>

                    {lotsLoading ? (
                        <div className="space-y-2">
                            {[1, 2, 3].map(i => (
                                <div key={i} className="h-16 bg-gray-100 rounded-xl animate-pulse" />
                            ))}
                        </div>
                    ) : lots.length === 0 ? (
                        <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 text-amber-700 text-sm text-center">
                            ⚠️ No available lots found. Contact admin to add your lot first.
                        </div>
                    ) : (
                        <div className="space-y-2 max-h-52 overflow-y-auto pr-1">
                            {lots.map(lot => (
                                <div
                                    key={lot.id}
                                    onClick={() => setSelectedLot(lot)}
                                    className={`p-4 rounded-xl border-2 cursor-pointer transition-all ${selectedLot?.id === lot.id
                                        ? 'border-[#2845D6] bg-[#EEF2FF]'
                                        : 'border-[#E8ECF4] hover:border-[#C7D2FE]'
                                        }`}
                                >
                                    <div className="flex items-center justify-between">
                                        <div>
                                            <p className="font-bold text-[#0D1117] text-sm">📍 {lot.name}</p>
                                            <p className="text-xs text-[#5C6B8A] mt-0.5">{lot.address}</p>
                                            <p className="text-xs text-[#9AA5BC] mt-0.5">
                                                {lot.total_slots || 0} slots • {lot.total_floors || 0} floors • ₹{lot.pricePerHour || 0}/hr
                                            </p>
                                        </div>
                                        {selectedLot?.id === lot.id && (
                                            <div className="w-6 h-6 bg-[#2845D6] rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
                                                ✓
                                            </div>
                                        )}
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </div>

                {/* Message */}
                <div className="mb-5">
                    <label className="block text-sm font-bold text-[#0D1117] mb-2">
                        Message to Admin <span className="text-[#9AA5BC] font-normal ml-1">(optional)</span>
                    </label>
                    <textarea
                        value={message}
                        onChange={e => setMessage(e.target.value)}
                        placeholder="e.g. I am the manager of this lot and have been working here since 2022..."
                        maxLength={300}
                        rows={3}
                        className="w-full border-2 border-[#E8ECF4] rounded-xl px-4 py-3 text-sm text-[#0D1117] outline-none resize-none placeholder:text-[#9AA5BC] focus:border-[#2845D6] transition-colors"
                    />
                    <p className="text-xs text-[#9AA5BC] text-right mt-1">{message.length}/300</p>
                </div>

                {/* Your Details */}
                <div className="bg-[#F8FAFF] border border-[#E8ECF4] rounded-xl p-4 mb-6">
                    <p className="text-xs font-bold text-[#9AA5BC] uppercase tracking-wider mb-3">Your Details</p>
                    <div className="space-y-1.5">
                        <p className="text-sm text-[#0D1117]"><span className="text-[#5C6B8A]">Name:</span> {userData?.name || 'Not set'}</p>
                        <p className="text-sm text-[#0D1117]"><span className="text-[#5C6B8A]">Email:</span> {user?.email}</p>
                        <p className="text-sm text-[#0D1117]"><span className="text-[#5C6B8A]">Phone:</span> {userData?.phone || 'Not added'}</p>
                    </div>
                </div>

                {/* Submit */}
                <button
                    onClick={handleSubmit}
                    disabled={loading || !selectedLot || lotsLoading}
                    className="w-full bg-[#2845D6] text-white py-4 rounded-xl font-bold text-sm hover:bg-[#1E36B5] transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                >
                    {loading ? (
                        <>
                            <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                            Submitting Request...
                        </>
                    ) : (
                        '📨 Submit Access Request'
                    )}
                </button>

                <button
                    onClick={logout}
                    className="w-full mt-3 py-2.5 text-[#9AA5BC] text-sm hover:text-[#5C6B8A] transition-colors"
                >
                    Sign out of this account
                </button>
            </div>
        </div>
    );
}
