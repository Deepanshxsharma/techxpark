import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, query, onSnapshot, getDoc, doc, updateDoc, getDocs, where, orderBy, limit as fbLimit } from 'firebase/firestore';
import { CalendarCheck, Search, Download, Filter, MoreVertical, CreditCard, Clock, MapPin, X } from 'lucide-react';
import Button from '../components/ui/Button';
import DataTable from '../components/ui/DataTable';
import Badge from '../components/ui/Badge';
import Drawer from '../components/ui/Drawer';
import Modal from '../components/ui/Modal';
import { format } from 'date-fns';
import toast from 'react-hot-toast';
import { formatCurrency, exportToCSV } from '../utils/helpers';

export default function Bookings() {
    const [bookings, setBookings] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [selectedBooking, setSelectedBooking] = useState(null);
    const [statusFilter, setStatusFilter] = useState('all');
    const [cancelTarget, setCancelTarget] = useState(null);
    const [cancelling, setCancelling] = useState(false);

    useEffect(() => {
        const q = query(collection(db, 'bookings'), orderBy('createdAt', 'desc'));

        const unsubscribe = onSnapshot(q, async (snapshot) => {
            const arr = [];
            // Build lookup maps
            const userIds = new Set();
            const lotIds = new Set();
            snapshot.docs.forEach(d => {
                const data = d.data();
                if (data.userId) userIds.add(data.userId);
                if (data.parkingLocationId) lotIds.add(data.parkingLocationId);
                if (data.parkingId) lotIds.add(data.parkingId);
            });

            const userMap = {};
            for (const uid of userIds) {
                try {
                    const snap = await getDoc(doc(db, 'users', uid));
                    if (snap.exists()) userMap[uid] = snap.data().name || 'User';
                } catch (e) { /* skip */ }
            }

            const lotMap = {};
            for (const lid of lotIds) {
                try {
                    const snap = await getDoc(doc(db, 'parking_locations', lid));
                    if (snap.exists()) lotMap[lid] = snap.data().name || 'Lot';
                } catch (e) { /* skip */ }
            }

            snapshot.docs.forEach(d => {
                const data = d.data();
                arr.push({
                    id: d.id,
                    ...data,
                    userName: data.userName || userMap[data.userId] || 'Unknown',
                    lotName: data.parkingName || lotMap[data.parkingLocationId] || lotMap[data.parkingId] || 'Unknown Lot'
                });
            });

            setBookings(arr);
            setLoading(false);
        }, (err) => {
            console.error('Bookings listener error:', err);
            toast.error('Failed to load bookings');
            setLoading(false);
        });

        return () => unsubscribe();
    }, []);

    const handleCancel = async () => {
        if (!cancelTarget) return;
        setCancelling(true);
        try {
            await updateDoc(doc(db, 'bookings', cancelTarget.id), { status: 'cancelled' });
            toast.success('Booking cancelled');
            setCancelTarget(null);
            setSelectedBooking(null);
        } catch (err) {
            toast.error('Failed to cancel booking');
        } finally {
            setCancelling(false);
        }
    };

    const handleExport = () => {
        const rows = filteredBookings.map(b => ({
            'Booking ID': b.id,
            Customer: b.userName,
            Location: b.lotName,
            Vehicle: b.vehicleNumber || '',
            Amount: b.totalAmount || b.amount || 0,
            Status: b.status || 'unknown',
            Date: b.createdAt ? format(b.createdAt.toDate(), 'yyyy-MM-dd HH:mm') : ''
        }));
        exportToCSV(rows, 'bookings');
        toast.success('Bookings exported');
    };

    const statusTabs = [
        { id: 'all', label: 'All' },
        { id: 'active', label: 'Active' },
        { id: 'completed', label: 'Completed' },
        { id: 'pending', label: 'Pending' },
        { id: 'cancelled', label: 'Cancelled' },
    ];

    const filteredBookings = bookings.filter(b => {
        const matchSearch = (b.id?.toLowerCase() || '').includes(searchTerm.toLowerCase()) ||
            (b.userName?.toLowerCase() || '').includes(searchTerm.toLowerCase()) ||
            (b.vehicleNumber?.toLowerCase() || '').includes(searchTerm.toLowerCase());
        if (!matchSearch) return false;
        if (statusFilter === 'all') return true;
        return b.status === statusFilter;
    });

    const columns = [
        {
            header: 'Booking ID',
            accessor: 'id',
            cell: (row) => (
                <div>
                    <span className="font-mono text-[13px] font-bold text-text-primary">{row.id.substring(0, 8).toUpperCase()}</span>
                    <p className="text-[11px] font-medium text-text-secondary mt-0.5">
                        {row.createdAt ? format(row.createdAt.toDate(), 'MMM dd, HH:mm') : 'N/A'}
                    </p>
                </div>
            )
        },
        {
            header: 'Customer',
            accessor: 'userName',
            cell: (row) => (
                <div>
                    <p className="font-bold text-text-primary mb-0.5">{row.userName}</p>
                    <p className="text-[12px] font-medium text-text-secondary">{row.vehicleNumber || 'No Vehicle'}</p>
                </div>
            )
        },
        {
            header: 'Location',
            accessor: 'lotName',
            cell: (row) => (
                <div className="flex items-center gap-1.5 font-semibold text-text-secondary text-[12px]">
                    <MapPin className="w-3.5 h-3.5 text-primary" />
                    {row.lotName}
                </div>
            )
        },
        {
            header: 'Amount',
            accessor: 'totalAmount',
            cell: (row) => (
                <span className="font-extrabold text-[14px] text-text-primary">
                    {formatCurrency(row.totalAmount || row.amount || 0)}
                </span>
            )
        },
        {
            header: 'Status',
            accessor: 'status',
            cell: (row) => {
                const status = row.status || 'pending';
                const variants = { completed: 'success', active: 'info', pending: 'warning', cancelled: 'error' };
                return <Badge variant={variants[status] || 'neutral'}>{status}</Badge>;
            }
        },
        {
            header: '',
            accessor: 'actions',
            align: 'right',
            cell: (row) => (
                <button
                    onClick={(e) => { e.stopPropagation(); setSelectedBooking(row); }}
                    className="p-1.5 rounded-lg text-text-tertiary hover:bg-surface-hover hover:text-text-primary transition-colors"
                >
                    <MoreVertical className="w-4 h-4" />
                </button>
            )
        }
    ];

    return (
        <div className="space-y-6 animate-fade-in pb-10">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-text-primary tracking-tight">Platform Bookings</h1>
                    <p className="text-sm font-medium text-text-secondary mt-1">Monitor all parking sessions across TechXPark.</p>
                </div>
                <div className="flex items-center gap-3">
                    <Button variant="secondary" icon={Download} onClick={handleExport}>Export CSV</Button>
                </div>
            </div>

            {/* Filter Tabs */}
            <div className="flex gap-1 bg-surface border border-border rounded-xl p-1 w-fit">
                {statusTabs.map(tab => (
                    <button
                        key={tab.id}
                        onClick={() => setStatusFilter(tab.id)}
                        className={`px-4 py-2 rounded-lg text-sm font-bold transition-all ${statusFilter === tab.id ? 'bg-white text-primary shadow-sm' : 'text-text-secondary hover:text-text-primary'}`}
                    >{tab.label}</button>
                ))}
            </div>

            {/* Data Table */}
            <DataTable
                columns={columns}
                data={filteredBookings}
                loading={loading}
                searchTerm={searchTerm}
                onSearchChange={setSearchTerm}
                onRowClick={(row) => setSelectedBooking(row)}
            />

            {/* Cancel Confirm */}
            <Modal isOpen={!!cancelTarget} onClose={() => setCancelTarget(null)} title="Cancel Booking" size="sm">
                <div className="space-y-4">
                    <p className="text-sm text-text-secondary">
                        Are you sure you want to cancel booking <strong>{cancelTarget?.id?.substring(0, 8).toUpperCase()}</strong>?
                    </p>
                    <div className="flex gap-3">
                        <Button variant="secondary" className="flex-1" onClick={() => setCancelTarget(null)}>No, Keep</Button>
                        <Button variant="danger" className="flex-1" onClick={handleCancel} disabled={cancelling}>
                            {cancelling ? 'Cancelling...' : 'Yes, Cancel'}
                        </Button>
                    </div>
                </div>
            </Modal>

            {/* Details Drawer */}
            <Drawer
                isOpen={!!selectedBooking}
                onClose={() => setSelectedBooking(null)}
                title="Booking Session Details"
                footer={
                    (selectedBooking?.status === 'active' || selectedBooking?.status === 'pending') ? (
                        <Button variant="danger" className="w-full" onClick={() => { setCancelTarget(selectedBooking); setSelectedBooking(null); }}>
                            Cancel Booking
                        </Button>
                    ) : null
                }
            >
                {selectedBooking && (
                    <div className="space-y-6">
                        <div className="flex items-center justify-between p-5 bg-bg-light border border-border rounded-2xl">
                            <div>
                                <p className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider mb-1">Session ID</p>
                                <p className="font-mono text-lg font-bold text-text-primary">{selectedBooking.id.substring(0, 12)}</p>
                            </div>
                            <Badge variant={selectedBooking.status === 'completed' ? 'success' : selectedBooking.status === 'active' ? 'info' : selectedBooking.status === 'cancelled' ? 'error' : 'warning'}>
                                {(selectedBooking.status || 'unknown').toUpperCase()}
                            </Badge>
                        </div>

                        <div className="grid grid-cols-2 gap-4">
                            <div className="space-y-1">
                                <p className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider">Customer</p>
                                <p className="text-sm font-bold text-text-primary">{selectedBooking.userName}</p>
                            </div>
                            <div className="space-y-1">
                                <p className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider">Vehicle</p>
                                <div className="inline-flex px-2 py-1 bg-warning-bg border border-warning/30 rounded text-xs font-mono font-bold text-warning-text uppercase">
                                    {selectedBooking.vehicleNumber || 'UNKNOWN'}
                                </div>
                            </div>
                            <div className="col-span-2 space-y-1 mt-2 border-t border-border pt-4">
                                <p className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider">Facility</p>
                                <div className="flex items-center gap-2">
                                    <MapPin className="w-4 h-4 text-primary" />
                                    <p className="text-sm font-bold text-text-primary">{selectedBooking.lotName}</p>
                                </div>
                            </div>
                        </div>

                        <div className="bg-surface border border-border rounded-xl overflow-hidden divide-y divide-border">
                            <div className="p-4 flex justify-between items-center">
                                <div className="flex items-center gap-2 text-text-secondary font-medium text-sm">
                                    <Clock className="w-4 h-4" /> Booked Time
                                </div>
                                <span className="font-bold text-text-primary">
                                    {selectedBooking.createdAt ? format(selectedBooking.createdAt.toDate(), 'PP p') : 'Unknown'}
                                </span>
                            </div>
                            <div className="p-4 flex justify-between items-center bg-bg-light">
                                <span className="text-text-primary font-bold">Total Amount</span>
                                <span className="text-2xl font-extrabold text-primary tracking-tight">
                                    {formatCurrency(selectedBooking.totalAmount || selectedBooking.amount || 0)}
                                </span>
                            </div>
                        </div>
                    </div>
                )}
            </Drawer>
        </div>
    );
}
