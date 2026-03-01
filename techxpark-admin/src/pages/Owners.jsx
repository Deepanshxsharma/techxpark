import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import {
    collection, query, where, onSnapshot, getDocs, doc,
    writeBatch, serverTimestamp, updateDoc, getDoc
} from 'firebase/firestore';
import { UserSquare2, Shield, Search, Download, MoreVertical, Calendar, UserPlus, X, ChevronRight, Check, AlertTriangle, Ban } from 'lucide-react';
import Button from '../components/ui/Button';
import DataTable from '../components/ui/DataTable';
import Avatar from '../components/ui/Avatar';
import Badge from '../components/ui/Badge';
import Drawer from '../components/ui/Drawer';
import Modal from '../components/ui/Modal';
import { format } from 'date-fns';
import toast from 'react-hot-toast';
import { useAuth } from '../hooks/useAuth';
import { formatCurrency, exportToCSV } from '../utils/helpers';

export default function Owners() {
    const { user: adminUser } = useAuth();
    const [owners, setOwners] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [selectedOwner, setSelectedOwner] = useState(null);
    const [filterTab, setFilterTab] = useState('all');

    // Grant Access Modal
    const [grantOpen, setGrantOpen] = useState(false);
    const [grantStep, setGrantStep] = useState(1);
    const [ownerSearch, setOwnerSearch] = useState('');
    const [selectedGrantOwner, setSelectedGrantOwner] = useState(null);
    const [allLots, setAllLots] = useState([]);
    const [selectedLot, setSelectedLot] = useState(null);
    const [granting, setGranting] = useState(false);

    // Revoke confirm
    const [revokeTarget, setRevokeTarget] = useState(null);
    const [revoking, setRevoking] = useState(false);

    // Suspend confirm
    const [suspendTarget, setSuspendTarget] = useState(null);

    useEffect(() => {
        const q = query(collection(db, 'users'), where('role', '==', 'owner'));
        const unsubscribe = onSnapshot(q, async (snapshot) => {
            const arr = [];
            // Batch fetch lot names
            const lotIds = new Set();
            snapshot.docs.forEach(d => { if (d.data().assignedLotId) lotIds.add(d.data().assignedLotId); });
            const lotMap = {};
            for (const lotId of lotIds) {
                try {
                    const lotSnap = await getDoc(doc(db, 'parking_locations', lotId));
                    if (lotSnap.exists()) lotMap[lotId] = lotSnap.data().name;
                } catch (e) { /* skip */ }
            }

            snapshot.docs.forEach(d => {
                const data = d.data();
                arr.push({
                    id: d.id,
                    ...data,
                    managedLotName: data.assignedLotId ? (lotMap[data.assignedLotId] || 'Unknown Lot') : 'Unassigned'
                });
            });
            setOwners(arr);
            setLoading(false);
        });
        return () => unsubscribe();
    }, []);

    // Fetch lots when grant modal opens
    useEffect(() => {
        if (!grantOpen) return;
        const fetchLots = async () => {
            try {
                const snap = await getDocs(collection(db, 'parking_locations'));
                setAllLots(snap.docs.map(d => ({ id: d.id, ...d.data() })));
            } catch (e) { toast.error('Failed to load lots'); }
        };
        fetchLots();
    }, [grantOpen]);

    const handleGrantAccess = async () => {
        if (!selectedGrantOwner || !selectedLot) return;
        setGranting(true);
        try {
            const batch = writeBatch(db);

            // 1. Update owner
            batch.update(doc(db, 'users', selectedGrantOwner.id), {
                accessStatus: 'approved',
                assignedLotId: selectedLot.id,
                requestId: null,
            });

            // 2. Update lot
            batch.update(doc(db, 'parking_locations', selectedLot.id), {
                assignedOwnerId: selectedGrantOwner.id,
                isAssigned: true,
            });

            // 3. If previous manager → revoke
            if (selectedLot.assignedOwnerId && selectedLot.assignedOwnerId !== selectedGrantOwner.id) {
                batch.update(doc(db, 'users', selectedLot.assignedOwnerId), {
                    accessStatus: 'none',
                    assignedLotId: null,
                });
            }

            // 4. If pending request → approve it
            if (selectedGrantOwner.requestId) {
                batch.update(doc(db, 'access_requests', selectedGrantOwner.requestId), {
                    status: 'approved',
                    reviewedAt: serverTimestamp(),
                    reviewedBy: adminUser?.uid || 'admin',
                });
            }

            await batch.commit();
            toast.success(`Access granted to ${selectedGrantOwner.name || selectedGrantOwner.email}`);
            closeGrantModal();
        } catch (err) {
            console.error('Grant access error:', err);
            toast.error('Failed to grant access');
        } finally {
            setGranting(false);
        }
    };

    const handleRevokeAccess = async (owner) => {
        if (!owner.assignedLotId) return;
        setRevoking(true);
        try {
            const batch = writeBatch(db);
            batch.update(doc(db, 'users', owner.id), {
                accessStatus: 'none',
                assignedLotId: null,
            });
            batch.update(doc(db, 'parking_locations', owner.assignedLotId), {
                assignedOwnerId: null,
                isAssigned: false,
            });
            await batch.commit();
            toast.success(`Access revoked for ${owner.name || owner.email}`);
            setRevokeTarget(null);
            setSelectedOwner(null);
        } catch (err) {
            console.error('Revoke error:', err);
            toast.error('Failed to revoke access');
        } finally {
            setRevoking(false);
        }
    };

    const handleSuspendToggle = async (owner) => {
        try {
            const newStatus = owner.accessStatus === 'suspended' ? 'approved' : 'suspended';
            await updateDoc(doc(db, 'users', owner.id), { accessStatus: newStatus });
            toast.success(newStatus === 'suspended' ? 'Owner suspended' : 'Owner reactivated');
            setSuspendTarget(null);
            setSelectedOwner(null);
        } catch (err) {
            toast.error('Failed to update status');
        }
    };

    const closeGrantModal = () => {
        setGrantOpen(false);
        setGrantStep(1);
        setSelectedGrantOwner(null);
        setSelectedLot(null);
        setOwnerSearch('');
    };

    const handleExportCSV = () => {
        exportToCSV(owners.map(o => ({
            Name: o.name || '',
            Email: o.email || '',
            Phone: o.phone || '',
            Status: o.accessStatus || 'none',
            'Managed Lot': o.managedLotName || '',
            Joined: o.createdAt ? format(o.createdAt.toDate(), 'yyyy-MM-dd') : ''
        })), 'owners');
        toast.success('CSV exported');
    };

    // Filters
    const tabs = [
        { id: 'all', label: 'All' },
        { id: 'approved', label: 'Active' },
        { id: 'pending', label: 'Pending' },
        { id: 'unassigned', label: 'Unassigned' },
        { id: 'suspended', label: 'Suspended' },
    ];

    const filteredOwners = owners.filter(o => {
        const matchSearch = (o.name?.toLowerCase() || '').includes(searchTerm.toLowerCase()) ||
            (o.email?.toLowerCase() || '').includes(searchTerm.toLowerCase());
        if (!matchSearch) return false;
        if (filterTab === 'all') return true;
        if (filterTab === 'approved') return o.accessStatus === 'approved';
        if (filterTab === 'pending') return o.accessStatus === 'pending';
        if (filterTab === 'unassigned') return !o.assignedLotId;
        if (filterTab === 'suspended') return o.accessStatus === 'suspended';
        return true;
    });

    // Owners filtered for grant modal
    const grantOwnerResults = owners.filter(o =>
    (!ownerSearch || (o.name?.toLowerCase() || '').includes(ownerSearch.toLowerCase()) ||
        (o.email?.toLowerCase() || '').includes(ownerSearch.toLowerCase()))
    );

    const columns = [
        {
            header: 'Owner',
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
            cell: (row) => (
                <span className="font-mono text-text-secondary">{row.phone || 'N/A'}</span>
            )
        },
        {
            header: 'Managed Lot',
            accessor: 'managedLotName',
            cell: (row) => (
                <div className="flex items-center gap-2">
                    {row.assignedLotId ? (
                        <>
                            <div className="w-1.5 h-1.5 rounded-full bg-primary" />
                            <span className="font-bold text-text-primary">{row.managedLotName}</span>
                        </>
                    ) : (
                        <Badge variant="warning">Unassigned</Badge>
                    )}
                </div>
            )
        },
        {
            header: 'Status',
            accessor: 'accessStatus',
            cell: (row) => {
                const status = row.accessStatus || 'none';
                const v = status === 'approved' ? 'success' : status === 'suspended' ? 'error' : status === 'pending' ? 'warning' : 'neutral';
                return <Badge variant={v}>{status}</Badge>;
            }
        },
        {
            header: '',
            accessor: 'actions',
            align: 'right',
            cell: (row) => (
                <div className="flex items-center gap-1">
                    {row.accessStatus === 'approved' && row.assignedLotId && (
                        <button
                            onClick={(e) => { e.stopPropagation(); setRevokeTarget(row); }}
                            className="px-2 py-1 text-[11px] font-bold text-error hover:bg-error/10 rounded-lg transition-colors"
                        >Revoke</button>
                    )}
                    <button
                        onClick={(e) => { e.stopPropagation(); setSelectedOwner(row); }}
                        className="p-1.5 rounded-lg text-text-tertiary hover:bg-surface-hover hover:text-text-primary transition-colors"
                    >
                        <MoreVertical className="w-4 h-4" />
                    </button>
                </div>
            )
        }
    ];

    return (
        <div className="space-y-6 animate-fade-in pb-10">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-text-primary tracking-tight">Lot Owners</h1>
                    <p className="text-sm font-medium text-text-secondary mt-1">Manage platform partners and their lot assignments.</p>
                </div>
                <div className="flex items-center gap-3">
                    <Button variant="secondary" icon={Download} onClick={handleExportCSV}>Export CSV</Button>
                    <Button icon={UserPlus} onClick={() => setGrantOpen(true)}>Grant Direct Access</Button>
                </div>
            </div>

            {/* Filter Tabs */}
            <div className="flex gap-1 bg-surface border border-border rounded-xl p-1 w-fit">
                {tabs.map(tab => (
                    <button
                        key={tab.id}
                        onClick={() => setFilterTab(tab.id)}
                        className={`px-4 py-2 rounded-lg text-sm font-bold transition-all ${filterTab === tab.id ? 'bg-white text-primary shadow-sm' : 'text-text-secondary hover:text-text-primary'}`}
                    >{tab.label}</button>
                ))}
            </div>

            {/* Data Table */}
            <DataTable
                columns={columns}
                data={filteredOwners}
                loading={loading}
                searchTerm={searchTerm}
                onSearchChange={setSearchTerm}
                onRowClick={(row) => setSelectedOwner(row)}
            />

            {/* Grant Direct Access Modal */}
            <Modal isOpen={grantOpen} onClose={closeGrantModal} title="Grant Direct Access" size="lg">
                {/* Step Indicator */}
                <div className="flex items-center gap-2 mb-8">
                    {[1, 2, 3].map(s => (
                        <React.Fragment key={s}>
                            <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold transition-all ${grantStep >= s ? 'bg-primary text-white' : 'bg-bg-light text-text-tertiary border border-border'}`}>
                                {grantStep > s ? <Check className="w-4 h-4" /> : s}
                            </div>
                            {s < 3 && <div className={`flex-1 h-0.5 rounded ${grantStep > s ? 'bg-primary' : 'bg-border'}`} />}
                        </React.Fragment>
                    ))}
                </div>

                {/* Step 1: Select Owner */}
                {grantStep === 1 && (
                    <div className="space-y-4">
                        <h3 className="text-sm font-bold text-text-primary">Step 1 — Select Owner</h3>
                        <div className="relative">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-tertiary" />
                            <input
                                type="text"
                                placeholder="Search by name or email..."
                                value={ownerSearch}
                                onChange={(e) => setOwnerSearch(e.target.value)}
                                className="w-full pl-10 pr-4 py-2.5 bg-bg-light border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10"
                            />
                        </div>
                        <div className="max-h-[300px] overflow-y-auto space-y-2">
                            {grantOwnerResults.map(o => (
                                <button
                                    key={o.id}
                                    onClick={() => { setSelectedGrantOwner(o); setGrantStep(2); }}
                                    className={`w-full flex items-center gap-3 p-3 rounded-xl border text-left transition-all hover:border-primary/50 hover:bg-primary/5 ${selectedGrantOwner?.id === o.id ? 'border-primary bg-primary/5' : 'border-border'}`}
                                >
                                    <Avatar name={o.name} size="md" />
                                    <div className="flex-1 min-w-0">
                                        <p className="font-bold text-text-primary text-sm truncate">{o.name || 'No Name'}</p>
                                        <p className="text-xs text-text-secondary truncate">{o.email}</p>
                                    </div>
                                    <div className="flex flex-col items-end gap-1">
                                        <Badge variant={o.accessStatus === 'approved' ? 'success' : o.accessStatus === 'pending' ? 'warning' : 'neutral'}>
                                            {o.accessStatus || 'none'}
                                        </Badge>
                                        {o.assignedLotId && <span className="text-[10px] text-text-tertiary font-medium">Has lot</span>}
                                    </div>
                                    <ChevronRight className="w-4 h-4 text-text-tertiary" />
                                </button>
                            ))}
                            {grantOwnerResults.length === 0 && (
                                <p className="text-center text-sm text-text-secondary py-8">No owners found</p>
                            )}
                        </div>
                    </div>
                )}

                {/* Step 2: Select Lot */}
                {grantStep === 2 && (
                    <div className="space-y-4">
                        <div className="flex items-center justify-between">
                            <h3 className="text-sm font-bold text-text-primary">Step 2 — Select Parking Lot</h3>
                            <button onClick={() => setGrantStep(1)} className="text-xs font-bold text-primary hover:underline">← Back</button>
                        </div>
                        <div className="bg-primary/5 border border-primary/20 rounded-xl p-3 flex items-center gap-3">
                            <Avatar name={selectedGrantOwner?.name} size="sm" />
                            <div>
                                <p className="text-sm font-bold text-text-primary">{selectedGrantOwner?.name}</p>
                                <p className="text-xs text-text-secondary">{selectedGrantOwner?.email}</p>
                            </div>
                        </div>
                        <div className="max-h-[300px] overflow-y-auto space-y-2">
                            {allLots.map(lot => (
                                <button
                                    key={lot.id}
                                    onClick={() => { setSelectedLot(lot); setGrantStep(3); }}
                                    className={`w-full flex items-center gap-3 p-3 rounded-xl border text-left transition-all hover:border-primary/50 hover:bg-primary/5 ${selectedLot?.id === lot.id ? 'border-primary bg-primary/5' : 'border-border'}`}
                                >
                                    <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center text-primary shrink-0">
                                        <Shield className="w-5 h-5" />
                                    </div>
                                    <div className="flex-1 min-w-0">
                                        <p className="font-bold text-text-primary text-sm truncate">{lot.name || 'Unnamed Lot'}</p>
                                        <p className="text-xs text-text-secondary truncate">{lot.address || 'No address'}</p>
                                        <p className="text-[10px] text-text-tertiary mt-0.5">{lot.total_slots || 0} slots • {lot.total_floors || 0} floors</p>
                                    </div>
                                    {lot.assignedOwnerId ? (
                                        <Badge variant="warning">Assigned</Badge>
                                    ) : (
                                        <Badge variant="success">Available</Badge>
                                    )}
                                    <ChevronRight className="w-4 h-4 text-text-tertiary" />
                                </button>
                            ))}
                        </div>
                    </div>
                )}

                {/* Step 3: Confirm */}
                {grantStep === 3 && (
                    <div className="space-y-6">
                        <div className="flex items-center justify-between">
                            <h3 className="text-sm font-bold text-text-primary">Step 3 — Confirm Assignment</h3>
                            <button onClick={() => setGrantStep(2)} className="text-xs font-bold text-primary hover:underline">← Back</button>
                        </div>

                        {selectedLot?.assignedOwnerId && selectedLot.assignedOwnerId !== selectedGrantOwner?.id && (
                            <div className="bg-warning/10 border border-warning/30 rounded-xl p-3 flex items-start gap-2">
                                <AlertTriangle className="w-4 h-4 text-warning shrink-0 mt-0.5" />
                                <p className="text-xs font-medium text-warning-text">This lot already has a manager assigned. Assigning a new manager will replace them.</p>
                            </div>
                        )}

                        <div className="bg-bg-light border border-border rounded-2xl p-6 space-y-4">
                            <h4 className="text-xs font-bold text-text-tertiary uppercase tracking-wider">Granting Access</h4>
                            <div className="flex items-center gap-3">
                                <Avatar name={selectedGrantOwner?.name} size="md" />
                                <div>
                                    <p className="font-bold text-text-primary">{selectedGrantOwner?.name}</p>
                                    <p className="text-xs text-text-secondary">{selectedGrantOwner?.email}</p>
                                </div>
                            </div>
                            <div className="border-t border-border pt-4 flex items-center gap-3">
                                <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center text-primary">
                                    <Shield className="w-5 h-5" />
                                </div>
                                <div>
                                    <p className="font-bold text-text-primary">{selectedLot?.name}</p>
                                    <p className="text-xs text-text-secondary">{selectedLot?.address} • {selectedLot?.total_slots || 0} slots</p>
                                </div>
                            </div>
                        </div>

                        <div className="flex gap-3">
                            <Button variant="secondary" className="flex-1" onClick={closeGrantModal}>Cancel</Button>
                            <Button className="flex-1" onClick={handleGrantAccess} disabled={granting}>
                                {granting ? 'Granting...' : '✅ Grant Access Now'}
                            </Button>
                        </div>
                    </div>
                )}
            </Modal>

            {/* Revoke Confirm Dialog */}
            <Modal isOpen={!!revokeTarget} onClose={() => setRevokeTarget(null)} title="Revoke Access" size="sm">
                <div className="space-y-4">
                    <p className="text-sm text-text-secondary">
                        Remove <strong>{revokeTarget?.name}</strong>'s access to <strong>{revokeTarget?.managedLotName}</strong>?
                    </p>
                    <div className="flex gap-3">
                        <Button variant="secondary" className="flex-1" onClick={() => setRevokeTarget(null)}>Cancel</Button>
                        <Button variant="danger" className="flex-1" onClick={() => handleRevokeAccess(revokeTarget)} disabled={revoking}>
                            {revoking ? 'Revoking...' : 'Revoke Access'}
                        </Button>
                    </div>
                </div>
            </Modal>

            {/* Details Drawer */}
            <Drawer
                isOpen={!!selectedOwner}
                onClose={() => setSelectedOwner(null)}
                title="Owner Details"
                footer={
                    <>
                        {selectedOwner?.assignedLotId && (
                            <Button variant="danger" className="w-full" onClick={() => { setRevokeTarget(selectedOwner); setSelectedOwner(null); }}>
                                Revoke Lot Access
                            </Button>
                        )}
                        {!selectedOwner?.assignedLotId && (
                            <Button className="w-full" onClick={() => { setSelectedGrantOwner(selectedOwner); setGrantStep(2); setGrantOpen(true); setSelectedOwner(null); }}>
                                Assign Lot
                            </Button>
                        )}
                        <Button
                            variant={selectedOwner?.accessStatus === 'suspended' ? 'primary' : 'danger'}
                            className="w-full"
                            onClick={() => handleSuspendToggle(selectedOwner)}
                        >
                            {selectedOwner?.accessStatus === 'suspended' ? 'Reactivate' : 'Suspend Account'}
                        </Button>
                    </>
                }
            >
                {selectedOwner && (
                    <div className="space-y-8">
                        <div className="flex flex-col items-center text-center">
                            <Avatar name={selectedOwner.name} size="xl" className="mb-4" />
                            <h3 className="text-xl font-bold text-text-primary mb-1">{selectedOwner.name}</h3>
                            <p className="text-sm font-medium text-text-secondary mb-3">{selectedOwner.email}</p>
                            <Badge variant={selectedOwner.accessStatus === 'approved' ? 'success' : selectedOwner.accessStatus === 'suspended' ? 'error' : 'warning'}>
                                {(selectedOwner.accessStatus || 'none').toUpperCase()}
                            </Badge>
                        </div>

                        <div className="space-y-4 bg-bg-light rounded-xl p-5 border border-border text-sm">
                            <h4 className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider mb-2">Contact Details</h4>
                            <div className="flex justify-between items-center">
                                <span className="text-text-secondary font-medium">Phone</span>
                                <span className="font-mono text-text-primary font-bold">{selectedOwner.phone || 'Not provided'}</span>
                            </div>
                            <div className="flex justify-between items-center border-t border-border pt-3 mt-3">
                                <span className="text-text-secondary font-medium">Joined</span>
                                <span className="text-text-primary font-bold">
                                    {selectedOwner.createdAt ? format(selectedOwner.createdAt.toDate(), 'MMM dd, yyyy') : 'Unknown'}
                                </span>
                            </div>
                        </div>

                        <div className="space-y-4">
                            <h4 className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider">Managed Location</h4>
                            {selectedOwner.assignedLotId ? (
                                <div className="bg-surface border border-border rounded-xl p-4 flex items-center justify-between">
                                    <div className="flex items-center gap-3">
                                        <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center text-primary">
                                            <Shield className="w-5 h-5" />
                                        </div>
                                        <div>
                                            <p className="text-sm font-bold text-text-primary mb-0.5">{selectedOwner.managedLotName}</p>
                                            <p className="text-xs font-mono text-text-secondary">ID: {selectedOwner.assignedLotId.substring(0, 8)}</p>
                                        </div>
                                    </div>
                                </div>
                            ) : (
                                <div className="bg-warning-bg border border-warning/20 rounded-xl p-4 flex flex-col items-center text-center">
                                    <p className="text-sm font-bold text-warning mb-1">No Location Assigned</p>
                                    <p className="text-xs font-medium text-warning/80">This owner currently cannot manage any parking lot.</p>
                                </div>
                            )}
                        </div>
                    </div>
                )}
            </Drawer>
        </div>
    );
}
