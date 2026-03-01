import React, { useEffect, useState } from 'react';
import { NavLink } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import Avatar from './ui/Avatar';
import { db } from '../firebase';
import { collection, query, where, onSnapshot } from 'firebase/firestore';
import {
    LayoutDashboard,
    Car,
    Wifi,
    UserSquare2,
    Users,
    CalendarCheck,
    Wallet,
    KeyRound,
    BellRing,
    MessageSquare,
    Settings,
    LogOut
} from 'lucide-react';

export default function Sidebar() {
    const { adminData, logout } = useAuth();
    const [pendingRequests, setPendingRequests] = useState(0);

    // Live listener for pending access requests
    useEffect(() => {
        const q = query(
            collection(db, 'access_requests'),
            where('status', '==', 'pending')
        );
        const unsubscribe = onSnapshot(q, (snapshot) => {
            setPendingRequests(snapshot.size);
        });
        return () => unsubscribe();
    }, []);

    const [unreadMessages, setUnreadMessages] = useState(0);

    // Live listener for unread messages
    useEffect(() => {
        if (!adminData || !adminData.uid) return;
        const q = query(
            collection(db, 'conversations'),
            where('participants', 'array-contains', adminData.uid)
        );
        const unsubscribe = onSnapshot(q, (snapshot) => {
            let totalUnread = 0;
            snapshot.forEach(doc => {
                const data = doc.data();
                if (data.unreadCount && data.unreadCount[adminData.uid]) {
                    totalUnread += data.unreadCount[adminData.uid];
                }
            });
            setUnreadMessages(totalUnread);
        });
        return () => unsubscribe();
    }, [adminData]);

    const navSections = [
        {
            title: "Overview",
            items: [
                { name: 'Dashboard', path: '/dashboard', icon: LayoutDashboard }
            ]
        },
        {
            title: "Parking",
            items: [
                { name: 'Parking Lots', path: '/lots', icon: Car },
                { name: 'Sensors', path: '/sensors', icon: Wifi }
            ]
        },
        {
            title: "People",
            items: [
                { name: 'Owners', path: '/owners', icon: UserSquare2 },
                { name: 'Users', path: '/users', icon: Users }
            ]
        },
        {
            title: "Operations",
            items: [
                { name: 'Bookings', path: '/bookings', icon: CalendarCheck },
                { name: 'Revenue', path: '/revenue', icon: Wallet }
            ]
        },
        {
            title: "System",
            items: [
                {
                    name: 'Access Requests',
                    path: '/admin/requests',
                    icon: KeyRound,
                    badge: pendingRequests > 0 ? pendingRequests : null
                },
                { name: 'Send Notifications', path: '/notifications', icon: BellRing },
                {
                    name: 'Messages',
                    path: '/messages',
                    icon: MessageSquare,
                    badge: unreadMessages > 0 ? unreadMessages : null
                },
                { name: 'Settings', path: '/settings', icon: Settings }
            ]
        }
    ];

    return (
        <aside className="w-[260px] h-screen bg-sidebar-bg border-r border-sidebar-border flex flex-col font-sans shrink-0 hidden md:flex transition-all duration-300">
            {/* Header */}
            <div className="p-6 pb-4">
                <div className="flex items-center gap-3 mb-6">
                    <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-primary to-indigo-600 flex items-center justify-center text-white font-bold text-xl shadow-primary">
                        P
                    </div>
                    <div>
                        <h1 className="text-xl font-bold tracking-tight text-white leading-none mb-1">
                            TechXPark<span className="text-primary-light">.</span>
                        </h1>
                        <div className="inline-flex items-center px-2 py-0.5 rounded-full bg-gradient-to-r from-primary to-purple-500 text-[9px] font-extrabold text-white uppercase tracking-wider">
                            Super Admin
                        </div>
                    </div>
                </div>
            </div>

            {/* Navigation */}
            <div className="flex-1 overflow-y-auto px-4 pb-6 scrollbar-none">
                {navSections.map((section, idx) => (
                    <div key={idx} className="mb-6">
                        <h3 className="text-[10px] font-bold text-sidebar-text/50 uppercase tracking-[1.2px] mb-3 px-2">
                            {section.title}
                        </h3>
                        <ul className="space-y-1">
                            {section.items.map((item) => (
                                <li key={item.name}>
                                    <NavLink
                                        to={item.path}
                                        className={({ isActive }) => `
                                            flex items-center justify-between px-3 py-2.5 rounded-xl text-[14px] font-semibold transition-all duration-200 group
                                            ${isActive
                                                ? 'bg-sidebar-active text-white shadow-[inset_2px_0_0_0_#2845D6]'
                                                : 'text-sidebar-text hover:bg-sidebar-hover hover:text-white'
                                            }
                                        `}
                                    >
                                        <div className="flex items-center gap-3">
                                            <item.icon className={`w-4 h-4 shrink-0 transition-colors ${location.pathname === item.path ? 'text-primary-light' : 'text-sidebar-text group-hover:text-white'}`} strokeWidth={2.5} />
                                            {item.name}
                                        </div>

                                        {item.badge !== undefined && item.badge !== null && (
                                            <span className={`flex items-center justify-center min-w-[20px] h-5 px-1.5 rounded-full text-[11px] font-bold text-white bg-error ${item.badge > 0 ? 'animate-pulse shadow-[0_0_10px_rgba(229,57,59,0.5)]' : ''}`}>
                                                {item.badge}
                                            </span>
                                        )}
                                    </NavLink>
                                </li>
                            ))}
                        </ul>
                    </div>
                ))}
            </div>

            {/* Footer Profile */}
            <div className="p-4 border-t border-sidebar-border">
                <div className="flex items-center gap-3 p-3 rounded-xl bg-sidebar-hover/50 border border-sidebar-border/50">
                    <div className="relative">
                        <Avatar name={adminData?.name || 'Super Admin'} size="sm" />
                        <span className="absolute bottom-0 right-0 w-2.5 h-2.5 bg-success border-2 border-sidebar-bg rounded-full"></span>
                    </div>
                    <div className="flex-1 min-w-0">
                        <p className="text-[13px] font-bold text-white truncate">{adminData?.name || 'Super Admin'}</p>
                        <p className="text-[11px] text-warning font-semibold truncate uppercase tracking-widest">Administrator</p>
                    </div>
                    <button
                        onClick={logout}
                        className="w-8 h-8 rounded-lg flex items-center justify-center text-sidebar-text hover:bg-error/10 hover:text-error transition-colors shrink-0"
                        title="Sign out"
                    >
                        <LogOut className="w-4 h-4" />
                    </button>
                </div>
            </div>
        </aside>
    );
}
