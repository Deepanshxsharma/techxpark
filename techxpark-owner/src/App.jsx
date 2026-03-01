import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { AuthProvider, useAuth } from './context/AuthContext';

// Pages
import Login from './pages/Login';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import LiveMap from './pages/LiveMap';
import SensorManager from './pages/SensorManager';
import Bookings from './pages/Bookings';
import Messages from './pages/Messages';
import Settings from './pages/Settings';

// Access screens
import RequestAccessScreen from './pages/access/RequestAccessScreen';
import PendingScreen from './pages/access/PendingScreen';
import RejectedScreen from './pages/access/RejectedScreen';
import AccessDeniedScreen from './pages/access/AccessDeniedScreen';

// Loading spinner component
function LoadingScreen() {
  return (
    <div className="min-h-screen bg-[#F4F6FB] flex items-center justify-center">
      <div className="text-center">
        <div className="w-14 h-14 border-4 border-[#2845D6] border-t-transparent rounded-full animate-spin mx-auto mb-4" />
        <p className="text-[#5C6B8A] font-medium">Loading your account...</p>
      </div>
    </div>
  );
}

// This component decides which screen to show based on the owner's accessStatus
function AccessGate({ children }) {
  const { user, userData, loading, role, accessStatus } = useAuth();

  // 1. Still loading — show spinner
  if (loading) return <LoadingScreen />;

  // 2. Not logged in — go to login
  if (!user) return <Navigate to="/" replace />;

  // 3. userData not loaded yet — show spinner
  if (!userData) return <LoadingScreen />;

  // 4. Not an owner — access denied
  if (role !== 'owner') {
    return <AccessDeniedScreen />;
  }

  // 5. No request submitted yet
  if (!accessStatus || accessStatus === 'none') {
    return <RequestAccessScreen />;
  }

  // 6. Request submitted, waiting for admin
  if (accessStatus === 'pending') {
    return <PendingScreen />;
  }

  // 7. Request was rejected
  if (accessStatus === 'rejected') {
    return <RejectedScreen />;
  }

  // 8. Approved — show the actual dashboard
  if (accessStatus === 'approved') {
    return children;
  }

  // Fallback
  return <RequestAccessScreen />;
}

// Simple route wrapper
function ProtectedRoute({ children }) {
  const { user, loading } = useAuth();
  if (loading) return <LoadingScreen />;
  if (!user) return <Navigate to="/" replace />;
  return <AccessGate>{children}</AccessGate>;
}

function AppRoutes() {
  const { user, loading } = useAuth();
  if (loading) return <LoadingScreen />;

  return (
    <Routes>
      {/* Login — redirect to dashboard if logged in */}
      <Route
        path="/"
        element={user ? <Navigate to="/dashboard" replace /> : <Login />}
      />
      <Route
        path="/login"
        element={user ? <Navigate to="/dashboard" replace /> : <Login />}
      />

      {/* All protected routes go through AccessGate */}
      <Route element={<ProtectedRoute><Layout /></ProtectedRoute>}>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/map" element={<LiveMap />} />
        <Route path="/sensors" element={<SensorManager />} />
        <Route path="/bookings" element={<Bookings />} />
        <Route path="/messages" element={<Messages />} />
        <Route path="/settings" element={<Settings />} />
      </Route>

      {/* Catch all */}
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <AppRoutes />
        <Toaster
          position="top-right"
          toastOptions={{
            style: {
              background: '#0D1117',
              color: '#F8FAFF',
              borderRadius: '10px',
              border: '1px solid rgba(255,255,255,0.1)',
            },
            success: { iconTheme: { primary: '#22C55E', secondary: '#fff' } },
            error: { iconTheme: { primary: '#EF4444', secondary: '#fff' } },
          }}
        />
      </BrowserRouter>
    </AuthProvider>
  );
}
