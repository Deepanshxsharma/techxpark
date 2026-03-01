import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useBookings } from '../hooks/useBookings';
import { format } from 'date-fns';
import { Search, CalendarCheck, ArrowRight, X, MessageSquare, AlertTriangle, ShieldCheck } from 'lucide-react';

import DataTable from '../components/ui/DataTable';
import Badge from '../components/ui/Badge';
import Button from '../components/ui/Button';
import Avatar from '../components/ui/Avatar';

export default function Bookings() {
    const { ownerData } = useAuth();
    const lotId = ownerData?.assignedLotId;
    const { bookings, loading } = useBookings(lotId);

    const [searchTerm, setSearchTerm] = useState('');
    const [filterStr, setFilterStr] = useState('All');
    const [selectedBooking, setSelectedBooking] = useState(null);

    const filteredBookings = bookings.filter(b => {
        const textMatch = (b.userName || '').toLowerCase().includes(searchTerm.toLowerCase())
            || (b.slotId || '').toLowerCase().includes(searchTerm.toLowerCase())
            || (b.vehicle?.plateNumber || '').toLowerCase().includes(searchTerm.toLowerCase())
            || (b.id || '').toLowerCase().includes(searchTerm.toLowerCase());

        if (filterStr === 'All') return textMatch;
        return textMatch && (b.status || '').toLowerCase() === filterStr.toLowerCase();
    });

    const columns = [
        {
            header: 'Booking ID',
            accessor: 'id',
            className: 'w-[140px]',
            render: (row) => (
                <span className="font-mono text-xs font-semibold text-text-tertiary group-hover:text-primary transition-colors">
                    {row.id.substring(0, 8).toUpperCase()}
                </span>
            )
        },
        {
            header: 'Customer',
            accessor: 'userName',
            render: (row) => (
                <div className="flex items-center gap-3">
                    <Avatar name={row.userName || 'Guest'} size="sm" />
                    <div className="flex flex-col">
                        <span className="font-semibold text-text-primary text-sm">{row.userName || 'Guest'}</span>
                        <span className="font-mono text-[11px] font-bold text-text-secondary bg-bg-light px-1.5 py-0.5 rounded border border-border w-fit mt-1">
                            {row.vehicle?.plateNumber || 'N/A'}
                        </span>
                    </div>
                </div>
            )
        },
        {
            header: 'Target Slot',
            accessor: 'slotId',
            render: (row) => (
                <div className="flex flex-col">
                    <span className="font-bold text-text-primary text-sm">Slot {row.slotId}</span>
                    <span className="text-[11px] font-semibold text-text-tertiary uppercase tracking-[0.5px] mt-0.5">LEVEL {row.floor || 1}</span>
                </div>
            )
        },
        {
            header: 'Time Window',
            accessor: 'time',
            render: (row) => (
                <div className="flex items-center gap-2 text-[13px] font-semibold text-text-secondary bg-bg-light px-3 py-1.5 rounded-lg border border-border w-fit">
                    <span>{row.startTime ? format(row.startTime.toDate(), 'MMM d, h:mm a') : 'TBD'}</span>
                    <ArrowRight className="w-3.5 h-3.5 text-text-tertiary" />
                    <span className={`${row.status === 'active' ? 'text-primary' : ''}`}>
                        {row.endTime ? format(row.endTime.toDate(), 'h:mm a') : 'TBD'}
                    </span>
                </div>
            )
        },
        {
            header: 'Value',
            accessor: 'amount',
            render: (row) => (
                <span className="font-mono font-bold text-text-primary text-[15px]">
                    ₹{row.amount || 0}
                </span>
            )
        },
        {
            header: 'Status',
            accessor: 'status',
            render: (row) => {
                const s = (row.status || '').toLowerCase();
                if (s === 'active') return <Badge variant="success" dot pulse>Active</Badge>;
                if (s === 'upcoming') return <Badge variant="info" dot>Upcoming</Badge>;
                if (s === 'cancelled') return <Badge variant="error">Cancelled</Badge>;
                if (s === 'completed') return <Badge variant="neutral">Completed</Badge>;
                return <Badge variant="neutral">{row.status}</Badge>;
            }
        }
    ];

    return (
        <div className="flex flex-col h-[calc(100vh-64px-48px)] w-full max-w-[1400px] mx-auto animate-in fade-in duration-300 relative overflow-hidden">

            <div className="flex flex-1 gap-6 overflow-hidden">
                {/* Main Table Area */}
                <div className="flex-1 flex flex-col min-w-0 bg-white rounded-[14px] border border-border shadow-sm overflow-hidden">

                    {/* Header/Filters */}
                    <div className="p-5 border-b border-border bg-surface flex flex-wrap gap-4 items-center justify-between shrink-0">
                        <div className="relative flex-1 max-w-[400px]">
                            <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-text-tertiary">
                                <Search className="w-4 h-4" />
                            </div>
                            <input
                                type="text"
                                value={searchTerm}
                                onChange={(e) => setSearchTerm(e.target.value)}
                                placeholder="Search by customer, plate, or ID..."
                                className="w-full pl-10 pr-4 py-2.5 bg-bg-light border border-border rounded-lg text-sm font-medium focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary transition-all shadow-xs"
                            />
                        </div>

                        <div className="flex gap-1.5 bg-bg-light p-1 rounded-lg border border-border shadow-xs">
                            {['All', 'Active', 'Upcoming', 'Completed', 'Cancelled'].map(f => (
                                <button
                                    key={f}
                                    onClick={() => setFilterStr(f)}
                                    className={`px-4 py-1.5 rounded-md text-[13px] font-semibold transition-all duration-200 ${filterStr === f
                                            ? 'bg-white shadow-sm text-text-primary border border-border/50'
                                            : 'text-text-secondary hover:text-text-primary hover:bg-white/50 border border-transparent'
                                        }`}
                                >
                                    {f}
                                </button>
                            ))}
                        </div>
                    </div>

                    {/* Table */}
                    <div className="flex-1 overflow-hidden">
                        <DataTable
                            columns={columns}
                            data={filteredBookings}
                            loading={loading}
                            onRowClick={(row) => setSelectedBooking(row)}
                            pagination={true}
                            emptyState={
                                <div className="py-20 text-center flex flex-col items-center">
                                    <div className="w-14 h-14 bg-surface-hover rounded-full flex items-center justify-center mb-4">
                                        <CalendarCheck className="w-6 h-6 text-text-tertiary" />
                                    </div>
                                    <h3 className="text-base font-bold text-text-primary mb-1">No bookings match criteria</h3>
                                    <p className="text-sm text-text-secondary">Try adjusting your search filters above.</p>
                                </div>
                            }
                        />
                    </div>
                </div>

                {/* Slide-out Panel (Drawer) */}
                {selectedBooking && (
                    <div className="w-[400px] bg-white rounded-[14px] border border-border shadow-[-8px_0_32px_rgba(0,0,0,0.08)] flex flex-col overflow-hidden animate-[slideInRight_300ms_cubic-bezier(0.32,0.72,0,1)] shrink-0 top-0 z-20 absolute right-0 bottom-0 h-full">

                        <div className="h-1.5 w-full bg-gradient-to-r from-primary to-primary-light shrink-0" />

                        <div className="p-6 border-b border-border relative bg-surface">
                            <button
                                onClick={() => setSelectedBooking(null)}
                                className="absolute top-5 right-5 text-text-tertiary hover:text-text-primary hover:bg-surface-hover w-8 h-8 flex items-center justify-center rounded-full transition-colors"
                            >
                                <X className="w-5 h-5" />
                            </button>
                            <div className="flex items-center gap-4 mb-4">
                                <Avatar name={selectedBooking.userName || 'Guest User'} size="lg" />
                                <div>
                                    <h3 className="text-xl font-bold text-text-primary tracking-tight">{selectedBooking.userName || 'Guest User'}</h3>
                                    <p className="text-[13px] text-text-secondary mt-0.5">Customer</p>
                                </div>
                            </div>
                            <div className="flex items-center gap-2">
                                <span className="text-[11px] font-semibold text-text-tertiary uppercase tracking-[0.5px]">Booking ID</span>
                                <span className="text-xs font-mono font-bold text-text-primary bg-bg-light border border-border px-2 py-0.5 rounded">
                                    {selectedBooking.id}
                                </span>
                            </div>
                        </div>

                        <div className="p-6 flex-1 overflow-y-auto space-y-8 scrollbar-none">

                            {/* Status block */}
                            <div>
                                <h4 className="text-[11px] uppercase font-bold tracking-[0.8px] text-text-tertiary mb-3">Current Status</h4>
                                <div className="flex items-center justify-between bg-bg-light border border-border p-4 rounded-xl">
                                    <span className="text-[13px] font-semibold text-text-secondary">Overall Status</span>
                                    {selectedBooking.status === 'active' && <Badge variant="success" dot pulse>Active</Badge>}
                                    {selectedBooking.status === 'upcoming' && <Badge variant="info" dot>Upcoming</Badge>}
                                    {selectedBooking.status === 'completed' && <Badge variant="neutral">Completed</Badge>}
                                    {selectedBooking.status === 'cancelled' && <Badge variant="error">Cancelled</Badge>}
                                </div>
                            </div>

                            {/* Reservation Details */}
                            <div>
                                <h4 className="text-[11px] uppercase font-bold tracking-[0.8px] text-text-tertiary mb-3">Reservation Details</h4>
                                <div className="bg-white border border-border shadow-xs rounded-xl divide-y divide-border text-[13px] overflow-hidden">
                                    <div className="p-4 flex justify-between items-center bg-surface">
                                        <span className="text-text-secondary font-medium">Location</span>
                                        <div className="flex items-center gap-2">
                                            <span className="font-bold text-text-primary bg-bg-light font-mono px-2.5 py-1 rounded border border-border">Slot {selectedBooking.slotId}</span>
                                        </div>
                                    </div>
                                    <div className="p-4 flex justify-between items-center bg-surface">
                                        <span className="text-text-secondary font-medium">Arrival Time</span>
                                        <span className="font-semibold text-text-primary">
                                            {selectedBooking.startTime ? format(selectedBooking.startTime.toDate(), 'MMM d, yyyy • h:mm a') : 'N/A'}
                                        </span>
                                    </div>
                                    <div className="p-4 flex justify-between items-center bg-surface">
                                        <span className="text-text-secondary font-medium">Departure Time</span>
                                        <span className="font-semibold text-text-primary">
                                            {selectedBooking.endTime ? format(selectedBooking.endTime.toDate(), 'MMM d, yyyy • h:mm a') : 'N/A'}
                                        </span>
                                    </div>
                                </div>
                            </div>

                            {/* Vehicle Details */}
                            <div>
                                <h4 className="text-[11px] uppercase font-bold tracking-[0.8px] text-text-tertiary mb-3">Vehicle Information</h4>
                                <div className="bg-white border border-border shadow-xs rounded-xl flex items-center p-4 gap-4">
                                    <div className="w-12 h-12 bg-bg-light border border-border rounded-lg flex items-center justify-center text-2xl">
                                        {selectedBooking.vehicle?.type?.toLowerCase() === 'bike' ? '🏍️' : '🚗'}
                                    </div>
                                    <div className="flex flex-col">
                                        <p className="font-bold text-text-primary font-mono tracking-[1px] text-[17px]">{selectedBooking.vehicle?.plateNumber || 'UNKNOWN'}</p>
                                        <p className="text-[11px] font-bold text-text-tertiary uppercase tracking-[0.5px] mt-1">{selectedBooking.vehicle?.type || 'Vehicle'}</p>
                                    </div>
                                </div>
                            </div>

                            {/* Ledger */}
                            <div>
                                <h4 className="text-[11px] uppercase font-bold tracking-[0.8px] text-text-tertiary mb-3">Payment Ledger</h4>
                                <div className="bg-bg-light p-5 rounded-xl border border-border flex items-center justify-between">
                                    <div className="flex items-center gap-2">
                                        <ShieldCheck className="w-5 h-5 text-success" />
                                        <span className="text-[13px] font-semibold text-text-secondary">Processed via UPI</span>
                                    </div>
                                    <span className="font-mono font-bold text-[22px] tracking-tight text-text-primary">
                                        ₹{selectedBooking.amount || 0}
                                    </span>
                                </div>
                            </div>
                        </div>

                        {/* Actions fixed at bottom */}
                        <div className="p-5 border-t border-border bg-surface space-y-3 shrink-0">
                            {selectedBooking.status === 'upcoming' && (
                                <>
                                    <Button variant="danger" className="w-full">
                                        Cancel & Refund Booking
                                    </Button>
                                    <Button variant="secondary" className="w-full">
                                        Mark as No-Show
                                    </Button>
                                </>
                            )}
                            {selectedBooking.status === 'active' && (
                                <Button variant="secondary" className="w-full text-error hover:bg-error-bg hover:border-error/30 hover:text-error">
                                    Force Complete / Evict
                                </Button>
                            )}
                            <Button variant="secondary" className="w-full" icon={MessageSquare}>
                                Message Customer
                            </Button>
                        </div>
                    </div>
                )}
            </div>

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
