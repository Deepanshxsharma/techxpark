import React, { useState, useEffect } from 'react';
import { Settings as SettingsIcon, ShieldCheck, Database, Bell, Lock, UserCog, LogOut, AlertTriangle, Smartphone, Save, Loader2 } from 'lucide-react';
import Card from '../components/ui/Card';
import Button from '../components/ui/Button';
import Avatar from '../components/ui/Avatar';
import Badge from '../components/ui/Badge';
import { useAuth } from '../hooks/useAuth';
import { db } from '../firebase';
import { collection, query, where, onSnapshot, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';
import toast from 'react-hot-toast';

export default function Settings() {
    const { user, logout } = useAuth();
    const [admins, setAdmins] = useState([]);
    const [settings, setSettings] = useState({
        platformStatus: 'live',
        commission: 15,
        supportEmail: '',
        supportPhone: '',
    });
    const [settingsLoading, setSettingsLoading] = useState(true);
    const [saving, setSaving] = useState(false);

    // Fetch real platform settings
    useEffect(() => {
        const fetchSettings = async () => {
            try {
                const snap = await getDoc(doc(db, 'platform_settings', 'general'));
                if (snap.exists()) {
                    const data = snap.data();
                    setSettings({
                        platformStatus: data.platformStatus || 'live',
                        commission: data.commission || 15,
                        supportEmail: data.supportEmail || '',
                        supportPhone: data.supportPhone || '',
                    });
                }
            } catch (e) {
                console.error('Failed to load settings:', e);
            } finally {
                setSettingsLoading(false);
            }
        };
        fetchSettings();
    }, []);

    // Fetch real admin list
    useEffect(() => {
        const q = query(collection(db, 'users'), where('role', '==', 'admin'));
        const unsub = onSnapshot(q, (snap) => {
            setAdmins(snap.docs.map(d => ({ id: d.id, ...d.data() })));
        });
        return () => unsub();
    }, []);

    const handleSaveSettings = async () => {
        setSaving(true);
        try {
            await setDoc(doc(db, 'platform_settings', 'general'), {
                platformStatus: settings.platformStatus,
                commission: Number(settings.commission) || 15,
                supportEmail: settings.supportEmail.trim(),
                supportPhone: settings.supportPhone.trim(),
            }, { merge: true });
            toast.success('Settings saved');
        } catch (e) {
            console.error('Save settings error:', e);
            toast.error('Failed to save settings');
        } finally {
            setSaving(false);
        }
    };

    const handleTogglePlatform = async (status) => {
        setSettings(prev => ({ ...prev, platformStatus: status }));
        try {
            await updateDoc(doc(db, 'platform_settings', 'general'), { platformStatus: status });
            toast.success(status === 'live' ? 'Platform is live' : 'Maintenance mode enabled');
        } catch (e) {
            // If doc doesn't exist, create it
            try {
                await setDoc(doc(db, 'platform_settings', 'general'), { platformStatus: status }, { merge: true });
                toast.success(status === 'live' ? 'Platform is live' : 'Maintenance mode enabled');
            } catch (e2) {
                toast.error('Failed to update status');
            }
        }
    };

    return (
        <div className="space-y-6 animate-fade-in pb-10 max-w-5xl mx-auto">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-border pb-6">
                <div>
                    <h1 className="text-2xl font-bold text-text-primary tracking-tight">Platform Settings</h1>
                    <p className="text-sm font-medium text-text-secondary mt-1">Configure global parameters and manage admin access.</p>
                </div>
                <Button variant="secondary" icon={LogOut} onClick={logout}>Sign Out</Button>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                {/* Left Column */}
                <div className="space-y-6">
                    <Card className="flex flex-col items-center text-center">
                        <div className="relative mb-4">
                            <Avatar name={user?.name || 'Super Admin'} size="xl" />
                            <div className="absolute -bottom-1 -right-1 w-6 h-6 bg-surface border-2 border-border rounded-full flex items-center justify-center shadow-sm">
                                <ShieldCheck className="w-3.5 h-3.5 text-primary" />
                            </div>
                        </div>
                        <h2 className="text-lg font-bold text-text-primary mb-1">{user?.name || 'Super Admin Account'}</h2>
                        <p className="text-[13px] font-medium text-text-secondary mb-4">{user?.email}</p>
                        <Badge variant="success" dot pulse>System Administrator</Badge>
                    </Card>
                </div>

                {/* Right Column */}
                <div className="col-span-1 lg:col-span-2 space-y-6">
                    <Card>
                        <h3 className="text-base font-bold text-text-primary mb-6 flex items-center gap-2">
                            <Smartphone className="w-5 h-5 text-text-tertiary" />
                            App Configuration
                        </h3>

                        {settingsLoading ? (
                            <div className="py-8 flex justify-center">
                                <Loader2 className="w-6 h-6 text-text-tertiary animate-spin" />
                            </div>
                        ) : (
                            <div className="space-y-5">
                                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 py-4 border-b border-border">
                                    <div>
                                        <h4 className="text-[14px] font-bold text-text-primary mb-1">Platform Status</h4>
                                        <p className="text-[12px] font-medium text-text-secondary max-w-sm">Temporarily disable logins during maintenance.</p>
                                    </div>
                                    <div className="flex items-center gap-3 bg-bg-light p-1 rounded-lg border border-border">
                                        <button
                                            className={`px-4 py-1.5 rounded-md text-[12px] font-bold transition-colors ${settings.platformStatus === 'live' ? 'bg-white shadow-sm text-primary' : 'text-text-tertiary hover:text-text-secondary'}`}
                                            onClick={() => handleTogglePlatform('live')}
                                        >Live</button>
                                        <button
                                            className={`px-4 py-1.5 rounded-md text-[12px] font-bold transition-colors ${settings.platformStatus === 'maintenance' ? 'bg-white shadow-sm text-warning' : 'text-text-tertiary hover:text-text-secondary'}`}
                                            onClick={() => handleTogglePlatform('maintenance')}
                                        >Maintenance</button>
                                    </div>
                                </div>

                                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 py-4 border-b border-border">
                                    <div className="flex-1 space-y-2">
                                        <h4 className="text-[14px] font-bold text-text-primary mb-1">Base Platform Commission</h4>
                                        <p className="text-[12px] font-medium text-text-secondary max-w-sm mb-3">Default revenue split applied to all new parking lots.</p>
                                        <div className="flex items-center gap-2 max-w-[200px]">
                                            <input
                                                type="number"
                                                value={settings.commission}
                                                onChange={(e) => setSettings(prev => ({ ...prev, commission: e.target.value }))}
                                                className="w-full px-3 py-2 border border-border rounded-lg text-sm font-extrabold focus:outline-none focus:border-primary text-text-primary"
                                            />
                                            <span className="text-[14px] font-bold text-text-tertiary">%</span>
                                        </div>
                                    </div>
                                </div>

                                <div className="py-4">
                                    <h4 className="text-[14px] font-bold text-text-primary mb-3">Support Contact Details</h4>
                                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                        <input
                                            type="email"
                                            value={settings.supportEmail}
                                            onChange={(e) => setSettings(prev => ({ ...prev, supportEmail: e.target.value }))}
                                            placeholder="support@techxpark.app"
                                            className="px-4 py-2.5 border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-primary bg-bg-light"
                                        />
                                        <input
                                            type="tel"
                                            value={settings.supportPhone}
                                            onChange={(e) => setSettings(prev => ({ ...prev, supportPhone: e.target.value }))}
                                            placeholder="+91 1800 123 4567"
                                            className="px-4 py-2.5 border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-primary bg-bg-light"
                                        />
                                    </div>
                                    <div className="mt-4 flex justify-end">
                                        <Button size="sm" icon={Save} onClick={handleSaveSettings} disabled={saving}>
                                            {saving ? 'Saving...' : 'Save All Settings'}
                                        </Button>
                                    </div>
                                </div>
                            </div>
                        )}
                    </Card>

                    {/* Real Admin List */}
                    <Card padding="p-0">
                        <div className="px-5 py-4 border-b border-border bg-surface-hover/50 flex justify-between items-center">
                            <h3 className="text-sm font-bold text-text-primary flex items-center gap-2">
                                <ShieldCheck className="w-4 h-4 text-primary" />
                                Authorized Administrators
                            </h3>
                        </div>
                        <div className="divide-y divide-border">
                            {admins.length === 0 ? (
                                <div className="p-4 flex items-center justify-between group">
                                    <div className="flex items-center gap-3">
                                        <Avatar name={user?.name || 'Admin'} size="sm" />
                                        <div>
                                            <p className="text-[13px] font-bold text-text-primary">{user?.name || 'Admin'} (You)</p>
                                            <p className="text-[11px] font-medium text-text-secondary">{user?.email}</p>
                                        </div>
                                    </div>
                                    <Badge variant="success">Super Admin</Badge>
                                </div>
                            ) : (
                                admins.map(admin => (
                                    <div key={admin.id} className="p-4 flex items-center justify-between group">
                                        <div className="flex items-center gap-3">
                                            <Avatar name={admin.name || admin.email} size="sm" />
                                            <div>
                                                <p className="text-[13px] font-bold text-text-primary flex items-center gap-1.5">
                                                    {admin.name || admin.email}
                                                    {admin.id === user?.uid && <span className="text-[10px] text-text-tertiary">(You)</span>}
                                                </p>
                                                <p className="text-[11px] font-medium text-text-secondary">{admin.email}</p>
                                            </div>
                                        </div>
                                        <Badge variant="success">Admin</Badge>
                                    </div>
                                ))
                            )}
                        </div>
                    </Card>

                    {/* Danger Zone */}
                    <Card className="border-error/20 bg-error/5 relative overflow-hidden">
                        <h3 className="text-base font-bold text-error mb-2 flex items-center gap-2">
                            <AlertTriangle className="w-5 h-5 flex-shrink-0" />
                            Danger Zone
                        </h3>
                        <p className="text-sm font-medium text-error-text mb-6">Irreversible actions that affect the entire TechXPark platform.</p>
                        <div className="space-y-4">
                            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-4 border border-error/20 bg-white shadow-sm rounded-xl">
                                <div>
                                    <h4 className="text-[14px] font-bold text-text-primary">Purge Sensor Logs</h4>
                                    <p className="text-[12px] font-medium text-text-secondary mt-0.5">Delete all IoT pings older than 30 days to free DB space.</p>
                                </div>
                                <Button variant="secondary" className="text-error border-error/20 bg-error/5 hover:bg-error hover:text-white shrink-0">Purge Logs</Button>
                            </div>
                        </div>
                    </Card>
                </div>
            </div>
        </div>
    );
}
