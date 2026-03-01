import React from 'react';
import { useAuth } from '../hooks/useAuth';
import { ShieldAlert, LogOut } from 'lucide-react';
import Button from '../components/ui/Button';

export default function AccessDenied() {
    const { logout, adminData } = useAuth();

    return (
        <div className="min-h-screen bg-bg-light flex flex-col items-center justify-center p-6 font-sans text-text-primary animate-in fade-in duration-500">

            {/* Header */}
            <div className="flex items-center gap-3 mb-10">
                <div className="w-10 h-10 rounded-xl bg-error flex items-center justify-center text-white font-bold text-xl shadow-lg shadow-error/20">
                    P
                </div>
                <h1 className="text-2xl font-bold tracking-tight text-text-primary leading-none">
                    TechXPark<span className="text-error">.</span>
                </h1>
            </div>

            {/* Main Card */}
            <div className="w-full max-w-[480px] bg-white rounded-2xl border border-border shadow-sm overflow-hidden text-center">
                <div className="h-1.5 w-full bg-error" />

                <div className="p-10 border-b border-border bg-surface flex flex-col items-center">
                    <div className="w-20 h-20 bg-error-bg rounded-full flex items-center justify-center mb-6 text-error shadow-sm">
                        <ShieldAlert className="w-10 h-10" />
                    </div>
                    <h2 className="text-[26px] font-bold tracking-tight mb-3">Access Denied</h2>
                    <p className="text-[15px] font-medium text-text-secondary leading-relaxed max-w-[340px]">
                        You do not have Super Admin privileges to view this portal.
                    </p>
                </div>

                <div className="p-8 space-y-6">
                    <div className="bg-bg-light rounded-xl border border-border p-5 text-left">
                        <h3 className="text-[11px] font-bold text-text-tertiary uppercase tracking-[0.8px] mb-4">Account Information</h3>

                        <div className="space-y-3">
                            <div className="flex justify-between items-center text-[13px]">
                                <span className="text-text-secondary font-medium">Name</span>
                                <span className="font-bold text-text-primary">{adminData?.name || 'Unknown'}</span>
                            </div>
                            <div className="flex justify-between items-center text-[13px]">
                                <span className="text-text-secondary font-medium">Email</span>
                                <span className="font-medium text-text-primary">{adminData?.email || 'Unknown'}</span>
                            </div>
                            <div className="flex justify-between items-center text-[13px]">
                                <span className="text-text-secondary font-medium">Role</span>
                                <span className="flex items-center gap-1.5 font-bold text-error bg-error-bg px-2 py-0.5 rounded-md border border-error/20 uppercase tracking-widest text-[10px]">
                                    {adminData?.role || 'User'}
                                </span>
                            </div>
                        </div>
                    </div>

                    <Button
                        variant="ghost"
                        onClick={logout}
                        className="w-full"
                        icon={LogOut}
                    >
                        Sign out and return to Login
                    </Button>
                </div>
            </div>

        </div>
    );
}
