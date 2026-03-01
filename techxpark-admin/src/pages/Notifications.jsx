import React, { useState, useEffect } from 'react';
import { Send, Users, UserSquare2, Car, BellRing, Type, LayoutTemplate, CheckCircle2, Loader2 } from 'lucide-react';
import Card from '../components/ui/Card';
import Button from '../components/ui/Button';
import Badge from '../components/ui/Badge';
import { db, functions } from '../firebase';
import { collection, query, orderBy, limit, onSnapshot, addDoc, serverTimestamp } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import toast from 'react-hot-toast';
import { formatTimeAgo } from '../utils/helpers';

export default function Notifications() {
    const [title, setTitle] = useState('');
    const [message, setMessage] = useState('');
    const [audience, setAudience] = useState('all');
    const [loading, setLoading] = useState(false);
    const [history, setHistory] = useState([]);
    const [historyLoading, setHistoryLoading] = useState(true);

    // Quick templates
    const templates = [
        { title: 'System Maintenance', body: 'Platform will undergo scheduled maintenance. Services will be temporarily unavailable.' },
        { title: 'New Feature Available', body: "We've added exciting new features to improve your parking experience. Update now!" },
        { title: 'Holiday Hours', body: 'Please note adjusted operating hours during the holiday period.' },
    ];

    // Real-time notification history
    useEffect(() => {
        const q = query(collection(db, 'notifications'), orderBy('createdAt', 'desc'), limit(20));
        const unsub = onSnapshot(q, (snap) => {
            setHistory(snap.docs.map(d => ({ id: d.id, ...d.data() })));
            setHistoryLoading(false);
        }, (err) => {
            console.error('Notifications history error:', err);
            setHistoryLoading(false);
        });
        return () => unsub();
    }, []);

    const handleSend = async () => {
        if (!title.trim() || !message.trim()) {
            toast.error("Both title and message body are required.");
            return;
        }

        setLoading(true);
        try {
            // Try cloud function first
            let sent = 0;
            try {
                const sendBroadcast = httpsCallable(functions, 'broadcastNotification');
                let targetType = 'all_users';
                if (audience === 'customers') targetType = 'all_users';
                else if (audience === 'owners') targetType = 'all_owners';

                const result = await sendBroadcast({
                    title: title,
                    body: message,
                    type: 'broadcast',
                    targetType: targetType
                });
                sent = result.data?.sent || 0;
            } catch (fnErr) {
                console.warn('Cloud function not available, saving to Firestore only:', fnErr.message);
            }

            // Always save to notifications collection for history
            await addDoc(collection(db, 'notifications'), {
                title: title.trim(),
                body: message.trim(),
                audience: audience,
                type: 'broadcast',
                sentCount: sent,
                createdAt: serverTimestamp(),
            });

            toast.success(sent > 0 ? `Sent to ${sent} devices` : 'Notification saved');
            setTitle('');
            setMessage('');
        } catch (error) {
            console.error("Broadcast failed", error);
            toast.error('Failed to send notification');
        } finally {
            setLoading(false);
        }
    };

    const audienceLabels = { all: 'All Users', customers: 'Customers', owners: 'Owners', lot: 'Specific Lot' };

    return (
        <div className="space-y-6 animate-fade-in pb-10">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-border pb-6">
                <div>
                    <h1 className="text-2xl font-bold text-text-primary tracking-tight">Push Notifications</h1>
                    <p className="text-sm font-medium text-text-secondary mt-1">Broadcast system alerts and updates to platform users.</p>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* Compose Form */}
                <Card className="flex flex-col space-y-6">
                    <h2 className="text-base font-bold text-text-primary border-b border-border pb-4">Compose Broadcast</h2>

                    {/* Quick Templates */}
                    <div className="space-y-2">
                        <label className="text-[12px] font-bold text-text-primary uppercase tracking-wider flex items-center gap-2">Quick Templates</label>
                        <div className="flex gap-2 flex-wrap">
                            {templates.map((t, i) => (
                                <button
                                    key={i}
                                    onClick={() => { setTitle(t.title); setMessage(t.body); }}
                                    className="px-3 py-1.5 rounded-lg border border-border text-[12px] font-bold text-text-secondary hover:bg-primary/5 hover:border-primary/30 hover:text-primary transition-all"
                                >{t.title}</button>
                            ))}
                        </div>
                    </div>

                    {/* Audience Selection */}
                    <div className="space-y-3">
                        <label className="text-[12px] font-bold text-text-primary uppercase tracking-wider flex items-center gap-2">
                            <Users className="w-4 h-4 text-primary" /> Target Audience
                        </label>
                        <div className="grid grid-cols-2 gap-3">
                            {[
                                { id: 'all', label: 'All Users', icon: BellRing },
                                { id: 'customers', label: 'Customers Only', icon: Users },
                                { id: 'owners', label: 'Owners Only', icon: UserSquare2 },
                                { id: 'lot', label: 'Specific Lot', icon: Car },
                            ].map(btn => (
                                <button
                                    key={btn.id}
                                    onClick={() => setAudience(btn.id)}
                                    className={`flex items-center gap-2.5 p-3 rounded-xl border text-sm font-bold transition-all ${audience === btn.id ? 'bg-primary/5 border-primary text-primary shadow-sm' : 'bg-bg-light border-border text-text-secondary hover:bg-surface-hover hover:text-text-primary'}`}
                                >
                                    <btn.icon className={`w-4 h-4 ${audience === btn.id ? 'text-primary' : 'text-text-tertiary'}`} />
                                    {btn.label}
                                </button>
                            ))}
                        </div>
                    </div>

                    {/* Content Fields */}
                    <div className="space-y-4">
                        <div className="space-y-2">
                            <label className="text-[12px] font-bold text-text-primary uppercase tracking-wider flex items-center gap-2">
                                <Type className="w-4 h-4 text-primary" /> Notification Title
                            </label>
                            <input
                                type="text"
                                value={title}
                                onChange={(e) => setTitle(e.target.value)}
                                placeholder="E.g., System Maintenance Scheduled"
                                className="w-full px-4 py-3 bg-bg-light border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-primary focus:ring-4 focus:ring-primary/10 transition-all"
                            />
                        </div>
                        <div className="space-y-2">
                            <label className="text-[12px] font-bold text-text-primary uppercase tracking-wider flex items-center gap-2">
                                <LayoutTemplate className="w-4 h-4 text-primary" /> Message Body
                            </label>
                            <textarea
                                value={message}
                                onChange={(e) => setMessage(e.target.value)}
                                placeholder="Enter the detailed notification text here..."
                                className="w-full h-32 p-4 bg-bg-light border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-primary focus:ring-4 focus:ring-primary/10 transition-all resize-none"
                            ></textarea>
                            <div className="flex justify-between items-center px-1">
                                <span className="text-[11px] font-semibold text-text-tertiary">{message.length}/200 characters</span>
                            </div>
                        </div>
                    </div>

                    <div className="pt-4 mt-auto">
                        <Button className="w-full h-12 text-[15px]" icon={Send} onClick={handleSend} disabled={loading}>
                            {loading ? 'Sending...' : 'Send Broadcast'}
                        </Button>
                    </div>
                </Card>

                {/* Device Preview & History */}
                <div className="space-y-6">
                    {/* Device Preview */}
                    <Card className="bg-gradient-to-br from-sidebar-bg to-[#121A33] border-none text-white relative h-64 overflow-hidden flex flex-col items-center justify-center p-8">
                        <div className="absolute inset-0 opacity-10 bg-[url('https://www.transparenttextures.com/patterns/carbon-fibre.png')]"></div>
                        <p className="text-[11px] font-bold text-white/50 uppercase tracking-widest mb-6 relative z-10 w-full max-w-[300px]">iOS device preview</p>
                        <div className="w-full max-w-[300px] bg-white/10 backdrop-blur-md border border-white/20 rounded-2xl p-4 shadow-2xl relative z-10 transform translate-y-2 transition-all hover:-translate-y-1 hover:shadow-[0_20px_40px_-10px_rgba(0,0,0,0.5)]">
                            <div className="flex items-center gap-3 mb-2">
                                <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
                                    <span className="text-white font-bold text-[10px] tracking-tighter leading-none">TX</span>
                                </div>
                                <div>
                                    <p className="text-xs font-bold text-white/90">TechXPark</p>
                                    <p className="text-[10px] font-medium text-white/50">Just now</p>
                                </div>
                            </div>
                            <h4 className="text-[14px] font-bold text-white mb-1 tracking-tight leading-snug">{title || 'Notification Title'}</h4>
                            <p className="text-[12px] font-medium text-white/80 leading-relaxed line-clamp-3">
                                {message || 'The notification body text will appear here.'}
                            </p>
                        </div>
                    </Card>

                    {/* Real History Log */}
                    <Card padding="p-0">
                        <div className="px-5 py-4 border-b border-border bg-surface-hover/50">
                            <h3 className="text-sm font-bold text-text-primary">Recent Broadcasts</h3>
                        </div>
                        <div className="divide-y divide-border max-h-[400px] overflow-y-auto">
                            {historyLoading ? (
                                <div className="p-8 flex justify-center">
                                    <Loader2 className="w-5 h-5 text-text-tertiary animate-spin" />
                                </div>
                            ) : history.length === 0 ? (
                                <div className="p-8 text-center">
                                    <p className="text-sm text-text-tertiary">No broadcasts sent yet</p>
                                </div>
                            ) : (
                                history.map(n => (
                                    <div key={n.id} className="p-4 flex flex-col gap-1 hover:bg-bg-light transition-colors">
                                        <div className="flex items-center justify-between">
                                            <h4 className="text-[13px] font-bold text-text-primary">{n.title}</h4>
                                            <span className="text-[10px] font-bold text-text-tertiary">
                                                {n.createdAt ? formatTimeAgo(n.createdAt) : 'just now'}
                                            </span>
                                        </div>
                                        <p className="text-[12px] font-medium text-text-secondary truncate">{n.body}</p>
                                        <div className="flex items-center gap-1.5 mt-2">
                                            <span className="text-[10px] font-bold text-primary bg-primary/10 px-2 py-0.5 rounded-md">
                                                {audienceLabels[n.audience] || n.audience || 'All Users'}
                                            </span>
                                            {n.sentCount > 0 && (
                                                <span className="text-[10px] font-bold text-success bg-success/10 px-2 py-0.5 rounded-md flex items-center gap-1">
                                                    <CheckCircle2 className="w-3 h-3" /> {n.sentCount} sent
                                                </span>
                                            )}
                                        </div>
                                    </div>
                                ))
                            )}
                        </div>
                    </Card>
                </div>
            </div>
        </div>
    );
}
