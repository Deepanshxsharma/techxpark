import React, { useState, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { collection, query, onSnapshot } from 'firebase/firestore';
import { db } from '../firebase';
import { useAuth } from '../hooks/useAuth';
import { Search, Bell, ChevronDown } from 'lucide-react';
import Avatar from './ui/Avatar';

export default function TopBar({ onOpenCommand }) {
    const location = useLocation();
    const { adminData } = useAuth();

    // Dynamic page title based on route
    const getPageTitle = (pathname) => {
        const path = pathname.split('/')[1] || 'dashboard';
        const titles = {
            dashboard: 'Platform Overview',
            lots: 'Parking Lots',
            sensors: 'Sensors Health',
            owners: 'Parking Lot Owners',
            users: 'Users',
            bookings: 'Bookings',
            revenue: 'Revenue',
            admin: 'Access Requests',
            notifications: 'Send Notifications',
            messages: 'Messages',
            settings: 'Settings'
        };
        return titles[path] || 'Admin Portal';
    };

    const [stats, setStats] = useState({ activeLots: 0, freeSlots: 0 });
    const [unreadNotifs, setUnreadNotifs] = useState(0);

    useEffect(() => {
        const unsubscribe = onSnapshot(query(collection(db, 'parking_locations')), (snapshot) => {
            let activeLots = 0;
            let freeSlots = 0;

            snapshot.docs.forEach((lotDoc) => {
                const lot = lotDoc.data();
                if (lot.isActive !== false) activeLots += 1;
                freeSlots += Number(lot.available_slots || 0);
            });

            setStats({ activeLots, freeSlots });
        }, (error) => {
            console.error('Topbar stats listener error:', error);
        });

        return () => unsubscribe();
    }, []);

    return (
        <header className="h-16 bg-white border-b border-border flex items-center justify-between px-8 shrink-0 relative z-10 w-full">

            {/* Left - Page Title */}
            <div className="flex-1 min-w-0">
                <h2 className="text-[18px] font-bold text-text-primary truncate tracking-tight">
                    {getPageTitle(location.pathname)}
                </h2>
            </div>

            {/* Center - Platform Health Pills */}
            <div className="hidden lg:flex flex-1 justify-center items-center gap-3">
                <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-success-bg border border-success/20">
                    <span className="w-2 h-2 rounded-full bg-success animate-pulse shrink-0"></span>
                    <span className="text-[11px] font-bold text-success-text uppercase tracking-wider">Platform Online</span>
                </div>
                <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-surface border border-border">
                    <span className="text-[11px] font-bold text-text-secondary uppercase tracking-wider">
                        <strong className="text-text-primary">{stats.activeLots}</strong> lots active
                        <span className="mx-1 text-text-tertiary">•</span>
                        <strong className="text-text-primary">{stats.freeSlots}</strong> slots free
                    </span>
                </div>
            </div>

            {/* Right - Actions */}
            <div className="flex-1 flex items-center justify-end gap-5">

                {/* Search Bar Trigger */}
                <button
                    onClick={onOpenCommand}
                    className="hidden md:flex items-center gap-3 px-3 py-1.5 rounded-lg bg-bg-light border border-border text-text-tertiary hover:bg-border/50 transition-colors group w-56"
                >
                    <Search className="w-4 h-4 group-hover:text-primary transition-colors" />
                    <span className="text-[13px] font-medium flex-1 text-left">Search...</span>
                    <kbd className="hidden sm:inline-block px-1.5 py-0.5 rounded text-[10px] font-mono font-bold bg-white border border-border text-text-tertiary">⌘K</kbd>
                </button>

                {/* Notifications */}
                <button className="relative p-2 text-text-secondary hover:text-primary bg-surface hover:bg-info-bg rounded-lg transition-colors border border-transparent hover:border-primary/20">
                    <Bell className="w-5 h-5" strokeWidth={2.5} />
                    {unreadNotifs > 0 && (
                        <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-error border-2 border-white"></span>
                    )}
                </button>

                {/* Profile Dropdown Trigger */}
                <div className="h-8 w-px bg-border mx-1"></div>

                <button className="flex items-center gap-2.5 outline-none group pl-1">
                    <Avatar name={adminData?.name || 'Super Admin'} size="sm" />
                    <ChevronDown className="w-4 h-4 text-text-tertiary group-hover:text-text-primary transition-colors" strokeWidth={2.5} />
                </button>
            </div>

        </header>
    );
}
