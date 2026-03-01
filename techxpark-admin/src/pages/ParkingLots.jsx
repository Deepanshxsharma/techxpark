import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import {
    collection, query, onSnapshot, getDoc, doc, addDoc,
    updateDoc, deleteDoc, writeBatch, serverTimestamp, getDocs, where
} from 'firebase/firestore';
import { Plus, Car, MapPin, Search, Layers, Users as UsersIcon, MoreVertical, Edit3, Trash2, Power, PowerOff } from 'lucide-react';
import Button from '../components/ui/Button';
import Card from '../components/ui/Card';
import Badge from '../components/ui/Badge';
import Avatar from '../components/ui/Avatar';
import Modal from '../components/ui/Modal';
import { format } from 'date-fns';
import toast from 'react-hot-toast';
import { formatCurrency } from '../utils/helpers';

export default function ParkingLots() {
    const [lots, setLots] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [filterTab, setFilterTab] = useState('all');

    // Add/Edit Modal
    const [modalOpen, setModalOpen] = useState(false);
    const [editingLot, setEditingLot] = useState(null);
    const [saving, setSaving] = useState(false);
    const [form, setForm] = useState({
        name: '', address: '', city: '', state: '',
        pricePerHour: '', total_floors: '', total_slots: '',
        latitude: '', longitude: ''
    });

    // Delete confirm
    const [deleteTarget, setDeleteTarget] = useState(null);
    const [deleteConfirm, setDeleteConfirm] = useState('');
    const [deleting, setDeleting] = useState(false);

    // Deactivate confirm
    const [toggleTarget, setToggleTarget] = useState(null);

    useEffect(() => {
        const q = query(collection(db, 'parking_locations'));
        const unsubscribe = onSnapshot(q, async (snapshot) => {
            const locs = [];
            // Batch fetch owner data
            const ownerIds = new Set();
            snapshot.docs.forEach(d => {
                const data = d.data();
                if (data.assignedOwnerId) ownerIds.add(data.assignedOwnerId);
                else if (data.ownerId) ownerIds.add(data.ownerId);
            });
            const ownerMap = {};
            for (const oid of ownerIds) {
                try {
                    const snap = await getDoc(doc(db, 'users', oid));
                    if (snap.exists()) ownerMap[oid] = snap.data();
                } catch (e) { /* skip */ }
            }

            snapshot.docs.forEach(d => {
                const data = d.data();
                const oid = data.assignedOwnerId || data.ownerId;
                locs.push({
                    id: d.id,
                    ...data,
                    ownerData: oid ? ownerMap[oid] || null : null
                });
            });
            setLots(locs);
            setLoading(false);
        });
        return () => unsubscribe();
    }, []);

    const openAddModal = () => {
        setEditingLot(null);
        setForm({ name: '', address: '', city: '', state: '', pricePerHour: '', total_floors: '', total_slots: '', latitude: '', longitude: '' });
        setModalOpen(true);
    };

    const openEditModal = (lot) => {
        setEditingLot(lot);
        setForm({
            name: lot.name || '',
            address: lot.address || '',
            city: lot.city || '',
            state: lot.state || '',
            pricePerHour: lot.pricePerHour || '',
            total_floors: lot.total_floors || '',
            total_slots: lot.total_slots || '',
            latitude: lot.latitude || '',
            longitude: lot.longitude || '',
        });
        setModalOpen(true);
    };

    const handleSave = async () => {
        if (!form.name.trim() || !form.address.trim()) {
            toast.error('Name and address are required');
            return;
        }
        setSaving(true);
        try {
            const lotData = {
                name: form.name.trim(),
                address: form.address.trim(),
                city: form.city.trim(),
                state: form.state.trim(),
                pricePerHour: Number(form.pricePerHour) || 0,
                total_floors: Number(form.total_floors) || 1,
                total_slots: Number(form.total_slots) || 0,
                latitude: Number(form.latitude) || 0,
                longitude: Number(form.longitude) || 0,
            };

            if (editingLot) {
                await updateDoc(doc(db, 'parking_locations', editingLot.id), lotData);
                toast.success('Lot updated');
            } else {
                await addDoc(collection(db, 'parking_locations'), {
                    ...lotData,
                    available_slots: lotData.total_slots,
                    isActive: true,
                    isAssigned: false,
                    assignedOwnerId: null,
                    createdAt: serverTimestamp(),
                });
                toast.success('New lot added');
            }
            setModalOpen(false);
        } catch (err) {
            console.error('Save lot error:', err);
            toast.error('Failed to save lot');
        } finally {
            setSaving(false);
        }
    };

    const handleToggleActive = async (lot) => {
        try {
            await updateDoc(doc(db, 'parking_locations', lot.id), { isActive: !lot.isActive });
            toast.success(lot.isActive ? 'Lot deactivated' : 'Lot activated');
            setToggleTarget(null);
        } catch (err) {
            toast.error('Failed to update lot');
        }
    };

    const handleDelete = async () => {
        if (!deleteTarget || deleteConfirm !== deleteTarget.name) return;
        setDeleting(true);
        try {
            // Revoke assigned owner if exists
            if (deleteTarget.assignedOwnerId) {
                await updateDoc(doc(db, 'users', deleteTarget.assignedOwnerId), {
                    accessStatus: 'none',
                    assignedLotId: null,
                });
            }
            await deleteDoc(doc(db, 'parking_locations', deleteTarget.id));
            toast.success('Lot deleted');
            setDeleteTarget(null);
            setDeleteConfirm('');
        } catch (err) {
            toast.error('Failed to delete lot');
        } finally {
            setDeleting(false);
        }
    };

    const tabs = [
        { id: 'all', label: 'All' },
        { id: 'active', label: 'Active' },
        { id: 'inactive', label: 'Inactive' },
        { id: 'unassigned', label: 'Unassigned' },
    ];

    const filteredLots = lots.filter(lot => {
        const matchSearch = (lot.name?.toLowerCase() || '').includes(searchTerm.toLowerCase()) ||
            (lot.address?.toLowerCase() || '').includes(searchTerm.toLowerCase());
        if (!matchSearch) return false;
        if (filterTab === 'active') return lot.isActive !== false;
        if (filterTab === 'inactive') return lot.isActive === false;
        if (filterTab === 'unassigned') return !lot.assignedOwnerId && !lot.isAssigned;
        return true;
    });

    return (
        <div className="space-y-6 animate-fade-in pb-10">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div className="relative flex-1 max-w-md">
                    <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-text-tertiary" />
                    <input
                        type="text"
                        placeholder="Search parking locations..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        className="w-full pl-10 pr-4 py-2.5 bg-surface border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-primary focus:ring-4 focus:ring-primary/10 transition-all"
                    />
                </div>
                <Button icon={Plus} onClick={openAddModal}>Add New Location</Button>
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

            {loading ? (
                <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
                    {[1, 2, 3, 4, 5, 6].map(i => (
                        <div key={i} className="h-[300px] bg-slate-100 rounded-2xl animate-pulse"></div>
                    ))}
                </div>
            ) : filteredLots.length === 0 ? (
                <div className="flex flex-col items-center justify-center p-16 bg-surface border border-border rounded-2xl text-center">
                    <div className="w-16 h-16 bg-bg-light rounded-full flex items-center justify-center mb-4">
                        <Car className="w-8 h-8 text-text-tertiary" />
                    </div>
                    <h3 className="text-lg font-bold text-text-primary mb-2">No parking lots found</h3>
                    <p className="text-sm font-medium text-text-secondary max-w-sm mb-6">
                        {searchTerm ? 'Try adjusting your search query.' : 'Get started by adding your first parking location.'}
                    </p>
                    {!searchTerm && <Button icon={Plus} onClick={openAddModal}>Add Location</Button>}
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
                    {filteredLots.map((lot) => {
                        const totalSlots = lot.total_slots || 0;
                        const availableSlots = lot.available_slots || 0;
                        const occupancyRate = totalSlots > 0 ? Math.round(((totalSlots - availableSlots) / totalSlots) * 100) : 0;

                        return (
                            <Card key={lot.id} padding="p-0" className="overflow-hidden flex flex-col group hover:-translate-y-1 transition-transform duration-300">
                                <div className="h-32 bg-sidebar-bg relative border-b border-border/50">
                                    {lot.image ? (
                                        <img src={lot.image} alt={lot.name} className="w-full h-full object-cover opacity-80 mix-blend-overlay" />
                                    ) : (
                                        <div className="absolute inset-0 opacity-20 bg-[url('https://www.transparenttextures.com/patterns/cubes.png')] mix-blend-overlay"></div>
                                    )}
                                    <div className="absolute inset-0 bg-gradient-to-t from-sidebar-bg via-sidebar-bg/50 to-transparent"></div>

                                    <div className="absolute top-4 right-4 z-10 flex gap-2">
                                        {lot.isActive === false && <Badge variant="error">Inactive</Badge>}
                                        <Badge
                                            variant={occupancyRate > 90 ? 'error' : occupancyRate > 70 ? 'warning' : 'success'}
                                            dot
                                            pulse={occupancyRate > 90}
                                        >
                                            {occupancyRate > 90 ? 'Full' : occupancyRate > 70 ? 'Filling Fast' : 'Available'}
                                        </Badge>
                                    </div>

                                    <div className="absolute bottom-4 left-5 right-5 z-10">
                                        <h3 className="text-lg font-bold text-white truncate drop-shadow-md">{lot.name || 'Unnamed Lot'}</h3>
                                        <div className="flex items-center gap-1.5 text-xs font-medium text-sidebar-text mt-1">
                                            <MapPin className="w-3 h-3 text-primary-light" />
                                            <span className="truncate">{lot.address || 'No address provided'}</span>
                                        </div>
                                    </div>
                                </div>

                                <div className="p-5 flex-1 flex flex-col">
                                    <div className="grid grid-cols-3 divide-x divide-border bg-bg-light rounded-xl border border-border mb-5 py-3">
                                        <div className="flex flex-col items-center justify-center px-2">
                                            <span className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider mb-1">Slots</span>
                                            <div className="flex items-baseline gap-1">
                                                <span className="text-[17px] font-extrabold text-text-primary leading-none">{availableSlots}</span>
                                                <span className="text-[11px] font-semibold text-text-secondary">/{totalSlots}</span>
                                            </div>
                                        </div>
                                        <div className="flex flex-col items-center justify-center px-2">
                                            <span className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider mb-1">Floors</span>
                                            <span className="text-[17px] font-extrabold text-text-primary leading-none">{lot.total_floors || 0}</span>
                                        </div>
                                        <div className="flex flex-col items-center justify-center px-2">
                                            <span className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider mb-1">Occupancy</span>
                                            <span className={`text-[14px] font-extrabold leading-none ${occupancyRate > 80 ? 'text-error' : occupancyRate > 50 ? 'text-warning' : 'text-success'}`}>
                                                {occupancyRate}%
                                            </span>
                                        </div>
                                    </div>

                                    <div className="space-y-4 flex-1">
                                        <div className="flex justify-between items-center px-2">
                                            <div className="flex items-center gap-2">
                                                <div className="w-6 h-6 rounded bg-primary/10 flex items-center justify-center text-primary">
                                                    <UsersIcon className="w-3.5 h-3.5" />
                                                </div>
                                                <span className="text-[12px] font-semibold text-text-secondary">Assigned Owner</span>
                                            </div>
                                            <div className="flex items-center gap-2">
                                                {lot.ownerData ? (
                                                    <>
                                                        <Avatar name={lot.ownerData.name} size="sm" className="w-6 h-6 text-[9px]" />
                                                        <span className="text-[13px] font-bold text-text-primary">{lot.ownerData.name}</span>
                                                    </>
                                                ) : (
                                                    <Badge variant="warning">Unassigned</Badge>
                                                )}
                                            </div>
                                        </div>
                                        {lot.pricePerHour > 0 && (
                                            <div className="flex justify-between items-center px-2">
                                                <span className="text-[12px] font-semibold text-text-secondary">Rate</span>
                                                <span className="text-[13px] font-bold text-text-primary">{formatCurrency(lot.pricePerHour)}/hr</span>
                                            </div>
                                        )}
                                    </div>
                                </div>

                                <div className="px-5 py-4 border-t border-border bg-surface flex items-center justify-between">
                                    <span className="text-[11px] font-bold text-text-tertiary uppercase tracking-widest">
                                        ID: <span className="font-mono text-text-secondary">{lot.id.substring(0, 8)}</span>
                                    </span>
                                    <div className="flex gap-1">
                                        <button onClick={() => openEditModal(lot)} className="px-2 py-1.5 rounded-lg text-[12px] font-bold text-primary hover:bg-primary/10 transition-all">
                                            <Edit3 className="w-3.5 h-3.5" />
                                        </button>
                                        <button onClick={() => setToggleTarget(lot)} className="px-2 py-1.5 rounded-lg text-[12px] font-bold text-warning hover:bg-warning/10 transition-all">
                                            {lot.isActive === false ? <Power className="w-3.5 h-3.5" /> : <PowerOff className="w-3.5 h-3.5" />}
                                        </button>
                                        <button onClick={() => setDeleteTarget(lot)} className="px-2 py-1.5 rounded-lg text-[12px] font-bold text-error hover:bg-error/10 transition-all">
                                            <Trash2 className="w-3.5 h-3.5" />
                                        </button>
                                    </div>
                                </div>
                            </Card>
                        );
                    })}
                </div>
            )}

            {/* Add/Edit Modal */}
            <Modal isOpen={modalOpen} onClose={() => setModalOpen(false)} title={editingLot ? 'Edit Parking Lot' : 'Add New Parking Lot'} size="md"
                footer={
                    <>
                        <Button variant="secondary" onClick={() => setModalOpen(false)}>Cancel</Button>
                        <Button onClick={handleSave} disabled={saving}>{saving ? 'Saving...' : editingLot ? 'Update Lot' : 'Create Lot'}</Button>
                    </>
                }
            >
                <div className="space-y-4">
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                        <div className="sm:col-span-2">
                            <label className="text-[12px] font-bold text-text-primary uppercase tracking-wider mb-1.5 block">Name *</label>
                            <input type="text" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Phoenix Mall Parking"
                                className="w-full px-4 py-2.5 bg-bg-light border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10" />
                        </div>
                        <div className="sm:col-span-2">
                            <label className="text-[12px] font-bold text-text-primary uppercase tracking-wider mb-1.5 block">Address *</label>
                            <input type="text" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} placeholder="123 Main Street"
                                className="w-full px-4 py-2.5 bg-bg-light border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10" />
                        </div>
                        <div>
                            <label className="text-[12px] font-bold text-text-primary uppercase tracking-wider mb-1.5 block">City</label>
                            <input type="text" value={form.city} onChange={(e) => setForm({ ...form, city: e.target.value })} placeholder="Mumbai"
                                className="w-full px-4 py-2.5 bg-bg-light border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-primary" />
                        </div>
                        <div>
                            <label className="text-[12px] font-bold text-text-primary uppercase tracking-wider mb-1.5 block">State</label>
                            <input type="text" value={form.state} onChange={(e) => setForm({ ...form, state: e.target.value })} placeholder="Maharashtra"
                                className="w-full px-4 py-2.5 bg-bg-light border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-primary" />
                        </div>
                        <div>
                            <label className="text-[12px] font-bold text-text-primary uppercase tracking-wider mb-1.5 block">Total Floors</label>
                            <input type="number" value={form.total_floors} onChange={(e) => setForm({ ...form, total_floors: e.target.value })} placeholder="3"
                                className="w-full px-4 py-2.5 bg-bg-light border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-primary" />
                        </div>
                        <div>
                            <label className="text-[12px] font-bold text-text-primary uppercase tracking-wider mb-1.5 block">Total Slots</label>
                            <input type="number" value={form.total_slots} onChange={(e) => setForm({ ...form, total_slots: e.target.value })} placeholder="60"
                                className="w-full px-4 py-2.5 bg-bg-light border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-primary" />
                        </div>
                        <div>
                            <label className="text-[12px] font-bold text-text-primary uppercase tracking-wider mb-1.5 block">Price per Hour (₹)</label>
                            <input type="number" value={form.pricePerHour} onChange={(e) => setForm({ ...form, pricePerHour: e.target.value })} placeholder="50"
                                className="w-full px-4 py-2.5 bg-bg-light border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-primary" />
                        </div>
                        <div>
                            <label className="text-[12px] font-bold text-text-primary uppercase tracking-wider mb-1.5 block">Latitude</label>
                            <input type="number" step="any" value={form.latitude} onChange={(e) => setForm({ ...form, latitude: e.target.value })} placeholder="19.0760"
                                className="w-full px-4 py-2.5 bg-bg-light border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-primary" />
                        </div>
                        <div>
                            <label className="text-[12px] font-bold text-text-primary uppercase tracking-wider mb-1.5 block">Longitude</label>
                            <input type="number" step="any" value={form.longitude} onChange={(e) => setForm({ ...form, longitude: e.target.value })} placeholder="72.8777"
                                className="w-full px-4 py-2.5 bg-bg-light border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-primary" />
                        </div>
                    </div>
                </div>
            </Modal>

            {/* Toggle Active Confirm */}
            <Modal isOpen={!!toggleTarget} onClose={() => setToggleTarget(null)} title={toggleTarget?.isActive === false ? 'Activate Lot' : 'Deactivate Lot'} size="sm">
                <div className="space-y-4">
                    <p className="text-sm text-text-secondary">
                        {toggleTarget?.isActive === false
                            ? `Activate ${toggleTarget?.name}? It will become visible to customers.`
                            : `Deactivate ${toggleTarget?.name}? It will be hidden from customers.`
                        }
                    </p>
                    <div className="flex gap-3">
                        <Button variant="secondary" className="flex-1" onClick={() => setToggleTarget(null)}>Cancel</Button>
                        <Button variant={toggleTarget?.isActive === false ? 'primary' : 'danger'} className="flex-1" onClick={() => handleToggleActive(toggleTarget)}>
                            {toggleTarget?.isActive === false ? 'Activate' : 'Deactivate'}
                        </Button>
                    </div>
                </div>
            </Modal>

            {/* Delete Confirm */}
            <Modal isOpen={!!deleteTarget} onClose={() => { setDeleteTarget(null); setDeleteConfirm(''); }} title="Delete Parking Lot" size="sm">
                <div className="space-y-4">
                    <p className="text-sm text-text-secondary">
                        This will permanently delete <strong>{deleteTarget?.name}</strong>. Type the lot name to confirm.
                    </p>
                    <input
                        type="text"
                        value={deleteConfirm}
                        onChange={(e) => setDeleteConfirm(e.target.value)}
                        placeholder={`Type "${deleteTarget?.name}" to confirm`}
                        className="w-full px-4 py-2.5 border border-border rounded-xl text-sm font-bold focus:outline-none focus:border-error"
                    />
                    <div className="flex gap-3">
                        <Button variant="secondary" className="flex-1" onClick={() => { setDeleteTarget(null); setDeleteConfirm(''); }}>Cancel</Button>
                        <Button variant="danger" className="flex-1" onClick={handleDelete} disabled={deleteConfirm !== deleteTarget?.name || deleting}>
                            {deleting ? 'Deleting...' : 'Delete Lot'}
                        </Button>
                    </div>
                </div>
            </Modal>
        </div>
    );
}
