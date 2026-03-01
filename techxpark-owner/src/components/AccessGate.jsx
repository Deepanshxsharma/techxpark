import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import RequestAccessScreen from '../pages/access/RequestAccessScreen';
import PendingScreen from '../pages/access/PendingScreen';
import RejectedScreen from '../pages/access/RejectedScreen';
import AccessDeniedScreen from '../pages/access/AccessDeniedScreen';

export default function AccessGate({ children }) {
    const { user, userData, loading } = useAuth();

    // Still loading user data
    if (loading) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-[#F4F6FB]">
                <div className="text-center">
                    <div className="w-12 h-12 border-4 border-[#2845D6] border-t-transparent rounded-full animate-spin mx-auto mb-4" />
                    <p className="text-gray-500 font-medium">
                        Loading your account...
                    </p>
                </div>
            </div>
        );
    }

    // Not logged in → go to login
    if (!user) {
        return <Navigate to="/login" replace />;
    }

    // Not an owner role (and not an admin) → access denied
    // We allow 'admin' here because sometimes super admin might login to owner panel for debugging
    if (userData?.role !== 'owner' && userData?.role !== 'admin') {
        return <AccessDeniedScreen />;
    }

    // If admin, bypass the access gate logic (can see everything)
    if (userData?.role === 'admin') {
        return children;
    }

    // Owner but no request yet → show request form
    if (!userData?.accessStatus || userData?.accessStatus === 'none') {
        return <RequestAccessScreen />;
    }

    // Owner submitted request → waiting
    if (userData?.accessStatus === 'pending') {
        return <PendingScreen />;
    }

    // Owner was rejected → show rejection screen
    if (userData?.accessStatus === 'rejected') {
        return <RejectedScreen />;
    }

    // Owner is approved → show dashboard
    if (userData?.accessStatus === 'approved') {
        return children;
    }

    // Fallback
    return <RequestAccessScreen />;
}
