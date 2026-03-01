import { NavLink, useNavigate } from 'react-router-dom';
import AskAccessModal from './AskAccessModal';
import { useAuth } from '../context/AuthContext';
import { useLot } from '../hooks/useLot';
import { useState, useEffect } from 'react';
import { db } from '../firebase';
import { collection, query, where, onSnapshot } from 'firebase/firestore';
import {
    LayoutDashboard,
    Map,
    RadioTower,
    CalendarDays,
    MessageSquare,
    Settings as SettingsIcon,
    LogOut,
    MapPin,
    Settings,
    ShieldCheck
} from 'lucide-react';
import Avatar from './ui/Avatar';
import { useAllAccessRequests } from '../hooks/useAccessRequest';

const NAV_ITEMS = [
    { path: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
    { path: '/map', label: 'Live Map', icon: Map },
    { path: '/sensors', label: 'Sensor Manager', icon: RadioTower }
];

const MANAGEMENT_ITEMS = [
    { path: '/bookings', label: 'Bookings', icon: CalendarDays },
    { path: '/messages', label: 'Messages', icon: MessageSquare },
];

const ADMIN_ITEMS = [
    { path: '/admin/requests', label: 'Access Requests', icon: ShieldCheck }
];

const ACCOUNT_ITEMS = [
    { path: '/settings', label: 'Settings', icon: SettingsIcon },
];

export default function Sidebar() {
    const { ownerData, logout } = useAuth();
    const { lotData } = useLot(ownerData?.assignedLotId);
    const navigate = useNavigate();

    // Only fetch if admin
    const isAdmin = ownerData?.role === 'admin';
    const { requests } = useAllAccessRequests(isAdmin ? 'pending' : null);
    const pendingCount = requests?.length || 0;

    // Attach dynamic badge
    const adminItemsWithBadge = ADMIN_ITEMS.map(item =>
        item.path === '/admin/requests' && pendingCount > 0
            ? { ...item, badge: pendingCount }
            : item
    );

    const [unreadMessages, setUnreadMessages] = useState(0);
    const [showAskModal, setShowAskModal] = useState(false);

    useEffect(() => {
        if (!ownerData || !ownerData.uid) return;
        const q = query(
            collection(db, 'conversations'),
            where('participants', 'array-contains', ownerData.uid)
        );
        const unsubscribe = onSnapshot(q, (snapshot) => {
            let totalUnread = 0;
            snapshot.forEach(doc => {
                const data = doc.data();
                if (data.unreadCount && data.unreadCount[ownerData.uid]) {
                    totalUnread += data.unreadCount[ownerData.uid];
                }
            });
            setUnreadMessages(totalUnread);
        });
        return () => unsubscribe();
    }, [ownerData]);

    const managementItemsWithBadge = MANAGEMENT_ITEMS.map(item =>
        item.path === '/messages' && unreadMessages > 0
            ? { ...item, badge: unreadMessages }
            : item
    );

    const handleLogout = async () => {
        await logout();
        navigate('/login');
    };

    const renderNavSection = (items, label) => (
        <div className="mb-6">
            <div className="text-[11px] uppercase tracking-[1px] text-sidebar-text mb-2 px-3 font-semibold">
                {label}
            </div>
            <div className="space-y-1">
                {items.map((item) => (
                    <NavLink
                        key={item.path}
                        to={item.path}
                        className={({ isActive }) =>
                            `flex items-center gap-2 px-3 h-11 rounded-lg transition-all group relative ${isActive
                                ? 'bg-sidebar-active border-l-[3px] border-sidebar-active-border'
                                : 'hover:bg-sidebar-hover border-l-[3px] border-transparent'
                            }`
                        }
                    >
                        {({ isActive }) => (
                            <>
                                <div className={`w-9 h-9 rounded-md flex items-center justify-center shrink-0 transition-colors ${isActive ? 'bg-primary text-white' : 'group-hover:bg-white/5 text-sidebar-text group-hover:text-white'
                                    }`}>
                                    <item.icon className="w-5 h-5" strokeWidth={2} />
                                </div>
                                <span className={`flex-1 text-sm font-medium ${isActive ? 'text-white' : 'text-sidebar-text group-hover:text-white'}`}>
                                    {item.label}
                                </span>
                                {item.badge && (
                                    <span className="absolute right-3 bg-error text-white text-[11px] font-bold h-5 min-w-[20px] px-1.5 flex items-center justify-center rounded-full">
                                        {item.badge}
                                    </span>
                                )}
                            </>
                        )}
                    </NavLink>
                ))}
            </div>
        </div>
    );

    return (
        <div className="w-64 bg-sidebar-bg flex flex-col h-full border-r border-sidebar-border shrink-0">
            {/* Top Section */}
            <div className="p-4 shrink-0 flex flex-col gap-4">
                {/* Logo Area */}
                <div className="flex items-center gap-3 px-2">
                    <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center text-white font-bold text-lg shadow-sm">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                            <path d="M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242"></path>
                            <path d="M12 12v9"></path>
                            <path d="m8 17 4 4 4-4"></path>
                        </svg>
                    </div>
                    <div className="flex-1 flex items-center justify-between">
                        <h1 className="text-base font-bold text-white tracking-tight leading-none">
                            TechXPark
                        </h1>
                        <span className="text-[10px] uppercase tracking-wider bg-white/10 text-white/70 px-1.5 py-0.5 rounded-sm font-medium">
                            v1.0
                        </span>
                    </div>
                </div>

                {/* Lot Info Card */}
                <div className="bg-white/5 rounded-lg p-3 flex gap-3 items-start border border-white/5">
                    <MapPin className="w-4 h-4 text-primary shrink-0 mt-0.5" />
                    <div className="flex flex-col min-w-0">
                        <span className="text-sm font-semibold text-white truncate">
                            {lotData?.name || 'Loading lot...'}
                        </span>
                        <span className="text-xs text-sidebar-text truncate">
                            {lotData?.city || 'City'} • {lotData?.total_slots || 0} slots
                        </span>
                    </div>
                </div>
            </div>

            {/* Navigation */}
            <nav className="flex-1 px-3 py-2 overflow-y-auto">
                {isAdmin && renderNavSection(adminItemsWithBadge, 'SUPER ADMIN')}
                {renderNavSection(NAV_ITEMS, 'MAIN')}
                {renderNavSection(managementItemsWithBadge, 'MANAGEMENT')}
                {renderNavSection(ACCOUNT_ITEMS, 'ACCOUNT')}
            </nav>

            {/* Ask Access Button */}
            <div className="px-3 pb-3">
                <button
                    onClick={() => setShowAskModal(true)}
                    className="w-full flex items-center gap-3 px-4 py-3 rounded-xl bg-gradient-to-r from-primary to-[#4C63E8] text-white font-bold text-sm hover:from-[#1E36B5] hover:to-primary transition-all shadow-lg shadow-primary/30"
                >
                    <svg className="w-5 h-5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4" />
                    </svg>
                    <span>Ask for Lot Access</span>
                </button>
            </div>

            <AskAccessModal isOpen={showAskModal} onClose={() => setShowAskModal(false)} />

            {/* Bottom User Section */}
            <div className="p-4 border-t border-sidebar-border shrink-0">
                <div className="flex items-center gap-3 group/user cursor-pointer">
                    <Avatar
                        name={ownerData?.name || 'Manager'}
                        size="md"
                        status="online"
                    />
                    <div className="flex flex-col flex-1 min-w-0">
                        <span className="text-sm font-semibold text-white truncate">
                            {ownerData?.name || 'Manager'}
                        </span>
                        <span className="text-xs text-sidebar-text truncate">
                            Parking Manager
                        </span>
                    </div>
                    <div className="flex items-center opacity-0 group-hover/user:opacity-100 transition-opacity">
                        <button
                            onClick={(e) => { e.stopPropagation(); handleLogout(); }}
                            className="p-1.5 text-sidebar-text hover:text-error rounded-md transition-colors"
                            title="Log out"
                        >
                            <LogOut className="w-4 h-4" />
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}
