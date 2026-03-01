import { useAuth } from '../../context/AuthContext';

export default function AccessDeniedScreen() {
    const { logout } = useAuth();
    return (
        <div className="min-h-screen bg-[#F4F6FB] flex items-center justify-center p-4">
            <div className="bg-white rounded-3xl shadow-xl w-full max-w-md p-8 text-center">
                <div className="w-20 h-20 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-6 text-4xl">
                    🚫
                </div>
                <h1 className="text-2xl font-black text-[#0D1117] mb-2">
                    Access Denied
                </h1>
                <p className="text-[#5C6B8A] text-sm mb-6">
                    This portal is only for parking lot managers. Your account role does not have permission to access this panel.
                </p>
                <button
                    onClick={logout}
                    className="w-full bg-red-500 text-white py-4 rounded-xl font-bold hover:bg-red-600 transition-colors"
                >
                    Sign Out
                </button>
            </div>
        </div>
    );
}
