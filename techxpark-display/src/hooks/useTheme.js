import { useState, useEffect } from 'react';

/** Auto theme: light 6AM-7PM, dark 7PM-6AM. Checks every minute. */
export default function useTheme(forceTheme) {
  const [theme, setTheme] = useState(() => getAutoTheme());

  useEffect(() => {
    if (forceTheme && forceTheme !== 'auto') {
      setTheme(forceTheme);
      document.documentElement.setAttribute('data-theme', forceTheme);
      return;
    }
    const update = () => {
      const t = getAutoTheme();
      setTheme(t);
      document.documentElement.setAttribute('data-theme', t);
    };
    update();
    const id = setInterval(update, 60_000);
    return () => clearInterval(id);
  }, [forceTheme]);

  return theme;
}

function getAutoTheme() {
  const h = new Date().getHours();
  return (h >= 6 && h < 19) ? 'light' : 'dark';
}
