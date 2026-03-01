import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Search, MessageSquare, Send, Plus, Users, Shield, ChevronLeft } from 'lucide-react';
import { collection, getDocs, query, where, doc, getDoc } from 'firebase/firestore';
import { format } from 'date-fns';
import toast from 'react-hot-toast';
import { db } from '../firebase';
import { useAuth } from '../context/AuthContext';
import Avatar from '../components/ui/Avatar';
import {
    sendMessage,
    markAsRead,
    listenToConversations,
    listenToMessages
} from '../services/messageService';

// ─── Quick Reply Templates ─────────────────────────────────────────
const ownerTemplates = [
    '🚗 Please move your vehicle',
    '⚠️ Your session expires in 10 mins',
    '✅ Your slot is ready',
    '🔧 Slot maintenance - please relocate',
    '💰 Payment reminder',
    '👋 How was your parking experience?',
];

export default function Messages() {
    const { user, userData } = useAuth();

    // ─── Tab State ─────────────────────────────────────────────────
    const [activeTab, setActiveTab] = useState('conversations'); // 'conversations' | 'customers'

    // ─── Conversations State (Tab 1) ───────────────────────────────
    const [conversations, setConversations] = useState([]);
    const [selectedConversation, setSelectedConversation] = useState(null);
    const [messages, setMessages] = useState([]);
    const [searchTerm, setSearchTerm] = useState('');
    const [msgInput, setMsgInput] = useState('');
    const [sending, setSending] = useState(false);
    const [newChatOpen, setNewChatOpen] = useState(false);
    const [userSearch, setUserSearch] = useState('');
    const [chatUsers, setChatUsers] = useState([]);
    const bottomRef = useRef(null);

    // ─── Customers State (Tab 2) ───────────────────────────────────
    const [customers, setCustomers] = useState([]);
    const [loadingCustomers, setLoadingCustomers] = useState(false);
    const [customerSearch, setCustomerSearch] = useState('');
    const [customerFilter, setCustomerFilter] = useState('all'); // 'all' | 'active' | 'recent'

    // ───────────────────────────────────────────────────────────────
    // CONVERSATIONS TAB LOGIC (existing)
    // ───────────────────────────────────────────────────────────────
    useEffect(() => {
        if (!user?.uid) return undefined;
        const unsubscribe = listenToConversations(user.uid, (convs) => {
            setConversations(convs);
            if (!selectedConversation && convs.length > 0) {
                setSelectedConversation(convs[0]);
            }
        });
        return () => unsubscribe();
    }, [user?.uid]);

    useEffect(() => {
        if (!selectedConversation?.id || !user?.uid) {
            setMessages([]);
            return undefined;
        }

        markAsRead(selectedConversation.id, user.uid).catch((error) => {
            console.error('markAsRead failed:', error);
        });

        const unsubscribe = listenToMessages(selectedConversation.id, (nextMessages) => {
            setMessages(nextMessages);
            markAsRead(selectedConversation.id, user.uid).catch((error) => {
                console.error('markAsRead failed:', error);
            });
            setTimeout(() => bottomRef.current?.scrollIntoView({ behavior: 'smooth' }), 80);
        });

        return () => unsubscribe();
    }, [selectedConversation?.id, user?.uid]);

    useEffect(() => {
        if (!newChatOpen) return;
        const fetchUsers = async () => {
            try {
                const [adminsSnap, customersSnap] = await Promise.all([
                    getDocs(query(collection(db, 'users'), where('role', '==', 'admin'))),
                    getDocs(query(collection(db, 'users'), where('role', '==', 'customer')))
                ]);
                const usersData = [...adminsSnap.docs, ...customersSnap.docs].map((docSnap) => ({
                    uid: docSnap.id,
                    ...docSnap.data()
                }));
                setChatUsers(usersData);
            } catch (error) {
                console.error('Failed to load users for chat:', error);
                toast.error('Failed to load users');
            }
        };
        fetchUsers();
    }, [newChatOpen]);

    // ───────────────────────────────────────────────────────────────
    // CUSTOMERS TAB LOGIC (new)
    // ───────────────────────────────────────────────────────────────
    useEffect(() => {
        if (activeTab !== 'customers' || !userData?.assignedLotId) return;
        loadCustomers();
    }, [activeTab, userData?.assignedLotId]);

    const loadCustomers = async () => {
        if (!userData?.assignedLotId) return;
        setLoadingCustomers(true);
        try {
            // 1. Fetch all bookings for this lot
            const bookingsSnap = await getDocs(
                query(collection(db, 'bookings'), where('parkingId', '==', userData.assignedLotId))
            );

            // 2. Get unique userIds
            const userIds = [...new Set(bookingsSnap.docs.map(d => d.data().userId))];

            // 3. Fetch each user's details + latest booking
            const customerData = await Promise.all(
                userIds.map(async (userId) => {
                    try {
                        const userDoc = await getDoc(doc(db, 'users', userId));
                        if (!userDoc.exists()) return null;

                        // Find latest booking for this user
                        const userBookings = bookingsSnap.docs
                            .filter(d => d.data().userId === userId)
                            .sort((a, b) => (b.data().createdAt?.seconds || 0) - (a.data().createdAt?.seconds || 0));

                        const latestBooking = userBookings[0];
                        const latestData = latestBooking?.data() || {};

                        return {
                            id: userId,
                            ...userDoc.data(),
                            totalBookings: userBookings.length,
                            latestBooking: {
                                id: latestBooking?.id,
                                slotId: latestData.slotId || '--',
                                status: latestData.status || 'unknown',
                                startTime: latestData.startTime,
                                endTime: latestData.endTime,
                                createdAt: latestData.createdAt,
                            }
                        };
                    } catch (err) {
                        console.error(`Failed to fetch user ${userId}:`, err);
                        return null;
                    }
                })
            );

            setCustomers(customerData.filter(Boolean));
        } catch (error) {
            console.error('Failed to load customers:', error);
            toast.error('Failed to load customers');
        } finally {
            setLoadingCustomers(false);
        }
    };

    // ───────────────────────────────────────────────────────────────
    // HELPER FUNCTIONS
    // ───────────────────────────────────────────────────────────────
    const getOtherParticipant = (conv) => {
        const id = conv?.participants?.find((p) => p !== user?.uid) || '';
        return {
            id,
            name: conv?.participantNames?.[id] || 'Unknown',
            role: conv?.participantRoles?.[id] || 'customer'
        };
    };

    const filteredConversations = useMemo(() => {
        const q = searchTerm.toLowerCase();
        return conversations.filter((conv) =>
            getOtherParticipant(conv).name.toLowerCase().includes(q)
        );
    }, [conversations, searchTerm]);

    const filteredUsers = useMemo(() => {
        const q = userSearch.toLowerCase();
        return chatUsers.filter((u) =>
            u.uid !== user?.uid &&
            (u.name || u.email || '').toLowerCase().includes(q)
        );
    }, [chatUsers, userSearch, user?.uid]);

    const filteredCustomers = useMemo(() => {
        let list = customers;

        // Filter by search
        if (customerSearch.trim()) {
            const q = customerSearch.toLowerCase();
            list = list.filter(c =>
                (c.name || '').toLowerCase().includes(q) ||
                (c.email || '').toLowerCase().includes(q)
            );
        }

        // Filter by status
        if (customerFilter === 'active') {
            list = list.filter(c => c.latestBooking?.status === 'active' || c.latestBooking?.status === 'upcoming');
        } else if (customerFilter === 'recent') {
            const weekAgo = Date.now() / 1000 - 7 * 86400;
            list = list.filter(c => (c.latestBooking?.createdAt?.seconds || 0) > weekAgo);
        }

        return list;
    }, [customers, customerSearch, customerFilter]);

    const openOrCreateConversation = (targetUser) => {
        const existing = conversations.find((conv) => conv.participants?.includes(targetUser.uid || targetUser.id));
        if (existing) {
            setSelectedConversation(existing);
        } else if (user?.uid) {
            setSelectedConversation({
                id: null,
                participants: [user.uid, targetUser.uid || targetUser.id],
                participantNames: {
                    [user.uid]: userData?.name || user.email || 'Owner',
                    [targetUser.uid || targetUser.id]: targetUser.name || targetUser.email || 'User'
                },
                participantRoles: {
                    [user.uid]: userData?.role || 'owner',
                    [targetUser.uid || targetUser.id]: targetUser.role || 'customer'
                },
                lotId: userData?.assignedLotId || null
            });
        }
        setNewChatOpen(false);
        setUserSearch('');
        setActiveTab('conversations');
    };

    const handleSend = async (e) => {
        if (e) e.preventDefault();
        if (!msgInput.trim() || !selectedConversation || !user?.uid || sending) return;

        const target = getOtherParticipant(selectedConversation);
        setSending(true);
        try {
            await sendMessage({
                senderId: user.uid,
                senderName: userData?.name || user.email || 'Owner',
                senderRole: userData?.role || 'owner',
                receiverId: target.id,
                receiverName: target.name,
                receiverRole: target.role,
                text: msgInput,
                lotId: userData?.assignedLotId || null
            });
            setMsgInput('');
        } catch (error) {
            console.error('Failed to send message:', error);
            toast.error('Failed to send message');
        } finally {
            setSending(false);
        }
    };

    const handleQuickReply = (template) => {
        setMsgInput(template);
    };

    const formatTimeAgo = (timestamp) => {
        if (!timestamp) return '';
        const seconds = timestamp.seconds || timestamp._seconds || 0;
        const diff = Math.floor(Date.now() / 1000 - seconds);
        if (diff < 60) return 'just now';
        if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
        if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
        if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
        return format(new Date(seconds * 1000), 'MMM d');
    };

    // ───────────────────────────────────────────────────────────────
    // RENDER
    // ───────────────────────────────────────────────────────────────
    return (
        <div className="flex flex-col h-[calc(100vh-64px-48px)] w-full max-w-[1200px] mx-auto animate-in fade-in duration-300">
            {/* Header + Tabs */}
            <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-4">
                    <h1 className="text-xl font-bold text-text-primary">Messages</h1>
                    <div className="flex bg-bg-light rounded-xl p-1 border border-border">
                        <button
                            onClick={() => setActiveTab('conversations')}
                            className={`px-4 py-1.5 rounded-lg text-sm font-bold transition-all ${activeTab === 'conversations'
                                    ? 'bg-primary text-white shadow-sm'
                                    : 'text-text-secondary hover:text-text-primary'
                                }`}
                        >
                            <MessageSquare className="w-3.5 h-3.5 inline mr-1.5" />
                            Chats
                        </button>
                        <button
                            onClick={() => setActiveTab('customers')}
                            className={`px-4 py-1.5 rounded-lg text-sm font-bold transition-all ${activeTab === 'customers'
                                    ? 'bg-primary text-white shadow-sm'
                                    : 'text-text-secondary hover:text-text-primary'
                                }`}
                        >
                            <Users className="w-3.5 h-3.5 inline mr-1.5" />
                            My Customers
                        </button>
                    </div>
                </div>
                {activeTab === 'conversations' && (
                    <button
                        onClick={() => setNewChatOpen((v) => !v)}
                        className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-primary text-white text-sm font-bold hover:bg-primary-dark transition-colors"
                    >
                        <Plus className="w-4 h-4" />
                        New Message
                    </button>
                )}
            </div>

            {/* ─── TAB 2: MY CUSTOMERS ─────────────────────────────────── */}
            {activeTab === 'customers' && (
                <div className="flex-1 overflow-hidden bg-white rounded-[14px] border border-border shadow-sm flex flex-col">
                    {/* Search + Filters */}
                    <div className="p-4 border-b border-border bg-surface shrink-0">
                        <div className="flex items-center gap-3">
                            <div className="relative flex-1">
                                <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-text-tertiary" />
                                <input
                                    type="text"
                                    placeholder="Search customers by name or email..."
                                    value={customerSearch}
                                    onChange={(e) => setCustomerSearch(e.target.value)}
                                    className="w-full pl-9 pr-4 py-2 bg-bg-light border border-border rounded-xl text-[13px] font-medium focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
                                />
                            </div>
                            <div className="flex bg-bg-light rounded-lg p-0.5 border border-border">
                                {['all', 'active', 'recent'].map(f => (
                                    <button
                                        key={f}
                                        onClick={() => setCustomerFilter(f)}
                                        className={`px-3 py-1 rounded-md text-xs font-bold capitalize transition-all ${customerFilter === f
                                                ? 'bg-white text-primary shadow-sm'
                                                : 'text-text-tertiary hover:text-text-primary'
                                            }`}
                                    >
                                        {f === 'active' ? 'Active Booking' : f === 'recent' ? 'Last 7 Days' : 'All'}
                                    </button>
                                ))}
                            </div>
                        </div>
                    </div>

                    {/* Customer List */}
                    <div className="flex-1 overflow-y-auto p-4">
                        {loadingCustomers ? (
                            <div className="flex items-center justify-center h-40">
                                <span className="w-6 h-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
                            </div>
                        ) : !userData?.assignedLotId ? (
                            <div className="text-center py-16 text-text-tertiary">
                                <Shield className="w-12 h-12 mx-auto mb-3 opacity-30" />
                                <p className="font-bold text-text-secondary">No lot assigned</p>
                                <p className="text-sm mt-1">You need an assigned parking lot to see customers</p>
                            </div>
                        ) : filteredCustomers.length === 0 ? (
                            <div className="text-center py-16 text-text-tertiary">
                                <Users className="w-12 h-12 mx-auto mb-3 opacity-30" />
                                <p className="font-bold text-text-secondary">No customers found</p>
                                <p className="text-sm mt-1">Customers who book your lot will appear here</p>
                            </div>
                        ) : (
                            <div className="grid gap-3">
                                {filteredCustomers.map((customer) => {
                                    const status = customer.latestBooking?.status || 'unknown';
                                    const statusColors = {
                                        active: 'bg-emerald-50 text-emerald-700 border-emerald-200',
                                        upcoming: 'bg-blue-50 text-blue-700 border-blue-200',
                                        completed: 'bg-gray-50 text-gray-600 border-gray-200',
                                        cancelled: 'bg-red-50 text-red-600 border-red-200',
                                    };

                                    return (
                                        <div
                                            key={customer.id}
                                            className="flex items-center gap-4 p-4 bg-white border border-border rounded-2xl hover:shadow-md hover:border-primary/20 transition-all"
                                        >
                                            <Avatar name={customer.name || customer.email || 'User'} size="md" />
                                            <div className="flex-1 min-w-0">
                                                <div className="flex items-center gap-2 mb-0.5">
                                                    <p className="font-bold text-text-primary text-[14px] truncate">
                                                        {customer.name || 'Unknown User'}
                                                    </p>
                                                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full border ${statusColors[status] || statusColors.completed}`}>
                                                        {status}
                                                    </span>
                                                </div>
                                                <p className="text-xs text-text-tertiary truncate">
                                                    {customer.email || ''}{customer.phone ? ` • ${customer.phone}` : ''}
                                                </p>
                                                <p className="text-[11px] text-text-secondary mt-1 font-medium">
                                                    Last booked: Slot {customer.latestBooking?.slotId} • {formatTimeAgo(customer.latestBooking?.createdAt)}{' '}
                                                    <span className="text-text-tertiary">({customer.totalBookings} total)</span>
                                                </p>
                                            </div>
                                            <button
                                                onClick={() => openOrCreateConversation(customer)}
                                                className="flex items-center gap-1.5 px-4 py-2 bg-primary text-white text-sm font-bold rounded-xl hover:bg-primary-dark transition-colors shrink-0"
                                            >
                                                <MessageSquare className="w-3.5 h-3.5" />
                                                Message
                                            </button>
                                        </div>
                                    );
                                })}
                            </div>
                        )}
                    </div>
                </div>
            )}

            {/* ─── TAB 1: CONVERSATIONS ────────────────────────────────── */}
            {activeTab === 'conversations' && (
                <div className="flex flex-1 overflow-hidden bg-white rounded-[14px] border border-border shadow-sm">
                    {/* Sidebar */}
                    <div className="w-[320px] bg-surface flex flex-col shrink-0 border-r border-border z-10">
                        <div className="p-4 border-b border-border bg-surface shrink-0">
                            <div className="relative">
                                <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-text-tertiary" />
                                <input
                                    type="text"
                                    placeholder="Search conversations..."
                                    value={searchTerm}
                                    onChange={(e) => setSearchTerm(e.target.value)}
                                    className="w-full pl-9 pr-4 py-1.5 bg-bg-light border border-border rounded-md text-[13px] font-medium focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary transition-all shadow-xs"
                                />
                            </div>
                        </div>

                        {newChatOpen && (
                            <div className="p-3 border-b border-border bg-white">
                                <input
                                    type="text"
                                    placeholder="Search users..."
                                    value={userSearch}
                                    onChange={(e) => setUserSearch(e.target.value)}
                                    className="w-full px-3 py-2 border border-border rounded-lg text-sm outline-none focus:ring-2 focus:ring-primary/10"
                                />
                                <div className="mt-2 max-h-44 overflow-y-auto space-y-1">
                                    {filteredUsers.slice(0, 15).map((u) => (
                                        <button
                                            key={u.uid}
                                            onClick={() => openOrCreateConversation(u)}
                                            className="w-full text-left p-2 rounded-lg hover:bg-bg-light flex items-center gap-2"
                                        >
                                            <Avatar name={u.name || u.email || 'User'} size="sm" />
                                            <div className="min-w-0">
                                                <p className="text-sm font-semibold text-text-primary truncate">{u.name || u.email}</p>
                                                <p className="text-xs text-text-tertiary">{u.role}</p>
                                            </div>
                                        </button>
                                    ))}
                                </div>
                            </div>
                        )}

                        <div className="flex-1 overflow-y-auto scrollbar-none bg-surface">
                            <div className="p-2 space-y-0.5">
                                {filteredConversations.map((conv) => {
                                    const other = getOtherParticipant(conv);
                                    const unread = conv.unreadCount?.[user?.uid] || 0;
                                    const isSelected = selectedConversation?.id === conv.id;
                                    const roleIcon = other.role === 'admin' ? '🛡️' : other.role === 'owner' ? '🅿️' : '👤';

                                    return (
                                        <button
                                            key={conv.id}
                                            onClick={() => setSelectedConversation(conv)}
                                            className={`w-full text-left p-2.5 rounded-lg flex items-center gap-3 transition-all duration-150 ${isSelected ? 'bg-primary text-white shadow-primary' : 'bg-transparent hover:bg-surface-hover text-text-primary'}`}
                                        >
                                            <Avatar name={other.name} size="sm" />
                                            <div className="flex-1 overflow-hidden">
                                                <div className="flex justify-between items-center mb-0.5">
                                                    <p className={`font-semibold truncate text-[14px] ${isSelected ? 'text-white' : 'text-text-primary'}`}>
                                                        {roleIcon} {other.name}
                                                    </p>
                                                    {unread > 0 && (
                                                        <span className="w-4 h-4 bg-error text-white text-[9px] font-bold rounded-full flex items-center justify-center">
                                                            {unread}
                                                        </span>
                                                    )}
                                                </div>
                                                <p className={`text-[11px] truncate ${isSelected ? 'text-white/80' : 'text-text-secondary'}`}>
                                                    {conv.lastMessage || 'New conversation'}
                                                </p>
                                            </div>
                                        </button>
                                    );
                                })}

                                {filteredConversations.length === 0 && (
                                    <div className="p-6 text-center mt-4">
                                        <div className="w-10 h-10 bg-bg-light border border-border rounded-full flex items-center justify-center mx-auto mb-3">
                                            <MessageSquare className="w-5 h-5 text-text-tertiary" />
                                        </div>
                                        <p className="text-[13px] font-bold text-text-secondary">No conversations</p>
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>

                    {/* Chat Area */}
                    <div className="flex-1 bg-[#FAFAFA] flex flex-col relative overflow-hidden">
                        {!selectedConversation ? (
                            <div className="flex flex-1 flex-col items-center justify-center text-text-tertiary">
                                <div className="w-16 h-16 bg-bg-light rounded-full flex items-center justify-center mb-4 border border-border">
                                    <MessageSquare className="w-8 h-8 text-text-tertiary opacity-50" />
                                </div>
                                <h3 className="text-lg font-bold text-text-primary">Select a conversation</h3>
                                <p className="text-sm text-text-secondary mt-1">or search for someone to message</p>
                            </div>
                        ) : (
                            <>
                                {/* Chat Header */}
                                <div className="h-[68px] border-b border-border flex items-center px-6 shrink-0 bg-white z-10">
                                    <div className="flex justify-between items-center w-full">
                                        <div className="flex items-center gap-3">
                                            <Avatar name={getOtherParticipant(selectedConversation).name} size="md" />
                                            <div>
                                                <h2 className="font-bold text-[15px] text-text-primary tracking-tight">{getOtherParticipant(selectedConversation).name}</h2>
                                                <p className="text-[12px] font-semibold text-text-secondary mt-0.5">
                                                    {getOtherParticipant(selectedConversation).role === 'admin' ? '🛡️ Support' : getOtherParticipant(selectedConversation).role === 'owner' ? '🅿️ Owner' : '👤 Customer'}
                                                </p>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                {/* Messages */}
                                <div className="flex-1 overflow-y-auto px-6 py-6 space-y-5 z-10 scrollbar-none pb-[160px]">
                                    {messages.map((msg) => {
                                        const isMe = msg.senderId === user?.uid;
                                        const msgTime = msg.timestamp?.toDate();
                                        return (
                                            <div key={msg.id} className={`flex flex-col ${isMe ? 'items-end' : 'items-start'}`}>
                                                <div className={`max-w-[75%] group flex flex-col ${isMe ? 'items-end' : 'items-start'}`}>
                                                    <div className={`px-4 py-2.5 text-[14px] leading-relaxed shadow-sm ${isMe ? 'bg-primary text-white rounded-[14px] rounded-tr-[4px]' : 'bg-white border border-border text-text-primary rounded-[14px] rounded-tl-[4px]'}`}>
                                                        {msg.text}
                                                    </div>
                                                    <span className={`text-[10px] uppercase font-bold tracking-[0.8px] mt-1.5 flex items-center gap-1 ${isMe ? 'mr-1 text-text-tertiary' : 'ml-1 text-text-tertiary'}`}>
                                                        {msgTime ? format(msgTime, 'h:mm a') : 'Sending...'}
                                                        {isMe && (
                                                            <span className={msg.read ? 'text-primary' : 'text-text-tertiary'}>
                                                                {msg.read ? '✓✓' : '✓'}
                                                            </span>
                                                        )}
                                                    </span>
                                                </div>
                                            </div>
                                        );
                                    })}
                                    {messages.length === 0 && (
                                        <div className="h-full flex flex-col items-center justify-center text-text-tertiary mt-20">
                                            <p className="text-[13px] font-semibold text-text-secondary mb-1">No messages yet</p>
                                            <p className="text-[12px]">Send a message to start the conversation.</p>
                                        </div>
                                    )}
                                    <div ref={bottomRef} className="h-4" />
                                </div>

                                {/* Quick Reply Templates + Input */}
                                <div className="absolute bottom-6 left-6 right-6 z-20 flex flex-col items-center gap-2">
                                    {/* Templates Row */}
                                    <div className="w-full max-w-[800px] flex gap-1.5 overflow-x-auto scrollbar-none pb-1">
                                        {ownerTemplates.map((t, i) => (
                                            <button
                                                key={i}
                                                onClick={() => handleQuickReply(t)}
                                                className="shrink-0 px-3 py-1.5 bg-white border border-border rounded-full text-[11px] font-semibold text-text-secondary hover:bg-primary/5 hover:text-primary hover:border-primary/30 transition-all whitespace-nowrap"
                                            >
                                                {t}
                                            </button>
                                        ))}
                                    </div>

                                    {/* Message Input */}
                                    <form
                                        onSubmit={handleSend}
                                        className="w-full max-w-[800px] bg-white border border-border rounded-full shadow-lg p-1.5 flex items-center gap-2 focus-within:ring-2 focus-within:ring-primary/20 focus-within:border-primary transition-all"
                                    >
                                        <input
                                            type="text"
                                            value={msgInput}
                                            onChange={(e) => setMsgInput(e.target.value)}
                                            placeholder="Type a message..."
                                            className="flex-1 px-4 py-2.5 bg-transparent outline-none text-[14px] font-medium text-text-primary placeholder:text-text-tertiary"
                                        />
                                        <button
                                            type="submit"
                                            disabled={!msgInput.trim() || sending}
                                            className="w-10 h-10 shrink-0 bg-primary hover:bg-primary-dark text-white rounded-full flex items-center justify-center transition-all disabled:opacity-50 disabled:scale-100 active:scale-95 shadow-sm"
                                        >
                                            {sending ? (
                                                <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                                            ) : (
                                                <Send className="w-4 h-4 ml-0.5" />
                                            )}
                                        </button>
                                    </form>
                                </div>
                            </>
                        )}
                    </div>
                </div>
            )}
        </div>
    );
}
