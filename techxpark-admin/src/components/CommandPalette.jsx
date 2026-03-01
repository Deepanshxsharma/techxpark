import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, Car, Users, UserSquare2, Home, CreditCard, Activity, Settings, CalendarCheck, X } from 'lucide-react';

export default function CommandPalette({ isOpen, onClose }) {
    const [query, setQuery] = useState('');
    const inputRef = useRef(null);
    const navigate = useNavigate();

    useEffect(() => {
        if (isOpen) {
            document.body.style.overflow = 'hidden';
            setTimeout(() => inputRef.current?.focus(), 100);
        } else {
            document.body.style.overflow = 'unset';
            setQuery('');
        }
        return () => { document.body.style.overflow = 'unset'; };
    }, [isOpen]);

    // Handle Esc key to close
    useEffect(() => {
        const handleKeyDown = (e) => {
            if (e.key === 'Escape' && isOpen) onClose();
        };
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, [isOpen, onClose]);

    if (!isOpen) return null;

    const navigateTo = (path) => {
        navigate(path);
        onClose();
    };

    const navItems = [
        { title: 'Dashboard', icon: Home, path: '/dashboard', category: 'Pages' },
        { title: 'Parking Lots', icon: Car, path: '/lots', category: 'Pages' },
        { title: 'Lot Owners', icon: UserSquare2, path: '/owners', category: 'Pages' },
        { title: 'Customers', icon: Users, path: '/users', category: 'Pages' },
        { title: 'Bookings', icon: CalendarCheck, path: '/bookings', category: 'Operations' },
        { title: 'Revenue Analytics', icon: CreditCard, path: '/revenue', category: 'Operations' },
        { title: 'Hardware Sensors', icon: Activity, path: '/sensors', category: 'Operations' },
        { title: 'Settings', icon: Settings, path: '/settings', category: 'System' },
    ];

    const filteredItems = query === ''
        ? navItems
        : navItems.filter(item => item.title.toLowerCase().includes(query.toLowerCase()));

    // Group items by category
    const groupedItems = filteredItems.reduce((acc, item) => {
        if (!acc[item.category]) acc[item.category] = [];
        acc[item.category].push(item);
        return acc;
    }, {});

    return (
        <div className="fixed inset-0 z-[100] flex items-start justify-center pt-[10vh] px-4">

            {/* Backdrop */}
            <div
                className="absolute inset-0 bg-sidebar-bg/60 backdrop-blur-sm transition-opacity"
                onClick={onClose}
            ></div>

            {/* Modal */}
            <div className="relative w-full max-w-2xl bg-surface rounded-2xl shadow-[0_40px_80px_-20px_rgba(0,0,0,0.5)] border border-border overflow-hidden animate-scale-in flex flex-col max-h-[70vh]">

                {/* Search Input */}
                <div className="flex items-center px-4 py-4 border-b border-border bg-white">
                    <Search className="w-5 h-5 text-text-tertiary ml-2" />
                    <input
                        ref={inputRef}
                        type="text"
                        placeholder="Search for pages, users, lots, or bookings..."
                        value={query}
                        onChange={(e) => setQuery(e.target.value)}
                        className="flex-1 px-4 py-2 bg-transparent text-text-primary text-[15px] font-medium focus:outline-none placeholder:text-text-tertiary"
                    />
                    <button
                        onClick={onClose}
                        className="p-1 text-text-tertiary hover:bg-bg-light hover:text-text-primary rounded-lg transition-colors"
                    >
                        <X className="w-5 h-5" />
                    </button>
                </div>

                {/* Results */}
                <div className="flex-1 overflow-y-auto p-2 scrollbar-none">
                    {filteredItems.length === 0 ? (
                        <div className="py-14 text-center">
                            <Search className="w-8 h-8 text-text-tertiary/50 mx-auto mb-3" />
                            <p className="text-[14px] font-medium text-text-secondary">No results found for "{query}"</p>
                        </div>
                    ) : (
                        Object.keys(groupedItems).map(category => (
                            <div key={category} className="mb-4 last:mb-0">
                                <h4 className="px-4 py-2 text-[10px] font-bold uppercase tracking-wider text-text-tertiary">{category}</h4>
                                <div className="space-y-1">
                                    {groupedItems[category].map((item, idx) => (
                                        <button
                                            key={idx}
                                            onClick={() => navigateTo(item.path)}
                                            className="w-full flex items-center justify-between px-4 py-3 rounded-xl hover:bg-primary/5 hover:text-primary text-text-secondary transition-all group group-hover:bg-primary/5"
                                        >
                                            <div className="flex items-center gap-3">
                                                <item.icon className="w-4 h-4 text-text-tertiary group-hover:text-primary transition-colors" />
                                                <span className="text-[14px] font-bold text-text-primary group-hover:text-primary transition-colors">{item.title}</span>
                                            </div>
                                            <span className="text-[12px] font-bold text-text-tertiary group-hover:text-primary bg-bg-light group-hover:bg-primary/10 px-2 py-1 rounded transition-colors hidden sm:block">↵ Enter</span>
                                        </button>
                                    ))}
                                </div>
                            </div>
                        ))
                    )}
                </div>

                {/* Footer hints */}
                <div className="hidden sm:flex items-center justify-center gap-6 p-3 border-t border-border bg-bg-light/50 text-[11px] font-bold text-text-tertiary uppercase tracking-wider">
                    <span className="flex items-center gap-1.5"><strong className="bg-border/50 px-1.5 py-0.5 rounded text-text-secondary">↑↓</strong> to navigate</span>
                    <span className="flex items-center gap-1.5"><strong className="bg-border/50 px-1.5 py-0.5 rounded text-text-secondary">↵</strong> to select</span>
                    <span className="flex items-center gap-1.5"><strong className="bg-border/50 px-1.5 py-0.5 rounded text-text-secondary">ESC</strong> to close</span>
                </div>
            </div>

        </div>
    );
}
