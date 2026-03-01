import React, { useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { useAllAccessRequests } from '../../hooks/useAccessRequest';
import { db } from '../../firebase';
import { doc, updateDoc, writeBatch, serverTimestamp, collection, addDoc } from 'firebase/firestore';
import { toast } from 'react-hot-toast';
import { format } from 'date-fns';
import { ShieldCheck, XCircle, Search, AlertCircle, RefreshCw, CheckCircle2, Clock, Users, Building2 } from 'lucide-react';
import Button from '../../components/ui/Button';

export default function AccessRequests() {
    const { user: adminUser } = useAuth();
    const [statusFilter, setStatusFilter] = useState('all');
    const { requests, loading } = useAllAccessRequests(statusFilter);

    // Dialog state
    const [actionDialog, setActionDialog] = useState(null); // { type: 'approve' | 'reject', request: obj }
    const [rejectionReason, setRejectionReason] = useState('');
    const [isProcessing, setIsProcessing] = useState(false);

    // Derived Stats
    const { requests: allRequestsForStats } = useAllAccessRequests('all'); // Need all for accurate top stats

    // Fallback if allRequestsForStats isn't loaded yet
    const pendingCount = (allRequestsForStats || []).filter(r => r.status === 'pending').length;
    const approvedCount = (allRequestsForStats || []).filter(r => r.status === 'approved').length;
    const rejectedCount = (allRequestsForStats || []).filter(r => r.status === 'rejected').length;

    const handleApprove = async () => {
        if (!actionDialog?.request) return;
        setIsProcessing(true);

        try {
            const req = actionDialog.request;
            const batch = writeBatch(db);

            // 1. Update the request document
            const reqRef = doc(db, 'access_requests', req.id);
            batch.update(reqRef, {
                status: 'approved',
                reviewedAt: serverTimestamp(),
                reviewedBy: adminUser.uid
            });

            // 2. Update the user document
            const userRef = doc(db, 'users', req.ownerId);
            batch.update(userRef, {
                accessStatus: 'approved',
                assignedLotId: req.lotId
            });

            // 3. Update the parking lot
            const lotRef = doc(db, 'parking_locations', req.lotId);
            batch.update(lotRef, {
                assignedOwnerId: req.ownerId,
                isAssigned: true
            });

            await batch.commit();

            // 4. Send Notification to Owner
            await addDoc(collection(db, 'notifications'), {
                ownerId: req.ownerId,
                title: '🎉 Access Approved!',
                body: `You now have access to ${req.lotName}. Login to get started!`,
                type: 'access_approved',
                createdAt: serverTimestamp(),
                read: false,
                linkId: req.id
            });

            toast.success(`Access granted to ${req.ownerName}`);
            setActionDialog(null);
        } catch (error) {
            console.error("Approve error:", error);
            toast.error("Failed to approve access");
        } finally {
            setIsProcessing(false);
        }
    };

    const handleReject = async () => {
        if (!actionDialog?.request) return;
        if (!rejectionReason.trim()) {
            toast.error("Please provide a rejection reason");
            return;
        }

        setIsProcessing(true);

        try {
            const req = actionDialog.request;
            const batch = writeBatch(db);

            // 1. Update the request document
            const reqRef = doc(db, 'access_requests', req.id);
            batch.update(reqRef, {
                status: 'rejected',
                reviewedAt: serverTimestamp(),
                reviewedBy: adminUser.uid,
                rejectionReason: rejectionReason.trim()
            });

            // 2. Update user status to explicitly rejected
            const userRef = doc(db, 'users', req.ownerId);
            batch.update(userRef, {
                accessStatus: 'rejected'
            });

            await batch.commit();

            // 3. Send Notification to Owner
            await addDoc(collection(db, 'notifications'), {
                ownerId: req.ownerId,
                title: 'Access Request Update',
                body: `Your request for ${req.lotName} was not approved. Tap to see details.`,
                type: 'access_rejected',
                createdAt: serverTimestamp(),
                read: false,
                linkId: req.id
            });

            toast.success("Request rejected");
            setActionDialog(null);
            setRejectionReason('');
        } catch (error) {
            console.error("Reject error:", error);
            toast.error("Failed to reject request");
        } finally {
            setIsProcessing(false);
        }
    };

    const quickReasons = [
        "This lot already has an assigned manager.",
        "Invalid identity details provided.",
        "Duplicate request found.",
        "Please contact HQ for further verification."
    ];

    if (loading) {
        return (
            <div className="flex-1 flex items-center justify-center p-8 text-text-tertiary">
                <RefreshCw className="w-6 h-6 animate-spin" />
            </div>
        );
    }

    return (
        <div className="flex-1 overflow-y-auto bg-bg-light p-6 md:p-10 font-sans text-text-primary">

            <div className="max-w-[1200px] mx-auto animate-in fade-in duration-300">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
                    <div>
                        <h1 className="text-3xl font-bold tracking-tight mb-1">Access Requests</h1>
                        <p className="text-[15px] font-medium text-text-secondary">Review and approve owner management assignments.</p>
                    </div>
                </div>

                {/* Stat Cards */}
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
                    <div className="bg-white border border-border p-5 rounded-xl shadow-sm flex items-center gap-4">
                        <div className="w-12 h-12 bg-warning-bg rounded-lg border border-warning/20 flex items-center justify-center text-warning shrink-0">
                            <Clock className="w-6 h-6" />
                        </div>
                        <div>
                            <p className="text-[12px] font-bold text-text-tertiary uppercase tracking-[0.5px]">Pending Approval</p>
                            <p className="text-3xl font-bold tracking-tight mt-1">{pendingCount}</p>
                        </div>
                    </div>
                    <div className="bg-white border border-border p-5 rounded-xl shadow-sm flex items-center gap-4">
                        <div className="w-12 h-12 bg-success-bg rounded-lg border border-success/20 flex items-center justify-center text-success shrink-0">
                            <CheckCircle2 className="w-6 h-6" />
                        </div>
                        <div>
                            <p className="text-[12px] font-bold text-text-tertiary uppercase tracking-[0.5px]">Approved Total</p>
                            <p className="text-3xl font-bold tracking-tight mt-1">{approvedCount}</p>
                        </div>
                    </div>
                    <div className="bg-white border border-border p-5 rounded-xl shadow-sm flex items-center gap-4">
                        <div className="w-12 h-12 bg-error-bg rounded-lg border border-error/20 flex items-center justify-center text-error shrink-0">
                            <XCircle className="w-6 h-6" />
                        </div>
                        <div>
                            <p className="text-[12px] font-bold text-text-tertiary uppercase tracking-[0.5px]">Rejected Total</p>
                            <p className="text-3xl font-bold tracking-tight mt-1">{rejectedCount}</p>
                        </div>
                    </div>
                </div>

                {/* Filter Tabs */}
                <div className="flex items-center gap-2 mb-6 border-b border-border pb-1 overflow-x-auto scrollbar-none">
                    {['all', 'pending', 'approved', 'rejected'].map(status => (
                        <button
                            key={status}
                            onClick={() => setStatusFilter(status)}
                            className={`px-4 py-2 rounded-lg text-[14px] font-bold capitalize transition-colors whitespace-nowrap ${statusFilter === status
                                    ? 'bg-primary text-white shadow-sm'
                                    : 'text-text-secondary hover:bg-bg-light hover:text-text-primary'
                                }`}
                        >
                            {status}
                        </button>
                    ))}
                </div>

                {/* Request List */}
                {requests.length === 0 ? (
                    <div className="bg-white border border-border border-dashed rounded-xl p-16 flex flex-col items-center justify-center text-center">
                        <div className="w-16 h-16 bg-surface-hover rounded-full flex items-center justify-center mb-4 text-text-tertiary">
                            <Search className="w-8 h-8" />
                        </div>
                        <h3 className="text-[17px] font-bold text-text-primary mb-1">No requests found</h3>
                        <p className="text-[14px] text-text-secondary">There are no {statusFilter !== 'all' ? statusFilter : ''} access requests at this time.</p>
                    </div>
                ) : (
                    <div className="space-y-4">
                        {requests.map(req => {
                            let statusColor = "bg-white border-border border-l-border";
                            if (req.status === 'pending') statusColor = "bg-white border-border border-l-blue-500 shadow-sm";
                            if (req.status === 'approved') statusColor = "bg-success-bg/30 border-success/30 border-l-success";
                            if (req.status === 'rejected') statusColor = "bg-error-bg/30 border-error/20 border-l-error";

                            return (
                                <div key={req.id} className={`p-6 rounded-xl border border-l-[4px] relative overflow-hidden transition-all ${statusColor}`}>
                                    <div className="flex flex-col md:flex-row md:items-start justify-between gap-6">

                                        {/* User Info */}
                                        <div className="flex-1">
                                            <div className="flex items-center gap-3 mb-1">
                                                <div className="w-10 h-10 bg-surface rounded-full flex items-center justify-center text-[15px] font-bold text-text-primary border border-border shrink-0">
                                                    {(req.ownerName || 'U')[0].toUpperCase()}
                                                </div>
                                                <div>
                                                    <h3 className="font-bold text-[16px] text-text-primary leading-tight">{req.ownerName}</h3>
                                                    <p className="text-[12px] font-medium text-text-tertiary">
                                                        {req.ownerEmail} • {req.ownerPhone || 'No phone'}
                                                    </p>
                                                </div>
                                                <div className="ml-auto md:ml-4 text-[12px] font-bold text-text-tertiary whitespace-nowrap hidden md:block">
                                                    {req.requestedAt ? format(req.requestedAt.toDate(), "MMM d, h:mm a") : '...'}
                                                </div>
                                            </div>

                                            <div className="mt-5 space-y-3">
                                                <div className="flex items-start gap-2">
                                                    <Building2 className="w-4 h-4 text-text-tertiary shrink-0 mt-0.5" />
                                                    <div>
                                                        <span className="text-[12px] font-bold text-text-tertiary uppercase tracking-[0.5px] block mb-0.5">Requesting Access To</span>
                                                        <p className="text-[14px] font-bold text-text-primary">{req.lotName}</p>
                                                    </div>
                                                </div>

                                                {req.message && (
                                                    <div className="bg-surface p-3 rounded-lg border border-border mt-3">
                                                        <span className="text-[11px] font-bold text-text-tertiary uppercase tracking-[0.8px] block mb-1">Owner Message</span>
                                                        <p className="text-[13px] font-medium text-text-secondary italic">"{req.message}"</p>
                                                    </div>
                                                )}
                                            </div>
                                        </div>

                                        {/* Actions */}
                                        <div className="flex flex-row md:flex-col items-center justify-end md:justify-start gap-2 pt-4 md:pt-0 border-t border-border md:border-none w-full md:w-auto">
                                            {req.status === 'pending' ? (
                                                <>
                                                    <Button
                                                        variant="primary"
                                                        className="w-full md:w-32 bg-success text-white hover:bg-success/90 border-transparent shadow-sm"
                                                        onClick={() => setActionDialog({ type: 'approve', request: req })}
                                                        icon={CheckCircle2}
                                                    >
                                                        Approve
                                                    </Button>
                                                    <Button
                                                        variant="secondary"
                                                        className="w-full md:w-32 hover:bg-error/10 hover:text-error hover:border-error/30"
                                                        onClick={() => setActionDialog({ type: 'reject', request: req })}
                                                        icon={XCircle}
                                                    >
                                                        Reject
                                                    </Button>
                                                </>
                                            ) : (
                                                <div className="flex items-center gap-1.5 px-3 py-1.5 rounded bg-surface border border-border text-[12px] font-bold uppercase tracking-[0.5px]">
                                                    {req.status === 'approved' ? <CheckCircle2 className="w-4 h-4 text-success" /> : <XCircle className="w-4 h-4 text-error" />}
                                                    <span className={req.status === 'approved' ? 'text-success' : 'text-error'}>{req.status}</span>
                                                </div>
                                            )}
                                        </div>
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                )}

                {/* Dialog Overlay */}
                {actionDialog && (
                    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4 animate-in fade-in duration-200">
                        <div className="bg-white rounded-2xl shadow-xl border border-border w-full max-w-[440px] overflow-hidden animate-in zoom-in-95 duration-200">

                            {actionDialog.type === 'approve' && (
                                <>
                                    <div className="p-6 bg-success-bg/40 border-b border-border">
                                        <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center text-success border border-success/20 mb-4 shadow-sm">
                                            <CheckCircle2 className="w-6 h-6" />
                                        </div>
                                        <h3 className="text-[20px] font-bold text-text-primary mb-1">Approve Access</h3>
                                        <p className="text-[14px] text-text-secondary leading-relaxed">
                                            Grant <strong className="text-text-primary">{actionDialog.request.ownerName}</strong> access to <strong className="text-text-primary">{actionDialog.request.lotName}</strong>?
                                        </p>
                                    </div>
                                    <div className="p-6 bg-white space-y-4 text-[13px] font-medium text-text-secondary">
                                        <p>This action will immediately:</p>
                                        <ul className="space-y-2 list-disc list-inside text-text-primary">
                                            <li>Assign them as the official lot manager.</li>
                                            <li>Grant full dashboard access to this facility.</li>
                                            <li>Send them an access granted notification.</li>
                                        </ul>
                                    </div>
                                    <div className="p-4 bg-surface border-t border-border flex justify-end gap-3">
                                        <Button variant="ghost" onClick={() => setActionDialog(null)} disabled={isProcessing}>Cancel</Button>
                                        <Button variant="primary" className="bg-success hover:bg-success/90 shadow-sm" onClick={handleApprove} loading={isProcessing}>Approve Now</Button>
                                    </div>
                                </>
                            )}

                            {actionDialog.type === 'reject' && (
                                <>
                                    <div className="p-6 bg-error-bg/40 border-b border-border">
                                        <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center text-error border border-error/20 mb-4 shadow-sm">
                                            <XCircle className="w-6 h-6" />
                                        </div>
                                        <h3 className="text-[20px] font-bold text-text-primary mb-1">Reject Request</h3>
                                        <p className="text-[14px] text-text-secondary leading-relaxed">
                                            Provide a reason for rejecting <strong className="text-text-primary">{actionDialog.request.ownerName}</strong>'s request. This will be shown to them.
                                        </p>
                                    </div>
                                    <div className="p-6 bg-white space-y-4">
                                        <div>
                                            <label className="text-[12px] font-bold text-text-secondary uppercase tracking-[0.5px] block mb-2">Rejection Reason</label>
                                            <textarea
                                                className="w-full px-3 py-2 bg-bg-light border border-border rounded-lg text-[14px] font-medium resize-none min-h-[80px] focus:ring-1 focus:ring-primary focus:border-primary outline-none transition-all"
                                                placeholder="Explain why this was rejected..."
                                                value={rejectionReason}
                                                onChange={(e) => setRejectionReason(e.target.value)}
                                            />
                                        </div>
                                        <div>
                                            <p className="text-[11px] font-bold text-text-tertiary uppercase tracking-[0.8px] mb-2">Quick Reasons</p>
                                            <div className="flex flex-wrap gap-2">
                                                {quickReasons.map((reason, i) => (
                                                    <button
                                                        key={i}
                                                        onClick={() => setRejectionReason(reason)}
                                                        className="px-2.5 py-1.5 bg-surface hover:bg-bg-light border border-border rounded text-[12px] font-semibold text-text-secondary transition-colors text-left"
                                                    >
                                                        {reason}
                                                    </button>
                                                ))}
                                            </div>
                                        </div>
                                    </div>
                                    <div className="p-4 bg-surface border-t border-border flex justify-end gap-3">
                                        <Button variant="ghost" onClick={() => { setActionDialog(null); setRejectionReason(''); }} disabled={isProcessing}>Cancel</Button>
                                        <Button variant="secondary" className="hover:bg-error hover:text-white border-transparent" onClick={handleReject} loading={isProcessing}>Reject Request</Button>
                                    </div>
                                </>
                            )}

                        </div>
                    </div>
                )}

            </div>
        </div>
    );
}
