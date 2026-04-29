import { useState, useEffect, useCallback } from 'react';

export default function CountdownTimer({ targetTime, label, onExpire, large = false, className = '' }) {
  const [remaining, setRemaining] = useState(null);
  const [expired, setExpired] = useState(false);

  const getTarget = useCallback(() => {
    if (!targetTime) return null;
    if (targetTime instanceof Date) return targetTime.getTime();
    if (targetTime.toDate) return targetTime.toDate().getTime();
    if (typeof targetTime === 'string') return new Date(targetTime).getTime();
    if (typeof targetTime === 'number') return targetTime;
    if (targetTime.seconds) return targetTime.seconds * 1000;
    return null;
  }, [targetTime]);

  useEffect(() => {
    const target = getTarget();
    if (!target) return;

    const update = () => {
      const diff = target - Date.now();
      if (diff <= 0) {
        setRemaining(0);
        setExpired(true);
        if (onExpire) onExpire();
        return false;
      }
      setRemaining(diff);
      return true;
    };

    update();
    const interval = setInterval(() => {
      if (!update()) clearInterval(interval);
    }, 1000);

    return () => clearInterval(interval);
  }, [getTarget, onExpire]);

  if (remaining === null) return null;

  const totalSeconds = Math.max(0, Math.floor(remaining / 1000));
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  const pad = (n) => String(n).padStart(2, '0');

  let timeStr;
  if (hours > 0) {
    timeStr = `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
  } else {
    timeStr = `${pad(minutes)}:${pad(seconds)}`;
  }

  // Color based on remaining time
  let colorClass = 'text-primary-600';
  if (totalSeconds <= 300) {
    colorClass = 'text-error-500 animate-pulse';
  } else if (totalSeconds <= 600) {
    colorClass = 'text-warning-500';
  }

  if (expired) {
    colorClass = 'text-error-500';
    timeStr = '00:00';
  }

  return (
    <div className={`flex flex-col items-center gap-1 ${className}`}>
      {label && (
        <span className="text-sm text-text-secondary font-medium">{label}</span>
      )}
      <span
        className={`
          font-mono font-bold tracking-wider ${colorClass}
          ${large ? 'text-4xl md:text-5xl' : 'text-2xl'}
        `}
      >
        {timeStr}
      </span>
    </div>
  );
}
