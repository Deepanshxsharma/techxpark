import { useState, useCallback, useRef, useEffect } from 'react';

const STATIC_MSGS = [
  '📱 Book in advance — TechXPark App',
  '🅿️ Walk-in parking also available',
  '💳 Pay via UPI, Card, or Cash at exit',
];
const MAX = 20;

/**
 * Ticker message queue.
 * addMessage() adds a live update to the front.
 * Generates static messages every 60s when idle.
 */
export default function useTicker(totalFree, lotName) {
  const [messages, setMessages] = useState([]);
  const idx = useRef(0);

  const addMessage = useCallback((msg) => {
    setMessages(prev => [msg, ...prev].slice(0, MAX));
  }, []);

  // Static rotation every 60s
  useEffect(() => {
    const id = setInterval(() => {
      const statics = [
        ...STATIC_MSGS,
        `🅿️ ${totalFree} spots available right now`,
        `📞 Need help? Contact facility management`,
        lotName ? `🏢 ${lotName} — TechXPark Managed` : null,
      ].filter(Boolean);
      addMessage(statics[idx.current % statics.length]);
      idx.current++;
    }, 60_000);
    // Seed initial
    addMessage(`🅿️ ${totalFree} spots available right now`);
    return () => clearInterval(id);
  }, [totalFree, lotName, addMessage]);

  // Build ticker string
  const tickerText = messages.length
    ? messages.join('  •  ')
    : `🅿️ ${totalFree} spots available  •  📱 Scan QR to book  •  ${lotName || 'TechXPark'}`;

  return { messages, addMessage, tickerText };
}
