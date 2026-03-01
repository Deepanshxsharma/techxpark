import { useAuth } from '../../context/AuthContext';

export default function PendingScreen() {
    const { userData, logout } = useAuth();

    const steps = [
        { label: 'Request submitted', done: true },
        { label: 'Admin reviewing request', done: false, current: true },
        { label: 'Approval notification sent', done: false },
        { label: 'Dashboard access granted', done: false },
    ];

    return (
        <div className="min-h-screen bg-[#F4F6FB] flex items-center justify-center p-4">
            <div className="bg-white rounded-3xl shadow-xl w-full max-w-md p-8 text-center">

                {/* Animated hourglass */}
                <div className="w-20 h-20 bg-amber-100 rounded-full flex items-center justify-center mx-auto mb-6 text-4xl animate-bounce">
                    ⏳
                </div>

                <h1 className="text-2xl font-black text-[#0D1117] tracking-tight mb-2">
                    Request Pending
                </h1>
                <p className="text-[#5C6B8A] text-sm mb-6">
                    Your request has been submitted. The super admin will review it shortly.
                    This page will automatically update when your request is approved.
                </p>

                {/* Steps */}
                <div className="text-left space-y-3 mb-6">
                    {steps.map((step, i) => (
                        <div key={i} className="flex items-center gap-3">
                            <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0 transition-all ${step.done
                                ? 'bg-[#0D9E6E] text-white'
                                : step.current
                                    ? 'bg-[#2845D6] text-white animate-pulse'
                                    : 'bg-[#F4F6FB] text-[#9AA5BC] border-2 border-[#E8ECF4]'
                                }`}>
                                {step.done ? '✓' : i + 1}
                            </div>
                            <p className={`text-sm ${step.current
                                ? 'font-bold text-[#0D1117]'
                                : step.done
                                    ? 'text-[#9AA5BC] line-through'
                                    : 'text-[#9AA5BC]'
                                }`}>
                                {step.label}
                            </p>
                        </div>
                    ))}
                </div>

                {/* Auto update note */}
                <div className="bg-[#EEF2FF] rounded-xl p-3 mb-6">
                    <p className="text-xs text-[#2845D6] font-medium">
                        💡 This page updates automatically. You will be redirected to your dashboard the moment admin approves your request — no refresh needed!
                    </p>
                </div>

                <button
                    onClick={logout}
                    className="w-full py-3 border-2 border-[#E8ECF4] text-[#5C6B8A] rounded-xl text-sm font-medium hover:border-[#C7D2FE] hover:text-[#2845D6] transition-colors"
                >
                    Sign out
                </button>
            </div>
        </div>
    );
}
