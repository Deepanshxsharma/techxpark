import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, query, where, onSnapshot, getDocs, updateDoc, deleteDoc, doc } from 'firebase/firestore';
import { Users as UsersIcon, Search, Download, MoreVertical, CreditCard, Calendar, Ban, Trash2 } from 'lucide-react';
import Button from '../components/ui/Button';
import DataTable from '../components/ui/DataTable';
import Avatar from '../components/ui/Avatar';
import Badge from '../components/ui/Badge';
import Drawer from '../components/ui/Drawer';
import Modal from '../components/ui/Modal';
import { format } from 'date-fns';
import toast from 'react-hot-toast';
import { formatCurrency, exportToCSV } from '../utils/helpers';

export default function Users() {
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [selectedUser, setSelectedUser] = useState(null);
    const [banTarget, setBanTarget] = useState(null);
    const [deleteTarget, setDeleteTarget] = useState(null);
    const [deleteConfirmText, setDeleteConfirmText] = useState('');
    const [processing, setProcessing] = useState(false);

    useEffect(() => {
        const q = query(collection(db, 'users'), where('role', '==', 'customer'));
        const unsubscribe = onSnapshot(q, async (snapshot) => {
            const arr = [];
            // Fetch booking stats for each user
            const userIds = snapshot.docs.map(d => d.id);

            // Batch fetch booking counts and amounts
            const bookingMap = {};
            try {
                const bookingsSnap = await getDocs(collection(db, 'bookings'));
                bookingsSnap.docs.forEach(d => {
                    const data = d.data();
                    const uid = data.userId;
                    if (!uid) return;
                    if (!bookingMap[uid]) bookingMap[uid] = { count: 0, total: 0 };
                    bookingMap[uid].count += 1;
                    bookingMap[uid].total += Number(data.amount || data.totalAmount || 0);
                });
            } catch (e) {
                console.error('Failed to fetch booking stats:', e);
            }

            snapshot.docs.forEach(d => {
                const data = d.data();
                const stats = bookingMap[d.id] || { count: 0, total: 0 };
                arr.push({
                    id: d.id,
                    ...data,
                    totalBookings: stats.count,
                    totalSpent: stats.total,
                });
            });
            setUsers(arr);
            setLoading(false);
        });
        return () => unsubscribe();
    }, []);

    const handleBanToggle = async () => {
        if (!banTarget) return;
        setProcessing(true);
        try {
            const newBanned = !banTarget.banned;
            await updateDoc(doc(db, 'users', banTarget.id), { banned: newBanned, status: newBanned ? 'banned' : 'active' });
            toast.success(newBanned ? 'User banned' : 'User unbanned');
            setBanTarget(null);
            setSelectedUser(null);
        } catch (err) {
            toast.error('Failed to update user');
        } finally {
            setProcessing(false);
        }
    };

    const handleDelete = async () => {
        if (!deleteTarget || deleteConfirmText !== 'DELETE') return;
        setProcessing(true);
        try {
            await deleteDoc(doc(db, 'users', deleteTarget.id));
            toast.success('User deleted');
            setDeleteTarget(null);
            setDeleteConfirmText('');
            setSelectedUser(null);
        } catch (err) {
            toast.error('Failed to delete user');
        } finally {
            setProcessing(false);
        }
    };

    const handleExport = () => {
        exportToCSV(users.map(u => ({
            Name: u.name || '',
            Email: u.email || '',
            Phone: u.phone || '',
            'Total Bookings': u.totalBookings,
            'Total Spent': u.totalSpent,
            Status: u.banned ? 'banned' : 'active',
            Joined: u.createdAt ? format(u.createdAt.toDate(), 'yyyy-MM-dd') : ''
        })), 'customers');
        toast.success('CSV exported');
    };

    const filteredUsers = users.filter(u =>
        (u.name?.toLowerCase() || '').includes(searchTerm.toLowerCase()) ||
        (u.email?.toLowerCase() || '').includes(searchTerm.toLowerCase())
    );

    const columns = [
        {
            header: 'User',
            accessor: 'name',
            sortable: true,
            cell: (row) => (
                <div className="flex items-center gap-3">
                    <Avatar name={row.name} size="md" />
                    <div>
                        <p className="font-bold text-text-primary mb-0.5">{row.name}</p>
                        <p className="text-[12px] font-medium text-text-secondary">{row.email}</p>
                    </div>
                </div>
            )
        },
        {
            header: 'Phone',
            accessor: 'phone',
            cell: (row) => <span className="font-mono text-text-secondary">{row.phone || 'N/A'}</span>
        },
        {
            header: 'Bookings',
            accessor: 'totalBookings',
            cell: (row) => <span className="font-bold text-text-primary">{row.totalBookings}</span>
        },
        {
            header: 'Total Spent',
            accessor: 'totalSpent',
            cell: (row) => <span className="font-bold text-text-primary">{formatCurrency(row.totalSpent)}</span>
        },
        {
            header: 'Registered',
            accessor: 'createdAt',
            cell: (row) => (
                <span className="text-[13px] font-semibold text-text-secondary">
                    {row.createdAt ? format(row.createdAt.toDate(), 'MMM dd, yyyy') : 'Unknown'}
                </span>
            )
        },
        {
            header: 'Status',
            accessor: 'status',
            cell: (row) => {
                const isBanned = row.banned || row.status === 'banned';
                return <Badge variant={isBanned ? 'error' : 'success'}>{isBanned ? 'banned' : 'active'}</Badge>;
            }
        },
        {
            header: '',
            accessor: 'actions',
            align: 'right',
            cell: (row) => (
                <button
                    onClick={(e) => { e.stopPropagation(); setSelectedUser(row); }}
                    className="p-1.5 rounded-lg text-text-tertiary hover:bg-surface-hover hover:text-text-primary transition-colors"
                >
                    <MoreVertical className="w-4 h-4" />
                </button>
            )
        }
    ];

    return (
        <div className="space-y-6 animate-fade-in pb-10">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-text-primary tracking-tight">Customers</h1>
                    <p className="text-sm font-medium text-text-secondary mt-1">Manage all end-users registered on TechXPark.</p>
                </div>
                <div className="flex items-center gap-3">
                    <Button variant="secondary" icon={Download} onClick={handleExport}>Export CSV</Button>
                </div>
            </div>

            <DataTable
                columns={columns}
                data={filteredUsers}
                loading={loading}
                searchTerm={searchTerm}
                onSearchChange={setSearchTerm}
                onRowClick={(row) => setSelectedUser(row)}
            />

            {/* Ban Confirm */}
            <Modal isOpen={!!banTarget} onClose={() => setBanTarget(null)} title={banTarget?.banned ? 'Unban User' : 'Ban User'} size="sm">
                <div className="space-y-4">
                    <p className="text-sm text-text-secondary">
                        {banTarget?.banned
                            ? `Unban ${banTarget?.name}? They will regain access to the platform.`
                            : `Ban ${banTarget?.name}? They will be unable to use the app.`
                        }
                    </p>
                    <div className="flex gap-3">
                        <Button variant="secondary" className="flex-1" onClick={() => setBanTarget(null)}>Cancel</Button>
                        <Button variant={banTarget?.banned ? 'primary' : 'danger'} className="flex-1" onClick={handleBanToggle} disabled={processing}>
                            {processing ? 'Processing...' : banTarget?.banned ? 'Unban' : 'Ban User'}
                        </Button>
                    </div>
                </div>
            </Modal>

            {/* Delete Confirm */}
            <Modal isOpen={!!deleteTarget} onClose={() => { setDeleteTarget(null); setDeleteConfirmText(''); }} title="Delete User" size="sm">
                <div className="space-y-4">
                    <p className="text-sm text-text-secondary">
                        This will permanently delete <strong>{deleteTarget?.name}</strong>'s account. Type <strong>DELETE</strong> to confirm.
                    </p>
                    <input
                        type="text"
                        value={deleteConfirmText}
                        onChange={(e) => setDeleteConfirmText(e.target.value)}
                        placeholder="Type DELETE"
                        className="w-full px-4 py-2.5 border border-border rounded-xl text-sm font-bold focus:outline-none focus:border-error"
                    />
                    <div className="flex gap-3">
                        <Button variant="secondary" className="flex-1" onClick={() => { setDeleteTarget(null); setDeleteConfirmText(''); }}>Cancel</Button>
                        <Button variant="danger" className="flex-1" onClick={handleDelete} disabled={deleteConfirmText !== 'DELETE' || processing}>
                            {processing ? 'Deleting...' : 'Delete Account'}
                        </Button>
                    </div>
                </div>
            </Modal>

            {/* Details Drawer */}
            <Drawer
                isOpen={!!selectedUser}
                onClose={() => setSelectedUser(null)}
                title="Customer Profile"
                footer={
                    <>
                        <Button
                            variant={selectedUser?.banned ? 'primary' : 'danger'}
                            className="w-full"
                            onClick={() => { setBanTarget(selectedUser); setSelectedUser(null); }}
                        >
                            {selectedUser?.banned ? 'Unban User' : 'Ban User'}
                        </Button>
                        <Button
                            variant="danger"
                            className="w-full"
                            onClick={() => { setDeleteTarget(selectedUser); setSelectedUser(null); }}
                        >
                            <Trash2 className="w-4 h-4 mr-1" /> Delete Account
                        </Button>
                    </>
                }
            >
                {selectedUser && (
                    <div className="space-y-8">
                        <div className="flex flex-col items-center justify-center text-center p-6 bg-surface border border-border rounded-2xl">
                            <Avatar name={selectedUser.name} size="xl" className="mb-4" />
                            <h3 className="text-xl font-bold text-text-primary mb-1">{selectedUser.name}</h3>
                            <p className="text-sm font-medium text-text-secondary mb-3">{selectedUser.email}</p>
                            <Badge variant={selectedUser.banned ? 'error' : 'success'}>
                                {selectedUser.banned ? 'BANNED' : 'ACTIVE'}
                            </Badge>
                        </div>

                        <div className="grid grid-cols-2 gap-4">
                            <div className="bg-bg-light p-4 rounded-xl border border-border">
                                <span className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider mb-1 flex items-center gap-1.5"><Calendar className="w-3 h-3" /> Total Bookings</span>
                                <span className="text-[24px] font-extrabold text-text-primary tracking-tight">{selectedUser.totalBookings}</span>
                            </div>
                            <div className="bg-bg-light p-4 rounded-xl border border-border">
                                <span className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider mb-1 flex items-center gap-1.5"><CreditCard className="w-3 h-3" /> Total Spent</span>
                                <span className="text-[24px] font-extrabold text-text-primary tracking-tight">{formatCurrency(selectedUser.totalSpent)}</span>
                            </div>
                        </div>

                        <div className="space-y-3">
                            <h4 className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider px-1">System Information</h4>
                            <div className="bg-white rounded-xl border border-border divide-y divide-border text-sm font-medium">
                                <div className="flex justify-between items-center p-4">
                                    <span className="text-text-secondary">Phone Number</span>
                                    <span className="font-mono text-text-primary">{selectedUser.phone || 'Not provided'}</span>
                                </div>
                                <div className="flex justify-between items-center p-4">
                                    <span className="text-text-secondary">Account ID</span>
                                    <span className="font-mono text-[12px] text-text-tertiary">{selectedUser.id}</span>
                                </div>
                                <div className="flex justify-between items-center p-4">
                                    <span className="text-text-secondary">Registered</span>
                                    <span className="text-text-primary">{selectedUser.createdAt ? format(selectedUser.createdAt.toDate(), 'MMM dd, yyyy') : 'Unknown'}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                )}
            </Drawer>
        </div>
    );
}
