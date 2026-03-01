import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { AuthProvider } from './context/AuthContext';
import { useAuth } from './hooks/useAuth';

// Layout & Components
import Layout from './components/Layout';

// Pages
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import ParkingLots from './pages/ParkingLots';
import Owners from './pages/Owners';
import Users from './pages/Users';
import Bookings from './pages/Bookings';
import Revenue from './pages/Revenue';
import Sensors from './pages/Sensors';
import AccessRequests from './pages/AccessRequests';
import Notifications from './pages/Notifications';
import Messages from './pages/Messages';
import Settings from './pages/Settings';
import AccessDenied from './pages/AccessDenied';

// Protected Route Wrapper
const ProtectedRoute = ({ children }) => {
  const { user, adminData, loading } = useAuth();

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-sidebar-bg">
        <div className="w-12 h-12 border-4 border-primary border-t-transparent rounded-full animate-spin"></div>
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  if (adminData && adminData.role !== 'admin') {
    return <Navigate to="/denied" replace />;
  }

  // Double check adminData exists before rendering to avoid race conditions
  if (!adminData) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-sidebar-bg">
        <div className="w-12 h-12 border-4 border-primary border-t-transparent rounded-full animate-spin"></div>
      </div>
    );
  }

  return children;
};

// Admin Auth Redirection Logic
const AuthRoute = ({ children }) => {
  const { user, adminData, loading } = useAuth();

  if (loading) return null;

  if (user && adminData?.role === 'admin') {
    return <Navigate to="/dashboard" replace />;
  }

  return children;
};

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Toaster
          position="top-right"
          toastOptions={{
            style: {
              background: '#0A0F1E',
              color: '#fff',
              borderRadius: '12px',
              border: '1px solid rgba(255,255,255,0.1)',
            },
            success: {
              iconTheme: { primary: '#0D9E6E', secondary: '#fff' },
            }
          }}
        />
        <Routes>
          {/* Public / Auth Routes */}
          <Route path="/login" element={
            <AuthRoute>
              <Login />
            </AuthRoute>
          } />

          <Route path="/denied" element={<AccessDenied />} />

          {/* Protected Admin Routes */}
          <Route path="/" element={
            <ProtectedRoute>
              <Layout />
            </ProtectedRoute>
          }>
            <Route index element={<Navigate to="/dashboard" replace />} />

            <Route path="dashboard" element={<Dashboard />} />
            <Route path="lots" element={<ParkingLots />} />
            <Route path="sensors" element={<Sensors />} />

            <Route path="owners" element={<Owners />} />
            <Route path="users" element={<Users />} />

            <Route path="bookings" element={<Bookings />} />
            <Route path="revenue" element={<Revenue />} />

            <Route path="admin/requests" element={<AccessRequests />} />
            <Route path="notifications" element={<Notifications />} />
            <Route path="messages" element={<Messages />} />
            <Route path="settings" element={<Settings />} />

            {/* Catch all */}
            <Route path="*" element={<Navigate to="/dashboard" replace />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
