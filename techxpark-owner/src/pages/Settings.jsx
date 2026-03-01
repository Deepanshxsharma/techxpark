import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { useLot } from '../hooks/useLot';
import { db } from '../firebase';
import { doc, updateDoc, collection, query, where, orderBy, onSnapshot } from 'firebase/firestore';
import { User, Building2, Bell, Shield, Smartphone, Lock, Camera, AlertCircle, Key } from 'lucide-react';
import { format } from 'date-fns';
import toast from 'react-hot-toast';
import AskAccessModal from '../components/AskAccessModal';
import Button from '../components/ui/Button';

export default function Settings() {
    const { ownerData, user, uid } = useAuth();
    const { lotData } = useLot(ownerData?.assignedLotId);

    const [activeTab, setActiveTab] = useState('general');
    const [isSaving, setIsSaving] = useState(false);
    const [showAskModal, setShowAskModal] = useState(false);
    const [myRequests, setMyRequests] = useState([]);

    // Real-time request history
    useEffect(() => {
        if (!uid) return;
        const unsub = onSnapshot(
            query(
                collection(db, 'access_requests'),
                where('ownerId', '==', uid),
                orderBy('requestedAt', 'desc')
            ),
            (snap) => {
                setMyRequests(snap.docs.map(d => ({ id: d.id, ...d.data() })));
            },
            (err) => console.error('Request history error:', err)
        );
        return () => unsub();
    }, [uid]);

    // Form State
    const [formData, setFormData] = useState({
        name: ownerData?.name || '',
        phone: ownerData?.phone || '',
    });

    const handleSave = async () => {
        if (!formData.name.trim()) {
            toast.error("Name cannot be empty");
            return;
        }

        setIsSaving(true);
        try {
            const userRef = doc(db, 'users', user.uid);
            await updateDoc(userRef, {
                name: formData.name.trim(),
                phone: formData.phone.trim()
            });
            toast.success("Profile updated successfully");
        } catch (error) {
            console.error("Error updating profile:", error);
            toast.error("Failed to update profile");
        } finally {
            setIsSaving(false);
        }
    };

    const tabs = [
        { id: 'general', label: 'General', icon: User },
        { id: 'lot', label: 'Lot Details', icon: Building2 },
        { id: 'security', label: 'Security', icon: Shield },
        { id: 'notifications', label: 'Notifications', icon: Bell },
        { id: 'integrations', label: 'Integrations', icon: Smartphone },
    ];

    return (
        <div className="max-w-[1000px] mx-auto pb-16 animate-in fade-in duration-300">

            {/* Page Header */}
            <div className="mb-8">
                <h1 className="text-3xl font-bold text-text-primary tracking-tight">Settings</h1>
                <p className="text-[15px] font-medium text-text-secondary mt-1">Manage your account settings and preferences.</p>
            </div>

            {/* Horizontal Tabs (Vercel Style) */}
            <div className="flex items-center gap-6 border-b border-border mb-8 overflow-x-auto scrollbar-none">
                {tabs.map(tab => (
                    <button
                        key={tab.id}
                        onClick={() => setActiveTab(tab.id)}
                        className={`pb-3 text-[14px] font-semibold transition-all relative whitespace-nowrap ${activeTab === tab.id
                            ? 'text-text-primary'
                            : 'text-text-secondary hover:text-text-primary'
                            }`}
                    >
                        <div className="flex items-center gap-2">
                            <tab.icon className="w-4 h-4" />
                            {tab.label}
                        </div>
                        {activeTab === tab.id && (
                            <div className="absolute bottom-[-1px] left-0 w-full h-[2px] bg-text-primary rounded-t-full" />
                        )}
                    </button>
                ))}
            </div>

            <div className="space-y-8">
                {/* Lot Access Section — always visible at top for general tab */}
                {activeTab === 'general' && (
                    <>
                        <div className="bg-white border border-border rounded-xl shadow-sm overflow-hidden">
                            <div className="p-6 md:p-8">
                                <div className="flex items-center gap-3 mb-4">
                                    <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center text-primary">
                                        <Key className="w-5 h-5" />
                                    </div>
                                    <div>
                                        <h2 className="text-[17px] font-bold text-text-primary tracking-tight">Parking Lot Access</h2>
                                        <p className="text-[14px] text-text-secondary">Request access to manage a parking lot</p>
                                    </div>
                                </div>

                                {ownerData?.assignedLotId ? (
                                    <div className="bg-success/5 border border-success/20 rounded-xl p-4 mb-5">
                                        <p className="text-sm font-semibold text-success">✅ Currently managing a parking lot</p>
                                        <p className="text-xs text-success/80 mt-1">You can request access to a different lot if needed</p>
                                    </div>
                                ) : (
                                    <div className="bg-primary/5 border border-primary/20 rounded-xl p-4 mb-5">
                                        <p className="text-sm font-semibold text-primary">No lot assigned yet</p>
                                        <p className="text-xs text-text-secondary mt-1">Request access to start managing a parking lot</p>
                                    </div>
                                )}

                                <Button icon={Key} onClick={() => setShowAskModal(true)}>
                                    Request Lot Access
                                </Button>
                            </div>

                            {myRequests.length > 0 && (
                                <div className="border-t border-border">
                                    <div className="px-6 py-3 bg-surface">
                                        <h3 className="text-[13px] font-bold text-text-secondary">My Access Requests</h3>
                                    </div>
                                    <div className="divide-y divide-border">
                                        {myRequests.map(req => (
                                            <div key={req.id} className="px-6 py-3.5 flex items-center justify-between">
                                                <div>
                                                    <p className="text-sm font-semibold text-text-primary">{req.lotName}</p>
                                                    <p className="text-xs text-text-tertiary mt-0.5">
                                                        {req.requestedAt?.toDate ? format(req.requestedAt.toDate(), 'MMM dd, yyyy • hh:mm a') : 'Just now'}
                                                    </p>
                                                    {req.rejectionReason && (
                                                        <p className="text-xs text-error mt-1">Reason: {req.rejectionReason}</p>
                                                    )}
                                                </div>
                                                <span className={`text-[11px] font-bold px-3 py-1 rounded-full uppercase ${req.status === 'approved' ? 'bg-success/10 text-success'
                                                        : req.status === 'pending' ? 'bg-warning/10 text-warning'
                                                            : 'bg-error/10 text-error'
                                                    }`}>
                                                    {req.status}
                                                </span>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            )}
                        </div>

                        <AskAccessModal isOpen={showAskModal} onClose={() => setShowAskModal(false)} />
                    </>
                )}

                {activeTab === 'general' && (
                    <>
                        {/* Avatar Section */}
                        <div className="bg-white border border-border rounded-xl shadow-sm overflow-hidden flex flex-col md:flex-row">
                            <div className="p-6 md:p-8 flex-1">
                                <h2 className="text-[17px] font-bold text-text-primary mb-1 tracking-tight">Avatar</h2>
                                <p className="text-[14px] text-text-secondary mb-6 leading-relaxed">
                                    This is your avatar. Click on the avatar to upload a custom one from your files.
                                </p>
                                <div className="flex items-center gap-6">
                                    <div className="relative group cursor-pointer">
                                        <div className="w-20 h-20 rounded-full bg-bg-light border border-border flex items-center justify-center overflow-hidden transition-all group-hover:border-primary shadow-xs">
                                            {ownerData?.name ? (
                                                <span className="text-[28px] font-bold text-text-secondary">{ownerData.name.charAt(0).toUpperCase()}</span>
                                            ) : (
                                                <User className="w-8 h-8 text-text-tertiary" />
                                            )}
                                        </div>
                                        <div className="absolute inset-0 bg-black/40 rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                                            <Camera className="w-6 h-6 text-white" />
                                        </div>
                                    </div>
                                    <div className="flex flex-col gap-2">
                                        <p className="text-[12px] font-semibold text-text-tertiary">An avatar is optional but strongly recommended.</p>
                                    </div>
                                </div>
                            </div>
                        </div>

                        {/* Display Name Section (Vercel Style Card) */}
                        <div className="bg-white border border-border rounded-xl shadow-sm overflow-hidden flex flex-col">
                            <div className="p-6 md:p-8 flex-1 md:flex md:gap-8 justify-between">
                                <div className="md:w-1/3 mb-4 md:mb-0">
                                    <h2 className="text-[17px] font-bold text-text-primary mb-1 tracking-tight">Display Name</h2>
                                    <p className="text-[14px] text-text-secondary leading-relaxed">
                                        Please enter your full name, or a display name you are comfortable with.
                                    </p>
                                </div>
                                <div className="md:flex-1 max-w-[400px]">
                                    <input
                                        type="text"
                                        value={formData.name}
                                        onChange={e => setFormData({ ...formData, name: e.target.value })}
                                        className="w-full px-4 py-2.5 bg-bg-light border border-border focus:bg-white focus:border-primary focus:ring-1 focus:ring-primary rounded-lg text-[14px] font-medium text-text-primary outline-none transition-all shadow-xs"
                                        maxLength={32}
                                    />
                                    <p className="text-[12px] text-text-tertiary mt-2">Please use 32 characters at maximum.</p>
                                </div>
                            </div>
                            <div className="bg-surface border-t border-border px-6 py-4 flex items-center justify-between">
                                <p className="text-[13px] text-text-secondary">Please use your real name for verification.</p>
                                <Button
                                    variant="primary"
                                    onClick={handleSave}
                                    loading={isSaving}
                                    disabled={formData.name === ownerData?.name && formData.phone === ownerData?.phone}
                                >
                                    Save
                                </Button>
                            </div>
                        </div>

                        {/* Contact Info Section */}
                        <div className="bg-white border border-border rounded-xl shadow-sm overflow-hidden flex flex-col">
                            <div className="p-6 md:p-8 flex-1 md:flex md:gap-8 justify-between">
                                <div className="md:w-1/3 mb-4 md:mb-0">
                                    <h2 className="text-[17px] font-bold text-text-primary mb-1 tracking-tight">Contact Information</h2>
                                    <p className="text-[14px] text-text-secondary leading-relaxed">
                                        Your email address and phone number for direct support communication.
                                    </p>
                                </div>
                                <div className="md:flex-1 max-w-[400px] space-y-4">
                                    <div>
                                        <label className="block text-[13px] font-bold text-text-secondary mb-1.5">Email Address</label>
                                        <input
                                            type="email"
                                            value={ownerData?.email || ''}
                                            disabled
                                            className="w-full px-4 py-2.5 bg-surface-hover border border-border rounded-lg text-[14px] font-medium text-text-secondary cursor-not-allowed opacity-70"
                                        />
                                    </div>
                                    <div>
                                        <label className="block text-[13px] font-bold text-text-secondary mb-1.5">Phone Number</label>
                                        <input
                                            type="tel"
                                            value={formData.phone}
                                            onChange={e => setFormData({ ...formData, phone: e.target.value })}
                                            className="w-full px-4 py-2.5 bg-bg-light border border-border focus:bg-white focus:border-primary focus:ring-1 focus:ring-primary rounded-lg text-[14px] font-medium text-text-primary outline-none transition-all shadow-xs"
                                        />
                                    </div>
                                </div>
                            </div>
                            <div className="bg-surface border-t border-border px-6 py-4 flex items-center justify-between">
                                <p className="text-[13px] text-text-secondary flex items-center gap-1.5">
                                    <AlertCircle className="w-4 h-4 text-text-tertiary" />
                                    Email changes require HQ approval.
                                </p>
                                <Button
                                    variant="primary"
                                    onClick={handleSave}
                                    loading={isSaving}
                                    disabled={formData.name === ownerData?.name && formData.phone === ownerData?.phone}
                                >
                                    Save
                                </Button>
                            </div>
                        </div>
                    </>
                )}

                {activeTab === 'lot' && (
                    <div className="bg-white border border-border rounded-xl shadow-sm overflow-hidden flex flex-col animate-in fade-in slide-in-from-bottom-2 duration-300">
                        <div className="p-6 md:p-8 flex-1 md:flex md:gap-8 justify-between">
                            <div className="md:w-1/3 mb-6 md:mb-0">
                                <h2 className="text-[17px] font-bold text-text-primary mb-1 tracking-tight">Assigned Lot Configuration</h2>
                                <p className="text-[14px] text-text-secondary leading-relaxed mb-6">
                                    Operational parameters for your globally assigned TechXPark location.
                                </p>
                                <div className="p-4 bg-bg-light border border-border rounded-lg flex items-start gap-3">
                                    <AlertCircle className="w-5 h-5 text-warning shrink-0 mt-0.5" />
                                    <p className="text-[13px] font-medium text-text-secondary leading-relaxed">
                                        Lot boundaries, capacities, and pricing are managed centrally. Please contact HQ for modifications to physical parameters.
                                    </p>
                                </div>
                            </div>
                            <div className="md:flex-1">
                                <div className="border border-border rounded-xl overflow-hidden">
                                    <div className="h-40 bg-surface-hover border-b border-border flex items-center justify-center relative overflow-hidden">
                                        {lotData?.image ? (
                                            <img src={lotData.image} alt={lotData.name} className="w-full h-full object-cover" />
                                        ) : (
                                            <Building2 className="w-12 h-12 text-text-tertiary" />
                                        )}
                                        <div className="absolute inset-0 bg-gradient-to-t from-black/50 to-transparent flex items-end p-5">
                                            <h3 className="text-xl font-bold text-white tracking-tight">{lotData?.name || 'Loading Facility...'}</h3>
                                        </div>
                                    </div>
                                    <div className="p-5 bg-white space-y-5">
                                        <div>
                                            <label className="text-[11px] font-bold text-text-tertiary uppercase tracking-[0.8px]">Location Matrix</label>
                                            <p className="text-[14px] font-semibold text-text-primary mt-1">{lotData?.address || '...'}</p>
                                        </div>
                                        <div className="grid grid-cols-2 gap-4">
                                            <div>
                                                <label className="text-[11px] font-bold text-text-tertiary uppercase tracking-[0.8px]">Total Capacity</label>
                                                <p className="text-[15px] font-mono font-bold text-text-primary mt-1">{lotData?.available_slots || 0} Slots</p>
                                            </div>
                                            <div>
                                                <label className="text-[11px] font-bold text-text-tertiary uppercase tracking-[0.8px]">Levels / Floors</label>
                                                <p className="text-[15px] font-mono font-bold text-text-primary mt-1">{lotData?.total_floors || 0}</p>
                                            </div>
                                        </div>
                                        <div>
                                            <label className="text-[11px] font-bold text-text-tertiary uppercase tracking-[0.8px]">Global ID</label>
                                            <p className="text-[13px] font-mono font-bold text-text-secondary bg-bg-light border border-border px-2 py-1 rounded w-fit mt-1">
                                                {ownerData?.assignedLotId || '...'}
                                            </p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                )}

                {activeTab === 'security' && (
                    <div className="bg-white border border-border rounded-xl shadow-sm overflow-hidden flex flex-col animate-in fade-in slide-in-from-bottom-2 duration-300">
                        <div className="p-6 md:p-8 flex-1 md:flex md:gap-8 justify-between">
                            <div className="md:w-1/3 mb-4 md:mb-0">
                                <h2 className="text-[17px] font-bold text-text-primary mb-1 tracking-tight">Authentication</h2>
                                <p className="text-[14px] text-text-secondary leading-relaxed">
                                    Manage your password and security settings.
                                </p>
                            </div>
                            <div className="md:flex-1 flex items-center">
                                <Button variant="secondary" icon={Lock}>
                                    Send Password Reset Email
                                </Button>
                            </div>
                        </div>
                    </div>
                )}

                {['notifications', 'integrations'].includes(activeTab) && (
                    <div className="bg-white border border-border rounded-xl shadow-sm p-12 flex flex-col items-center justify-center animate-in fade-in slide-in-from-bottom-2 duration-300 text-center">
                        <div className="w-12 h-12 bg-surface-hover rounded-full flex items-center justify-center mb-4 border border-border">
                            {activeTab === 'notifications' ? <Bell className="w-5 h-5 text-text-tertiary" /> : <Smartphone className="w-5 h-5 text-text-tertiary" />}
                        </div>
                        <h2 className="text-[17px] font-bold text-text-primary mb-1">Coming Soon</h2>
                        <p className="text-[14px] text-text-secondary max-w-[300px]">
                            This feature is currently under active development.
                        </p>
                    </div>
                )}

            </div>
        </div>
    );
}
