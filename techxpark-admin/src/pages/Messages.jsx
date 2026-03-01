import React, { useState, useEffect, useRef, useMemo } from 'react';
import { db, auth } from '../firebase';
import {
    collection,
    query,
    where,
    getDocs,
    onSnapshot,
    orderBy
} from 'firebase/firestore';
import {
    listenToConversations,
    listenToMessages,
    sendMessage,
    markAsRead,
    getConversationId
} from '../services/messageService';
import {
    Send,
    Search,
    Plus,
    MessageSquare,
    Users,
    Building2,
    ChevronLeft,
    Check,
    CheckCheck
} from 'lucide-react';
import { format } from 'date-fns';
import Avatar from '../components/ui/Avatar';
import Card from '../components/ui/Card';
import Badge from '../components/ui/Badge';
import Button from '../components/ui/Button';
import toast from 'react-hot-toast';
import { useAuth } from '../hooks/useAuth';

export default function Messages() {
    // ─── Tab State ─────────────────────────────────────────────────
    const [activeTab, setActiveTab] = useState('owners'); // 'owners' | 'users' | 'all'

    // ─── Chat State ────────────────────────────────────────────────
    const [conversations, setConversations] = useState([]);
    const [selectedConv, setSelectedConv] = useState(null);
    const [messages, setMessages] = useState([]);
    const [loading, setLoading] = useState(true);
    const [textInput, setTextInput] = useState('');
    const [sending, setSending] = useState(false);

    // ─── People Lists ──────────────────────────────────────────────
    const [owners, setOwners] = useState([]);
    const [customers, setCustomers] = useState([]);
    const [loadingPeople, setLoadingPeople] = useState(false);
    const [peopleSearch, setPeopleSearch] = useState('');

    const { user: authUser } = useAuth();
    const currentUser = authUser || auth.currentUser;
    const msgEndRef = useRef(null);

    // ───────────────────────────────────────────────────────────────
    // 1. Listen to Conversations (for "All" tab + unread counts)
    // ───────────────────────────────────────────────────────────────
    useEffect(() => {
        if (!currentUser) return;
        const unsubscribe = listenToConversations(currentUser.uid, (data) => {
            setConversations(data);
            setLoading(false);
        });
        return () => unsubscribe();
    }, [currentUser]);

    // ───────────────────────────────────────────────────────────────
    // 2. Listen to Messages when conversation selected
    // ───────────────────────────────────────────────────────────────
    useEffect(() => {
        if (!selectedConv || !currentUser) {
            setMessages([]);
            return;
        }

        markAsRead(selectedConv.id, currentUser.uid);

        const unsubscribe = listenToMessages(selectedConv.id, (data) => {
            setMessages(data);
            markAsRead(selectedConv.id, currentUser.uid);
            setTimeout(() => {
                msgEndRef.current?.scrollIntoView({ behavior: 'smooth' });
            }, 100);
        });

        return () => unsubscribe();
    }, [selectedConv, currentUser]);

    // ───────────────────────────────────────────────────────────────
    // 3. Load Owners + Users on tab change
    // ───────────────────────────────────────────────────────────────
    useEffect(() => {
        if (activeTab === 'owners' && owners.length === 0) loadPeopleByRole('owner');
        if (activeTab === 'users' && customers.length === 0) loadPeopleByRole('customer');
    }, [activeTab]);

    const loadPeopleByRole = async (role) => {
        setLoadingPeople(true);
        try {
            const snap = await getDocs(query(collection(db, 'users'), where('role', '==', role)));
            const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
            if (role === 'owner') setOwners(list);
            else setCustomers(list);
        } catch (err) {
            console.error(`Failed to load ${role}s:`, err);
            toast.error(`Failed to load ${role}s`);
        } finally {
            setLoadingPeople(false);
        }
    };

    // ───────────────────────────────────────────────────────────────
    // 4. Send Message
    // ───────────────────────────────────────────────────────────────
    const handleSend = async (e) => {
        e.preventDefault();
        if (!textInput.trim() || !selectedConv || !currentUser) return;

        const otherId = selectedConv.participants.find(p => p !== currentUser.uid);
        const otherName = selectedConv.participantNames?.[otherId] || 'User';
        const otherRole = selectedConv.participantRoles?.[otherId] || 'customer';

        try {
            setSending(true);
            await sendMessage({
                senderId: currentUser.uid,
                senderName: 'Super Admin',
                senderRole: 'admin',
                receiverId: otherId,
                receiverName: otherName,
                receiverRole: otherRole,
                text: textInput.trim()
            });
            setTextInput('');
        } catch (error) {
            console.error("Send error:", error);
            toast.error("Failed to send message");
        } finally {
            setSending(false);
        }
    };

    // ───────────────────────────────────────────────────────────────
    // 5. Start New Chat from People List
    // ───────────────────────────────────────────────────────────────
    const startNewChat = (otherUser) => {
        const convId = getConversationId(currentUser.uid, otherUser.id);
        const existing = conversations.find(c => c.id === convId);
        if (existing) {
            setSelectedConv(existing);
        } else {
            setSelectedConv({
                id: convId,
                participants: [currentUser.uid, otherUser.id],
                participantNames: {
                    [currentUser.uid]: 'Super Admin',
                    [otherUser.id]: otherUser.name || 'User'
                },
                participantRoles: {
                    [currentUser.uid]: 'admin',
                    [otherUser.id]: otherUser.role || 'customer'
                }
            });
        }
    };

    // ───────────────────────────────────────────────────────────────
    // 6. Filtering
    // ───────────────────────────────────────────────────────────────
    const filteredConversations = useMemo(() => {
        if (!currentUser) return [];
        return conversations.filter(c => {
            const otherId = c.participants.find(p => p !== currentUser?.uid);
            const otherName = c.participantNames?.[otherId] || '';
            return otherName.toLowerCase().includes(peopleSearch.toLowerCase());
        });
    }, [conversations, peopleSearch, currentUser]);

    const filteredOwners = useMemo(() => {
        const q = peopleSearch.toLowerCase();
        return owners.filter(o =>
            (o.name || '').toLowerCase().includes(q) ||
            (o.email || '').toLowerCase().includes(q)
        );
    }, [owners, peopleSearch]);

    const filteredCustomers = useMemo(() => {
        const q = peopleSearch.toLowerCase();
        return customers.filter(c =>
            (c.name || '').toLowerCase().includes(q) ||
            (c.email || '').toLowerCase().includes(q)
        );
    }, [customers, peopleSearch]);

    // Get unread count for a user
    const getUnreadForUser = (userId) => {
        const conv = conversations.find(c => c.participants?.includes(userId));
        return conv?.unreadCount?.[currentUser?.uid] || 0;
    };

    // ───────────────────────────────────────────────────────────────
    // RENDER
    // ───────────────────────────────────────────────────────────────
    const tabs = [
        { id: 'owners', label: 'Owners', icon: Building2 },
        { id: 'users', label: 'Users', icon: Users },
        { id: 'all', label: 'All Chats', icon: MessageSquare },
    ];

    return (
        <div className="flex h-[calc(100vh-140px)] bg-surface rounded-3xl border border-border overflow-hidden shadow-sm">
            {/* ── Left Panel: People / Conversations ── */}
            <div className={`w-full md:w-80 border-r border-border flex flex-col bg-bg-light/30 ${selectedConv ? 'hidden md:flex' : 'flex'}`}>
                {/* Tab Bar */}
                <div className="p-3 border-b border-border bg-surface">
                    <div className="flex bg-bg-light rounded-xl p-1 border border-border mb-3">
                        {tabs.map(tab => {
                            const Icon = tab.icon;
                            return (
                                <button
                                    key={tab.id}
                                    onClick={() => { setActiveTab(tab.id); setPeopleSearch(''); }}
                                    className={`flex-1 flex items-center justify-center gap-1.5 px-2 py-1.5 rounded-lg text-xs font-bold transition-all ${activeTab === tab.id
                                            ? 'bg-primary text-white shadow-sm'
                                            : 'text-text-secondary hover:text-text-primary'
                                        }`}
                                >
                                    <Icon className="w-3.5 h-3.5" />
                                    {tab.label}
                                </button>
                            );
                        })}
                    </div>

                    {/* Search */}
                    <div className="relative">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-tertiary" />
                        <input
                            type="text"
                            placeholder={`Search ${activeTab === 'all' ? 'chats' : activeTab}...`}
                            value={peopleSearch}
                            onChange={(e) => setPeopleSearch(e.target.value)}
                            className="w-full pl-10 pr-4 py-2 bg-bg-light rounded-xl border-none text-sm font-medium focus:ring-2 focus:ring-primary/20 outline-none"
                        />
                    </div>
                </div>

                {/* List Content */}
                <div className="flex-1 overflow-y-auto">
                    {/* ── OWNERS TAB ── */}
                    {activeTab === 'owners' && (
                        loadingPeople ? (
                            <div className="flex items-center justify-center h-40">
                                <span className="w-6 h-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
                            </div>
                        ) : filteredOwners.length === 0 ? (
                            <div className="p-8 text-center">
                                <Building2 className="w-12 h-12 text-text-tertiary mx-auto mb-3 opacity-20" />
                                <p className="text-sm font-bold text-text-secondary">No owners found</p>
                            </div>
                        ) : (
                            <div className="divide-y divide-border/50">
                                {filteredOwners.map(owner => {
                                    const unread = getUnreadForUser(owner.id);
                                    return (
                                        <button
                                            key={owner.id}
                                            onClick={() => startNewChat(owner)}
                                            className="w-full p-4 flex gap-3 hover:bg-surface transition-colors text-left"
                                        >
                                            <Avatar name={owner.name || owner.email || 'Owner'} size="md" />
                                            <div className="flex-1 min-w-0">
                                                <div className="flex justify-between items-start">
                                                    <h3 className="font-bold text-text-primary text-sm truncate">{owner.name || 'Unnamed'}</h3>
                                                    {unread > 0 && (
                                                        <span className="bg-error text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full min-w-[18px] text-center">{unread}</span>
                                                    )}
                                                </div>
                                                <p className="text-xs text-text-tertiary truncate mt-0.5">{owner.email}</p>
                                                <div className="flex items-center gap-2 mt-1.5">
                                                    <Badge variant="warning" className="text-[9px] px-1.5 py-0">owner</Badge>
                                                    {owner.accessStatus && (
                                                        <span className={`text-[9px] font-bold px-1.5 py-0.5 rounded-full ${owner.accessStatus === 'approved' ? 'bg-emerald-50 text-emerald-700' : 'bg-amber-50 text-amber-700'
                                                            }`}>
                                                            {owner.accessStatus}
                                                        </span>
                                                    )}
                                                </div>
                                            </div>
                                        </button>
                                    );
                                })}
                            </div>
                        )
                    )}

                    {/* ── USERS TAB ── */}
                    {activeTab === 'users' && (
                        loadingPeople ? (
                            <div className="flex items-center justify-center h-40">
                                <span className="w-6 h-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
                            </div>
                        ) : filteredCustomers.length === 0 ? (
                            <div className="p-8 text-center">
                                <Users className="w-12 h-12 text-text-tertiary mx-auto mb-3 opacity-20" />
                                <p className="text-sm font-bold text-text-secondary">No users found</p>
                            </div>
                        ) : (
                            <div className="divide-y divide-border/50">
                                {filteredCustomers.map(customer => {
                                    const unread = getUnreadForUser(customer.id);
                                    return (
                                        <button
                                            key={customer.id}
                                            onClick={() => startNewChat(customer)}
                                            className="w-full p-4 flex gap-3 hover:bg-surface transition-colors text-left"
                                        >
                                            <Avatar name={customer.name || customer.email || 'User'} size="md" />
                                            <div className="flex-1 min-w-0">
                                                <div className="flex justify-between items-start">
                                                    <h3 className="font-bold text-text-primary text-sm truncate">{customer.name || 'Unnamed'}</h3>
                                                    {unread > 0 && (
                                                        <span className="bg-error text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full min-w-[18px] text-center">{unread}</span>
                                                    )}
                                                </div>
                                                <p className="text-xs text-text-tertiary truncate mt-0.5">{customer.email}</p>
                                                <Badge variant="info" className="mt-1.5 text-[9px] px-1.5 py-0">customer</Badge>
                                            </div>
                                        </button>
                                    );
                                })}
                            </div>
                        )
                    )}

                    {/* ── ALL CONVERSATIONS TAB ── */}
                    {activeTab === 'all' && (
                        filteredConversations.length === 0 ? (
                            <div className="p-8 text-center">
                                <MessageSquare className="w-12 h-12 text-text-tertiary mx-auto mb-3 opacity-20" />
                                <p className="text-sm font-bold text-text-secondary">No conversations yet</p>
                                <p className="text-xs font-medium text-text-tertiary mt-1">Start a new chat from the Owners or Users tab</p>
                            </div>
                        ) : (
                            <div className="divide-y divide-border/50">
                                {filteredConversations.map((conv) => {
                                    const otherId = conv.participants.find(p => p !== currentUser?.uid);
                                    const name = conv.participantNames?.[otherId] || 'User';
                                    const role = conv.participantRoles?.[otherId] || 'customer';
                                    const unreadCount = conv.unreadCount?.[currentUser?.uid] || 0;
                                    const isSelected = selectedConv?.id === conv.id;
                                    const roleIcon = role === 'owner' ? '🅿️' : role === 'admin' ? '🛡️' : '👤';

                                    return (
                                        <button
                                            key={conv.id}
                                            onClick={() => setSelectedConv(conv)}
                                            className={`w-full p-4 flex gap-3 hover:bg-surface transition-colors text-left ${isSelected ? 'bg-primary/5 border-l-4 border-primary' : 'border-l-4 border-transparent'}`}
                                        >
                                            <Avatar name={name} size="md" />
                                            <div className="flex-1 min-w-0">
                                                <div className="flex justify-between items-start">
                                                    <h3 className="font-bold text-text-primary text-sm truncate">{roleIcon} {name}</h3>
                                                    {conv.lastMessageTime && (
                                                        <span className="text-[10px] font-bold text-text-tertiary uppercase">
                                                            {format(conv.lastMessageTime.toDate(), 'h:mm a')}
                                                        </span>
                                                    )}
                                                </div>
                                                <div className="flex justify-between items-center mt-0.5">
                                                    <p className={`text-xs truncate ${unreadCount > 0 ? 'text-text-primary font-bold' : 'text-text-tertiary font-medium'}`}>
                                                        {conv.lastMessage || 'No messages yet'}
                                                    </p>
                                                    {unreadCount > 0 && (
                                                        <span className="bg-error text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full min-w-[18px] text-center">
                                                            {unreadCount}
                                                        </span>
                                                    )}
                                                </div>
                                                <Badge variant={role === 'owner' ? 'warning' : 'info'} className="mt-2 text-[9px] px-1.5 py-0">
                                                    {role}
                                                </Badge>
                                            </div>
                                        </button>
                                    );
                                })}
                            </div>
                        )
                    )}
                </div>
            </div>

            {/* ── Right Panel: Chat Area ── */}
            <div className={`flex-1 flex flex-col bg-surface ${!selectedConv && 'hidden md:flex'}`}>
                {selectedConv ? (
                    <>
                        {/* Chat Header */}
                        <div className="p-4 border-b border-border flex items-center justify-between bg-surface/80 backdrop-blur-md z-10 sticky top-0">
                            <div className="flex items-center gap-3">
                                <button
                                    onClick={() => setSelectedConv(null)}
                                    className="md:hidden p-2 hover:bg-bg-light rounded-xl transition-colors"
                                >
                                    <ChevronLeft className="w-5 h-5 text-text-secondary" />
                                </button>
                                {(() => {
                                    const otherId = selectedConv.participants.find(p => p !== currentUser?.uid);
                                    const name = selectedConv.participantNames?.[otherId] || 'User';
                                    const role = selectedConv.participantRoles?.[otherId] || 'customer';
                                    const roleLabel = role === 'owner' ? '🅿️ Lot Owner' : role === 'admin' ? '🛡️ Admin' : '👤 Customer';
                                    return (
                                        <>
                                            <Avatar name={name} size="md" />
                                            <div>
                                                <h3 className="font-bold text-text-primary text-base leading-none">{name}</h3>
                                                <p className="text-[11px] font-bold text-text-tertiary uppercase tracking-wider mt-1.5 flex items-center gap-1">
                                                    <span className="w-1.5 h-1.5 rounded-full bg-success"></span>
                                                    {roleLabel}
                                                </p>
                                            </div>
                                        </>
                                    );
                                })()}
                            </div>
                        </div>

                        {/* Messages Area */}
                        <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-bg-light/30">
                            {messages.length === 0 ? (
                                <div className="h-full flex flex-col items-center justify-center opacity-40">
                                    <div className="w-16 h-16 bg-bg-light rounded-full flex items-center justify-center mb-4">
                                        <MessageSquare className="w-8 h-8 text-primary" />
                                    </div>
                                    <p className="text-sm font-bold text-text-secondary text-center max-w-[200px]">Send a message to start the conversation</p>
                                </div>
                            ) : (
                                messages.map((msg) => {
                                    const isMe = msg.senderId === currentUser?.uid;
                                    return (
                                        <div key={msg.id} className={`flex flex-col ${isMe ? 'items-end' : 'items-start'}`}>
                                            <div className={`max-w-[80%] rounded-2xl px-4 py-2.5 text-sm shadow-sm ${isMe ? 'bg-primary text-white rounded-tr-none' : 'bg-surface border border-border text-text-primary rounded-tl-none'
                                                }`}>
                                                {msg.text}
                                            </div>
                                            <div className="flex items-center gap-1.5 mt-1 px-1">
                                                <span className="text-[10px] font-bold text-text-tertiary uppercase">
                                                    {msg.timestamp ? format(msg.timestamp.toDate(), 'h:mm a') : '...'}
                                                </span>
                                                {isMe && (
                                                    msg.read ? <CheckCheck className="w-3 h-3 text-primary" /> : <Check className="w-3 h-3 text-text-tertiary" />
                                                )}
                                            </div>
                                        </div>
                                    );
                                })
                            )}
                            <div ref={msgEndRef} />
                        </div>

                        {/* Input Area */}
                        <form onSubmit={handleSend} className="p-4 border-t border-border bg-surface">
                            <div className="flex gap-2">
                                <input
                                    type="text"
                                    placeholder="Type a message..."
                                    value={textInput}
                                    onChange={(e) => setTextInput(e.target.value)}
                                    className="flex-1 bg-bg-light border-none rounded-xl px-4 py-3 text-sm font-medium focus:ring-2 focus:ring-primary/20 outline-none"
                                />
                                <button
                                    type="submit"
                                    disabled={!textInput.trim() || sending}
                                    className="p-3 bg-primary text-white rounded-xl hover:bg-indigo-700 transition-all shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
                                >
                                    {sending ? (
                                        <span className="w-5 h-5 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                                    ) : (
                                        <Send className="w-5 h-5" />
                                    )}
                                </button>
                            </div>
                        </form>
                    </>
                ) : (
                    <div className="flex-1 flex flex-col items-center justify-center p-8 text-center opacity-40 bg-bg-light/10">
                        <div className="w-20 h-20 bg-surface border border-border rounded-full flex items-center justify-center mb-6">
                            <MessageSquare className="w-10 h-10 text-primary" />
                        </div>
                        <h2 className="text-2xl font-bold text-text-primary">Select a conversation</h2>
                        <p className="text-sm font-medium text-text-secondary mt-2 max-w-sm">Choose an owner or customer from the left panel to start chatting.</p>
                    </div>
                )}
            </div>
        </div>
    );
}
