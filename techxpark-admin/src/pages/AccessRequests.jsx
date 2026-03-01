import React, { useState, useEffect } from 'react';
import { db, auth } from '../firebase';
import {
    collection,
    query,
    where,
    orderBy,
    onSnapshot,
    doc,
    updateDoc,
    serverTimestamp,
    writeBatch
} from 'firebase/firestore';
import { format } from 'date-fns';
import {
    Clock,
    CheckCircle2,
    XCircle,
    Search,
    Filter,
    User,
    Mail,
    Phone,
    MapPin,
    AlertCircle
} from 'lucide-react';
import Card from '../components/ui/Card';
import Badge from '../components/ui/Badge';
import toast from 'react-hot-toast';

export default function AccessRequests() {
    const [requests, setRequests] = useState([]);
    const [loading, setLoading] = useState(true);
    const [filter, setFilter] = useState('pending');
    const [searchQuery, setSearchQuery] = useState('');
    const [processingId, setProcessingId] = useState(null);

    useEffect(() => {
        setLoading(true);
        let q = collection(db, 'access_requests');

        if (filter !== 'all') {
            q = query(q, where('status', '==', filter), orderBy('requestedAt', 'desc'));
        } else {
            q = query(q, orderBy('requestedAt', 'desc'));
        }

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const reqs = snapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data()
            }));
            setRequests(reqs);
            setLoading(false);
        }, (error) => {
            console.error("Error listening to access requests:", error);
            toast.error("Failed to load requests");
            setLoading(false);
        });

        return () => unsubscribe();
    }, [filter]);

    const filteredRequests = requests.filter(req =>
        req.ownerName?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        req.ownerEmail?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        req.lotName?.toLowerCase().includes(searchQuery.toLowerCase())
    );

    const handleApprove = async (request) => {
        if (!window.confirm(`Approve ${request.ownerName} for ${request.lotName}?`)) return;

        setProcessingId(request.id);
        try {
            const adminUid = auth.currentUser?.uid;
            if (!adminUid) throw new Error("No admin authenticated");

            // Atomic batch write — all or nothing
            const batch = writeBatch(db);

            // 1. Update access_requests
            batch.update(doc(db, 'access_requests', request.id), {
                status: 'approved',
                reviewedAt: serverTimestamp(),
                reviewedBy: adminUid
            });

            // 2. Update users
            batch.update(doc(db, 'users', request.ownerId), {
                accessStatus: 'approved',
                assignedLotId: request.lotId,
            });

            // 3. Lock lot to this owner
            batch.update(doc(db, 'parking_locations', request.lotId), {
                assignedOwnerId: request.ownerId,
                isAssigned: true,
            });

            await batch.commit();
            toast.success(`✅ Access granted to ${request.ownerName}!`);
        } catch (error) {
            console.error("Approve error:", error);
            toast.error("Failed to approve. Try again.");
        }
        setProcessingId(null);
    };

    const handleReject = async (request) => {
        const reason = window.prompt("Enter rejection reason (shown to owner):");
        if (!reason?.trim()) return;

        setProcessingId(request.id);
        try {
            const adminUid = auth.currentUser?.uid;
            if (!adminUid) throw new Error("No admin authenticated");

            const batch = writeBatch(db);

            batch.update(doc(db, 'access_requests', request.id), {
                status: 'rejected',
                rejectionReason: reason.trim(),
                reviewedAt: serverTimestamp(),
                reviewedBy: adminUid
            });

            batch.update(doc(db, 'users', request.ownerId), {
                accessStatus: 'rejected',
                rejectionReason: reason.trim(),
            });

            await batch.commit();
            toast.success('Request rejected');
        } catch (error) {
            console.error("Reject error:", error);
            toast.error("Failed to reject. Try again.");
        }
        setProcessingId(null);
    };

    return (
        <div className="space-y-6 animate-fade-in pb-10">
            <div>
                <h1 className="text-2xl font-bold text-text-primary tracking-tight">Access Requests</h1>
                <p className="text-sm font-medium text-text-secondary mt-1">Review and manage parking lot ownership access</p>
            </div>

            <div className="flex flex-col md:flex-row gap-4 justify-between items-center bg-surface p-4 rounded-2xl border border-border shadow-sm">
                <div className="flex bg-bg-light p-1 rounded-xl w-full md:w-auto">
                    {['pending', 'approved', 'rejected', 'all'].map((tab) => (
                        <button
                            key={tab}
                            onClick={() => setFilter(tab)}
                            className={`px-4 py-2 rounded-lg text-sm font-bold capitalize transition-all ${filter === tab
                                ? 'bg-white text-primary shadow-sm'
                                : 'text-text-tertiary hover:text-text-secondary'
                                }`}
                        >
                            {tab}
                        </button>
                    ))}
                </div>

                <div className="relative w-full md:w-64">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-tertiary" />
                    <input
                        type="text"
                        placeholder="Search requests..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="w-full pl-10 pr-4 py-2 bg-bg-light rounded-xl border-none text-sm font-medium focus:ring-2 focus:ring-primary/20 outline-none"
                    />
                </div>
            </div>

            {loading ? (
                <div className="h-[40vh] flex items-center justify-center">
                    <div className="w-10 h-10 border-4 border-primary border-t-transparent rounded-full animate-spin" />
                </div>
            ) : filteredRequests.length === 0 ? (
                <div className="flex flex-col items-center justify-center h-[40vh] bg-surface rounded-3xl border border-dashed border-border opacity-60">
                    <AlertCircle className="w-12 h-12 text-text-tertiary mb-3" />
                    <p className="text-lg font-bold text-text-secondary">No requests found</p>
                    <p className="text-sm font-medium text-text-tertiary mt-1">Try changing the filter or search term</p>
                </div>
            ) : (
                <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
                    {filteredRequests.map((req) => (
                        <Card key={req.id} className="overflow-hidden group">
                            <div className="p-6">
                                <div className="flex justify-between items-start mb-6">
                                    <div className="flex gap-4">
                                        <div className="w-12 h-12 rounded-2xl bg-primary/10 flex items-center justify-center shrink-0">
                                            <User className="w-6 h-6 text-primary" />
                                        </div>
                                        <div>
                                            <h3 className="font-bold text-text-primary text-lg">{req.ownerName}</h3>
                                            <div className="flex flex-wrap gap-x-4 gap-y-1 mt-1">
                                                <div className="flex items-center gap-1.5 text-xs font-semibold text-text-tertiary">
                                                    <Mail className="w-3.5 h-3.5" />
                                                    {req.ownerEmail}
                                                </div>
                                                <div className="flex items-center gap-1.5 text-xs font-semibold text-text-tertiary">
                                                    <Phone className="w-3.5 h-3.5" />
                                                    {req.ownerPhone || 'N/A'}
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    <Badge variant={
                                        req.status === 'approved' ? 'success' :
                                            req.status === 'rejected' ? 'error' : 'warning'
                                    }>
                                        {req.status}
                                    </Badge>
                                </div>

                                <div className="bg-bg-light rounded-2xl p-4 mb-6 space-y-3">
                                    <div className="flex items-start gap-3">
                                        <MapPin className="w-4 h-4 text-primary mt-0.5 shrink-0" />
                                        <div>
                                            <p className="text-[10px] font-bold text-text-tertiary uppercase tracking-wider">Requested Lot</p>
                                            <p className="text-sm font-bold text-text-primary leading-tight mt-0.5">{req.lotName}</p>
                                            <p className="text-[11px] font-semibold text-text-tertiary mt-0.5">ID: {req.lotId}</p>
                                        </div>
                                    </div>

                                    {req.message && (
                                        <div className="pt-3 border-t border-border/50">
                                            <p className="text-[10px] font-bold text-text-tertiary uppercase tracking-wider mb-1">Owner Message</p>
                                            <p className="text-sm font-medium text-text-secondary leading-relaxed italic">"{req.message}"</p>
                                        </div>
                                    )}

                                    {req.rejectionReason && (
                                        <div className="pt-3 border-t border-error/20 bg-error/5 p-3 rounded-lg mt-2">
                                            <p className="text-[10px] font-bold text-error uppercase tracking-wider mb-1">Rejection Reason</p>
                                            <p className="text-sm font-medium text-error leading-relaxed italic">"{req.rejectionReason}"</p>
                                        </div>
                                    )}
                                </div>

                                <div className="flex items-center justify-between pt-4 border-t border-border">
                                    <div className="flex items-center gap-1.5 text-[11px] font-bold text-text-tertiary">
                                        <Clock className="w-3.5 h-3.5" />
                                        {req.requestedAt ? format(req.requestedAt.toDate(), 'PPP p') : 'Recent'}
                                    </div>

                                    {req.status === 'pending' && (
                                        <div className="flex gap-2">
                                            <button
                                                onClick={() => handleReject(req)}
                                                disabled={processingId === req.id}
                                                className="px-4 py-2 rounded-xl text-xs font-bold text-error bg-error/10 hover:bg-error hover:text-white transition-all border border-error/20 flex items-center gap-2 disabled:opacity-50"
                                            >
                                                <XCircle className="w-3.5 h-3.5" />
                                                Reject
                                            </button>
                                            <button
                                                onClick={() => handleApprove(req)}
                                                disabled={processingId === req.id}
                                                className="px-4 py-2 rounded-xl text-xs font-bold text-white bg-primary hover:bg-indigo-700 transition-all shadow-sm flex items-center gap-2 disabled:opacity-50"
                                            >
                                                <CheckCircle2 className="w-3.5 h-3.5" />
                                                Approve Access
                                            </button>
                                        </div>
                                    )}
                                </div>
                            </div>
                        </Card>
                    ))}
                </div>
            )}
        </div>
    );
}
