import { useState, useEffect } from 'react';

const API_KEY = ''; // User fills in their OpenWeather API key

/** Fetches weather every 30 min from OpenWeather */
export default function useWeather(lat, lon) {
  const [weather, setWeather] = useState(null);

  useEffect(() => {
    if (!lat || !lon || !API_KEY) {
      // Provide a fallback
      setWeather({ temp: '--', desc: 'N/A', icon: '01d' });
      return;
    }
    const fetchW = async () => {
      try {
        const r = await fetch(
          `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&units=metric&appid=${API_KEY}`
        );
        const d = await r.json();
        setWeather({
          temp: Math.round(d.main.temp),
          desc: d.weather?.[0]?.description ?? '',
          icon: d.weather?.[0]?.icon ?? '01d',
        });
      } catch { /* keep cached */ }
    };
    fetchW();
    const id = setInterval(fetchW, 30 * 60_000);
    return () => clearInterval(id);
  }, [lat, lon]);

  return weather;
}

export function WeatherIcon({ code }) {
  const map = {
    '01d': '☀️', '01n': '🌙', '02d': '⛅', '02n': '☁️',
    '03d': '☁️', '03n': '☁️', '04d': '☁️', '04n': '☁️',
    '09d': '🌧️', '09n': '🌧️', '10d': '🌦️', '10n': '🌧️',
    '11d': '⛈️', '11n': '⛈️', '13d': '🌨️', '13n': '🌨️',
    '50d': '🌫️', '50n': '🌫️',
  };
  return <span className="text-2xl">{map[code] || '☀️'}</span>;
}
