import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './index.css';

// Prevent context menu on TV
document.addEventListener('contextmenu', e => e.preventDefault());

// Auto-refresh every 6 hours
setTimeout(() => window.location.reload(), 6 * 60 * 60 * 1000);

ReactDOM.createRoot(document.getElementById('root')).render(
    <React.StrictMode><App /></React.StrictMode>
);
