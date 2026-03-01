import React, { useState, useEffect } from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import TopBar from './TopBar';
import CommandPalette from './CommandPalette';

export default function Layout() {
    const [isCommandOpen, setIsCommandOpen] = useState(false);

    useEffect(() => {
        const handleKeyDown = (e) => {
            if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
                e.preventDefault();
                setIsCommandOpen(true);
            }
        };
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, []);

    return (
        <div className="flex h-screen w-full bg-bg-light overflow-hidden">
            {/* Sidebar */}
            <Sidebar />

            {/* Main Content Area */}
            <div className="flex-1 flex flex-col h-screen min-w-0">
                {/* Top Navbar */}
                <TopBar onOpenCommand={() => setIsCommandOpen(true)} />

                {/* Page Content */}
                <main className="flex-1 overflow-y-auto p-6 md:p-8 scroll-smooth scrollbar-none">
                    <div className="mx-auto max-w-[1400px]">
                        <Outlet />
                    </div>
                </main>
            </div>
            <CommandPalette isOpen={isCommandOpen} onClose={() => setIsCommandOpen(false)} />
        </div>
    );
}
