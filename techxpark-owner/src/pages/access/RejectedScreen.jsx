import { useAuth } from '../../context/AuthContext';
import { doc, updateDoc } from 'firebase/firestore';
import { db } from '../../firebase';
import toast from 'react-hot-toast';

export default function RejectedScreen() {
    const { user, userData, logout } = useAuth();

    const handleReRequest = async () => {
        if (!user) return;
        try {
            await updateDoc(
                doc(db, 'users', user.uid),
                {
                    accessStatus: 'none',
                    requestId: null,
                    assignedLotId: null,
                }
            );
            // AuthContext onSnapshot will detect the change and show RequestAccessScreen
        } catch (err) {
            console.error('Re-request error:', err);
            toast.error('Something went wrong');
        }
    };

    return (
        <div className="min-h-screen bg-[#F4F6FB] flex items-center justify-center p-4">
            <div className="bg-white rounded-3xl shadow-xl w-full max-w-md p-8 text-center">

                <div className="w-20 h-20 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-6 text-4xl">
                    ❌
                </div>

                <h1 className="text-2xl font-black text-[#0D1117] mb-2">
                    Request Rejected
                </h1>
                <p className="text-[#5C6B8A] text-sm mb-5">
                    Unfortunately your access request was not approved by the admin.
                </p>

                {/* Rejection reason */}
                {userData?.rejectionReason && (
                    <div className="bg-red-50 border border-red-200 rounded-xl p-4 mb-5 text-left">
                        <p className="text-xs font-bold text-red-400 uppercase tracking-wider mb-1">
                            Reason from admin
                        </p>
                        <p className="text-sm text-red-700">
                            {userData.rejectionReason}
                        </p>
                    </div>
                )}

                <button
                    onClick={handleReRequest}
                    className="w-full bg-[#2845D6] text-white py-4 rounded-xl font-bold text-sm hover:bg-[#1E36B5] transition-colors mb-3"
                >
                    🔄 Request a Different Lot
                </button>

                <button
                    onClick={logout}
                    className="w-full py-3 text-[#9AA5BC] text-sm hover:text-[#5C6B8A] transition-colors"
                >
                    Sign out
                </button>
            </div>
        </div>
    );
}
