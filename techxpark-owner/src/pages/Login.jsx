import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { toast } from 'react-hot-toast';
import { Eye, EyeOff, Loader2 } from 'lucide-react';

export default function Login() {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [loading, setLoading] = useState(false);
    const [errorMsg, setErrorMsg] = useState('');
    const navigate = useNavigate();

    const handleLogin = async (e) => {
        e.preventDefault();
        setLoading(true);

        try {
            const { user } = await signInWithEmailAndPassword(auth, email, password);

            // Verify Role
            const userDoc = await getDoc(doc(db, 'users', user.uid));
            if (!userDoc.exists() || userDoc.data()?.role !== 'owner') {
                await auth.signOut();
                setErrorMsg('not-owner');
                setLoading(false);
                return;
            }

            toast.success('Welcome back!');
            navigate('/dashboard');
        } catch (error) {
            console.error(error);
            setErrorMsg(error.code);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex text-text-primary overflow-hidden font-sans bg-bg-light">

            {/* LEFT SIDE - BRANDING (60%) */}
            <div className="hidden lg:flex lg:w-[60%] bg-sidebar-bg relative flex-col justify-between p-12 overflow-hidden">
                {/* Decorative background pattern */}
                <div className="absolute inset-0 opacity-10"
                    style={{ backgroundImage: 'radial-gradient(var(--primary) 1px, transparent 1px)', backgroundSize: '32px 32px' }}>
                </div>

                <div className="relative z-10 flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-primary flex items-center justify-center text-white font-bold text-xl shadow-lg shadow-primary/20">
                        P
                    </div>
                    <h1 className="text-3xl font-bold tracking-tight text-white leading-none">
                        TechXPark<span className="text-primary">.</span>
                    </h1>
                </div>

                <div className="relative z-10 max-w-lg">
                    <h2 className="text-4xl font-bold text-white mb-6 leading-tight">
                        Owner Management Portal
                    </h2>
                    <p className="text-text-tertiary text-lg mb-10 leading-relaxed text-slate-400">
                        The complete ecosystem for advanced parking infrastructure. Monitor, manage, and engage with your parking lot in real-time.
                    </p>

                    <div className="space-y-6">
                        <div className="flex items-center gap-4 text-slate-300">
                            <div className="w-12 h-12 rounded-full bg-slate-800 flex items-center justify-center shrink-0 border border-slate-700">
                                📡
                            </div>
                            <span className="text-[17px] font-medium">Live sensor monitoring</span>
                        </div>
                        <div className="flex items-center gap-4 text-slate-300">
                            <div className="w-12 h-12 rounded-full bg-slate-800 flex items-center justify-center shrink-0 border border-slate-700">
                                📊
                            </div>
                            <span className="text-[17px] font-medium">Real-time occupancy data</span>
                        </div>
                        <div className="flex items-center gap-4 text-slate-300">
                            <div className="w-12 h-12 rounded-full bg-slate-800 flex items-center justify-center shrink-0 border border-slate-700">
                                💬
                            </div>
                            <span className="text-[17px] font-medium">Direct customer messaging</span>
                        </div>
                    </div>
                </div>

                <div className="relative z-10 text-slate-500 text-[13px] font-bold tracking-[0.8px] uppercase">
                    Powered by TechXPark
                </div>
            </div>

            {/* RIGHT SIDE - FORM (40%) */}
            <div className="w-full lg:w-[40%] flex flex-col justify-center px-8 sm:px-12 lg:px-16 bg-white relative shadow-[-20px_0_40px_rgba(0,0,0,0.05)]">

                {/* Mobile Header (Hidden on Desktop) */}
                <div className="flex lg:hidden items-center gap-2 mb-10">
                    <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center text-white font-bold text-lg">
                        P
                    </div>
                    <h1 className="text-xl font-bold tracking-tight text-text-primary leading-none">
                        TechXPark<span className="text-primary">.</span>
                    </h1>
                </div>

                <div className="max-w-md w-full mx-auto">
                    <h1 className="text-[32px] font-bold text-text-primary mb-2 tracking-tight">Welcome Back</h1>
                    <p className="text-text-secondary mb-10 text-[17px]">Sign in to manage your parking lot.</p>

                    <form onSubmit={handleLogin} className="space-y-5">

                        <div>
                            <label className="block text-[13px] font-bold text-text-secondary mb-1.5 uppercase tracking-[0.5px]">Email Address</label>
                            <div className="relative">
                                <span className="absolute left-4 top-3.5 text-text-tertiary">✉️</span>
                                <input
                                    type="email"
                                    required
                                    className="w-full pl-11 pr-4 py-3 rounded-xl border border-border focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary transition-all bg-bg-light font-medium text-[15px] shadow-xs"
                                    placeholder="owner@techxpark.in"
                                    value={email}
                                    onChange={(e) => {
                                        setEmail(e.target.value);
                                        setErrorMsg('');
                                    }}
                                />
                            </div>
                            {errorMsg === 'auth/user-not-found' && (
                                <p className="text-error text-sm mt-1.5 font-medium ml-1">User not found. Please try again.</p>
                            )}
                        </div>

                        <div>
                            <label className="block text-[13px] font-bold text-text-secondary mb-1.5 uppercase tracking-[0.5px]">Password</label>
                            <div className="relative">
                                <span className="absolute left-4 top-3.5 text-text-tertiary">🔒</span>
                                <input
                                    type={showPassword ? "text" : "password"}
                                    required
                                    className="w-full pl-11 pr-12 py-3 rounded-xl border border-border focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary transition-all bg-bg-light font-medium text-[15px] shadow-xs"
                                    placeholder="••••••••"
                                    value={password}
                                    onChange={(e) => {
                                        setPassword(e.target.value);
                                        setErrorMsg('');
                                    }}
                                />
                                <button
                                    type="button"
                                    className="absolute right-3 top-3.5 text-text-tertiary hover:text-text-primary focus:outline-none p-1 transition-colors"
                                    onClick={() => setShowPassword(!showPassword)}
                                >
                                    {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                                </button>
                            </div>
                            {(errorMsg === 'auth/wrong-password' || errorMsg === 'auth/invalid-credential') && (
                                <p className="text-error text-[13px] mt-1.5 font-bold ml-1">Incorrect password.</p>
                            )}
                        </div>

                        {errorMsg === 'not-owner' && (
                            <div className="p-4 bg-error-bg border border-error/20 rounded-xl mt-4">
                                <p className="text-error text-[13px] font-bold leading-relaxed">
                                    Access denied. This portal is for parking lot managers only.
                                </p>
                            </div>
                        )}

                        <button
                            type="submit"
                            disabled={loading}
                            className={`w-full bg-primary hover:bg-primary-dark text-white font-bold py-3.5 px-4 rounded-xl transition-all flex items-center justify-center mt-8 ${loading ? 'opacity-50 cursor-not-allowed' : 'shadow-lg shadow-primary/30 hover:scale-[1.02]'}`}
                        >
                            {loading ? <Loader2 className="w-5 h-5 animate-spin" /> : "Sign In"}
                        </button>
                    </form>

                    <div className="mt-10 text-center">
                        <p className="text-[13px] text-text-secondary font-semibold">
                            Having trouble? <a href="#" className="text-primary hover:underline font-bold">Contact HQ</a>
                        </p>
                    </div>
                </div>
            </div>

        </div>
    );
}
