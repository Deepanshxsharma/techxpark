import { useEffect, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useLot } from '../hooks/useLot';
import { Bell, Search } from 'lucide-react';
import Avatar from './ui/Avatar';

export default function TopBar() {
    const { ownerData, logout } = useAuth();
    const { lotData } = useLot(ownerData?.assignedLotId);
    const location = useLocation();

    // Derived values
    const totalSlots = lotData?.total_slots || 0;
    const freeSlots = lotData?.available_slots || 0;
    const occupiedSlots = totalSlots - freeSlots;

    const getPageTitle = () => {
        switch (location.pathname) {
            case '/dashboard': return 'Dashboard';
            case '/map': return 'Live Map';
            case '/sensors': return 'Sensors › Manager';
            case '/bookings': return 'Bookings';
            case '/messages': return 'Messages';
            case '/settings': return 'Settings';
            default: return 'Overview';
        }
    };

    return (
        <header className="h-[64px] bg-white border-b border-border flex items-center justify-between px-8 bg-surface shrink-0">

            {/* Left: Breadcrumb style page title */}
            <div className="flex items-center font-semibold text-base text-text-primary tracking-[-0.3px]">
                {getPageTitle()}
            </div>

            {/* Center: Live stats pill row */}
            <div className="hidden lg:flex flex-col items-center">
                <div className="bg-bg-light border border-border rounded-lg px-4 py-1.5 shadow-xs flex items-center gap-3">
                    <div className="flex items-center gap-1.5 text-sm font-semibold text-text-primary">
                        <span className="relative flex h-2 w-2">
                            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-success opacity-75"></span>
                            <span className="relative inline-flex rounded-full h-2 w-2 bg-success"></span>
                        </span>
                        {freeSlots} Free
                    </div>
                    <span className="text-text-tertiary text-xs">•</span>
                    <div className="flex items-center gap-1.5 text-sm font-semibold text-text-primary">
                        <span className="relative flex h-2 w-2">
                            <span className="relative inline-flex rounded-full h-2 w-2 bg-error"></span>
                        </span>
                        {occupiedSlots} Occupied
                    </div>
                    <span className="text-text-tertiary text-xs">•</span>
                    <span className="text-xs font-semibold text-text-secondary">
                        {lotData?.name || 'Loading...'}
                    </span>
                </div>
            </div>

            {/* Right: Action cluster */}
            <div className="flex items-center gap-4">
                <button className="p-2 text-text-secondary hover:text-text-primary hover:bg-surface-hover rounded-full transition-colors">
                    <Search className="w-5 h-5" />
                </button>

                <div className="w-px h-6 bg-border"></div>

                <button className="relative p-2 text-text-secondary hover:text-primary hover:bg-surface-hover rounded-full transition-colors group">
                    <Bell className="w-5 h-5 group-hover:animate-[wiggle_0.5s_ease-in-out_once]" />
                    <span className="absolute top-1 right-1.5 w-2 h-2 bg-error rounded-full border border-white"></span>
                </button>

                <div className="w-px h-6 bg-border"></div>

                <div className="flex items-center cursor-pointer">
                    <Avatar
                        name={ownerData?.name || "Manager"}
                        size="sm"
                    />
                </div>
            </div>

        </header>
    );
}
