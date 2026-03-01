import { useState, useEffect, useRef } from 'react';

/**
 * Anti-screen-burn:
 *  - ±2px pixel shift every 60s
 *  - Night dim (2AM-5AM) at 40% brightness
 */
export default function useAntiBurn() {
  const [shift, setShift] = useState({ x: 0, y: 0 });
  const [isDimmed, setIsDimmed] = useState(false);

  useEffect(() => {
    const id = setInterval(() => {
      setShift({
        x: Math.round(Math.random() * 4 - 2),
        y: Math.round(Math.random() * 4 - 2),
      });
      const h = new Date().getHours();
      setIsDimmed(h >= 2 && h < 5);
    }, 60_000);
    return () => clearInterval(id);
  }, []);

  return { shift, isDimmed };
}
