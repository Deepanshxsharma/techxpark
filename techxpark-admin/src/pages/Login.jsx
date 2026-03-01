import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import { ShieldAlert, Users, Car, BarChart3, AlertCircle } from 'lucide-react';
import Button from '../components/ui/Button';

export default function Login() {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [isLoading, setIsLoading] = useState(false);

    const { login } = useAuth();
    const navigate = useNavigate();

    const handleLogin = async (e) => {
        e.preventDefault();
        setError('');
        setIsLoading(true);

        try {
            await login(email, password);
            // The AuthContext and App.jsx will handle checking the role and redirecting.
            // If they are an admin, they go to dashboard. If not, they go to AccessDenied.
            // But we can also catch immediate auth errors here (wrong password).
            navigate('/dashboard');
        } catch (err) {
            console.error("Login Error:", err);
            // Firebase explicit errors
            if (err.code === 'auth/user-not-found' || err.code === 'auth/wrong-password' || err.code === 'auth/invalid-credential') {
                setError('Invalid email or password.');
            } else {
                setError('Failed to sign in. Please try again.');
            }
            setIsLoading(false);
        }
    };

    return (
        <div className="flex min-h-screen bg-white">

            {/* Left Panel - Dark / Branding (60%) */}
            <div className="hidden lg:flex w-[60%] bg-sidebar-bg flex-col justify-between p-12 relative overflow-hidden">
                {/* Background decorative elements */}
                <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] bg-primary blur-[120px] rounded-full opacity-20 pointer-events-none"></div>
                <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] bg-purple-600 blur-[120px] rounded-full opacity-20 pointer-events-none"></div>

                <div className="relative z-10">
                    <div className="flex items-center gap-3 mb-8">
                        <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-primary to-indigo-600 flex items-center justify-center text-white font-bold text-2xl shadow-primary">
                            P
                        </div>
                        <div>
                            <h1 className="text-3xl font-bold tracking-tight text-white leading-none mb-1">
                                TechXPark<span className="text-primary-light">.</span>
                            </h1>
                            <p className="text-sidebar-text font-medium">Super Admin Portal</p>
                        </div>
                    </div>

                    <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-gradient-to-r from-amber-500/20 to-orange-500/20 border border-amber-500/30 text-amber-500 mb-12">
                        <span className="text-lg">⚡</span>
                        <span className="text-[11px] font-extrabold uppercase tracking-widest text-[#FDE68A]">Super Admin Access</span>
                    </div>

                    <div className="space-y-8 max-w-md">
                        <div className="flex items-start gap-4">
                            <div className="w-10 h-10 rounded-xl bg-white/5 flex items-center justify-center text-primary-light shrink-0 border border-white/10">
                                <Users className="w-5 h-5" />
                            </div>
                            <div>
                                <h3 className="text-white font-bold mb-1">Manage all users & owners</h3>
                                <p className="text-sidebar-text text-sm leading-relaxed">Full control over platform accounts, roles, access permissions and suspensions.</p>
                            </div>
                        </div>

                        <div className="flex items-start gap-4">
                            <div className="w-10 h-10 rounded-xl bg-white/5 flex items-center justify-center text-primary-light shrink-0 border border-white/10">
                                <Car className="w-5 h-5" />
                            </div>
                            <div>
                                <h3 className="text-white font-bold mb-1">Control all parking lots</h3>
                                <p className="text-sidebar-text text-sm leading-relaxed">Monitor real-time occupancy, edit lot details, and assign location managers.</p>
                            </div>
                        </div>

                        <div className="flex items-start gap-4">
                            <div className="w-10 h-10 rounded-xl bg-white/5 flex items-center justify-center text-primary-light shrink-0 border border-white/10">
                                <BarChart3 className="w-5 h-5" />
                            </div>
                            <div>
                                <h3 className="text-white font-bold mb-1">Platform-wide analytics</h3>
                                <p className="text-sidebar-text text-sm leading-relaxed">Track comprehensive revenue, global bookings, and hardware sensor health.</p>
                            </div>
                        </div>
                    </div>
                </div>

                <div className="relative z-10 text-sidebar-text text-sm">
                    &copy; {new Date().getFullYear()} TechXPark. Enterprise Dashboard.
                </div>
            </div>

            {/* Right Panel - Form (40%) */}
            <div className="w-full lg:w-[40%] flex flex-col justify-center px-8 sm:px-16 lg:px-24">
                <div className="max-w-md w-full mx-auto">

                    <div className="mb-10 lg:hidden flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl bg-primary flex items-center justify-center text-white font-bold text-xl shadow-primary">
                            P
                        </div>
                        <h1 className="text-2xl font-bold tracking-tight text-text-primary">
                            TechXPark<span className="text-primary">.</span>
                        </h1>
                    </div>

                    <h2 className="text-[28px] font-extrabold text-text-primary tracking-tight mb-2">Admin Login</h2>
                    <div className="flex items-center gap-2 text-warning mb-8 font-medium">
                        <ShieldAlert className="w-4 h-4" />
                        <span className="text-[13px]">Authorized personnel only</span>
                    </div>

                    {error && (
                        <div className="mb-6 p-4 rounded-xl bg-error-bg border border-error/20 flex items-start gap-3 animate-fade-in">
                            <AlertCircle className="w-5 h-5 text-error shrink-0 mt-0.5" />
                            <p className="text-sm font-medium text-error-text">{error}</p>
                        </div>
                    )}

                    <form onSubmit={handleLogin} className="space-y-5">
                        <div className="space-y-1.5">
                            <label className="text-[13px] font-bold text-text-secondary">Email Address</label>
                            <input
                                type="email"
                                required
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                className="w-full px-4 py-3 rounded-xl border border-border bg-surface hover:border-[#D1D5DB] focus:border-primary focus:ring-4 focus:ring-primary/10 outline-none transition-all text-sm font-medium"
                                placeholder="admin@techxpark.app"
                            />
                        </div>

                        <div className="space-y-1.5">
                            <label className="text-[13px] font-bold text-text-secondary">Password</label>
                            <input
                                type="password"
                                required
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                className="w-full px-4 py-3 rounded-xl border border-border bg-surface hover:border-[#D1D5DB] focus:border-primary focus:ring-4 focus:ring-primary/10 outline-none transition-all text-sm font-medium"
                                placeholder="••••••••"
                            />
                        </div>

                        <div className="pt-2">
                            <Button
                                type="submit"
                                className="w-full py-3.5 text-[15px]"
                                loading={isLoading}
                            >
                                Sign In as Super Admin
                            </Button>
                        </div>
                    </form>

                </div>
            </div>
        </div>
    );
}
