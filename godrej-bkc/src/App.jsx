import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { DemoProvider } from './context/DemoContext';
import { ParkingProvider, useParking } from './context/ParkingContext';
import ParkingSelectionModal from './components/ParkingSelectionModal';
import HomePage from './pages/HomePage';
import RequestPage from './pages/RequestPage';
import TrackingPage from './pages/TrackingPage';
import KioskPage from './pages/KioskPage';
import { AnimatePresence } from 'framer-motion';

function AppContent() {
  const { selectedParking } = useParking();

  return (
    <>
      {/* Parking selection gate — blocks app until a location is chosen */}
      <AnimatePresence>
        {!selectedParking && <ParkingSelectionModal />}
      </AnimatePresence>

      {/* Main app (hidden behind modal when no parking selected) */}
      {selectedParking && (
        <BrowserRouter>
          <Routes>
            <Route path="/" element={<HomePage />} />
            <Route path="/request" element={<RequestPage />} />
            <Route path="/track/:requestId" element={<TrackingPage />} />
            <Route path="/kiosk" element={<KioskPage />} />
          </Routes>
        </BrowserRouter>
      )}
    </>
  );
}

export default function App() {
  return (
    <ParkingProvider>
      <DemoProvider>
        <AppContent />
      </DemoProvider>
    </ParkingProvider>
  );
}
