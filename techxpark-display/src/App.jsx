import { BrowserRouter, Routes, Route } from 'react-router-dom';
import DisplayPage from './pages/DisplayPage';

export default function App() {
    return (
        <BrowserRouter>
            <Routes>
                <Route path="*" element={<DisplayPage />} />
            </Routes>
        </BrowserRouter>
    );
}
