import React, { useMemo } from 'react';

/**
 * TrackingAnimation — Premium progress-driven SVG vehicle tracking
 *
 * Props:
 * @param {number}  progress - 0 to 100 (drives car position along path)
 * @param {string}  status   - Current lifecycle status
 * @param {boolean} mini     - Compact variant for cards
 */
export default function TrackingAnimation({ progress = 0, status = 'Queued', mini = false }) {
  const isMoving = status === 'In Process' || status === 'Arriving';
  const isReady  = status === 'Ready' || status === 'Completed';

  // ── SVG dimensions ────────────────────────────────────
  const w = 440;
  const h = mini ? 65 : 130;
  const padX = 50;
  const startX = padX;
  const endX = w - padX;
  const midY = h / 2 + (mini ? 4 : 12);
  const arcH = mini ? 10 : 30;

  const cpX = w / 2;
  const cpY = midY - arcH;
  const dPath = `M ${startX} ${midY} Q ${cpX} ${cpY} ${endX} ${midY}`;

  // ── Car position on bezier ────────────────────────────
  const t = Math.min(1, Math.max(0, progress / 100));
  const carPos = useMemo(() => {
    const x = (1 - t) * (1 - t) * startX + 2 * (1 - t) * t * cpX + t * t * endX;
    const y = (1 - t) * (1 - t) * midY   + 2 * (1 - t) * t * cpY + t * t * midY;
    return { x, y };
  }, [t, startX, endX, cpX, cpY, midY]);

  const tangentAngle = useMemo(() => {
    const dx = 2 * (1 - t) * (cpX - startX) + 2 * t * (endX - cpX);
    const dy = 2 * (1 - t) * (cpY - midY)   + 2 * t * (midY - cpY);
    return Math.atan2(dy, dx) * (180 / Math.PI);
  }, [t, startX, endX, cpX, cpY, midY]);

  const carScale = 1 + 0.3 * Math.sin(t * Math.PI);
  const pathLength = 460;
  const trailDash = pathLength * t;
  const uid = mini ? 'mini' : 'full';

  return (
    <div className={`relative w-full ${mini ? '' : ''}`}>
      {/* SVG Canvas */}
      <svg
        viewBox={`0 0 ${w} ${h}`}
        className="w-full relative z-10"
        style={{ height: mini ? 55 : 110 }}
      >
        <defs>
          {/* Route glow */}
          <filter id={`routeGlow-${uid}`} x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="5" result="blur" />
            <feComposite in="SourceGraphic" in2="blur" operator="over" />
          </filter>
          {/* Car shadow */}
          <filter id={`carShadow-${uid}`} x="-50%" y="-50%" width="200%" height="200%">
            <feDropShadow dx="0" dy="7" stdDeviation="4" floodOpacity="0.5" floodColor="#000" />
          </filter>
          {/* Headlight cone */}
          <filter id={`headlight-${uid}`} x="-100%" y="-100%" width="300%" height="300%">
            <feGaussianBlur stdDeviation="8" />
          </filter>
          {/* Destination pulse glow */}
          <filter id={`destGlow-${uid}`} x="-100%" y="-100%" width="300%" height="300%">
            <feGaussianBlur stdDeviation="6" />
          </filter>
          {/* Route gradient */}
          <linearGradient id={`routeGrad-${uid}`} x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stopColor="#6366F1" />
            <stop offset="50%" stopColor="#818CF8" />
            <stop offset="100%" stopColor="#22C55E" />
          </linearGradient>
        </defs>

        {/* Base dashed path */}
        <path
          d={dPath}
          fill="none"
          stroke="#1E293B"
          strokeWidth={mini ? 2.5 : 4}
          strokeLinecap="round"
          strokeDasharray="5 12"
        />

        {/* Traveled glow trail */}
        <path
          d={dPath}
          fill="none"
          stroke={`url(#routeGrad-${uid})`}
          strokeWidth={mini ? 4 : 7}
          strokeLinecap="round"
          filter={`url(#routeGlow-${uid})`}
          strokeDasharray={`${trailDash} ${pathLength}`}
          opacity="0.35"
          style={{ transition: 'stroke-dasharray 1s ease-out' }}
        />

        {/* Solid traveled path */}
        <path
          d={dPath}
          fill="none"
          stroke={`url(#routeGrad-${uid})`}
          strokeWidth={mini ? 2 : 3}
          strokeLinecap="round"
          strokeDasharray={`${trailDash} ${pathLength}`}
          opacity="0.6"
          style={{ transition: 'stroke-dasharray 1s ease-out' }}
        />

        {/* Source point (Parking) */}
        <circle cx={startX} cy={midY} r={mini ? 5 : 8} fill="#0A0F1E" stroke="#334155" strokeWidth="2" />
        <circle cx={startX} cy={midY} r={mini ? 2 : 3} fill="#64748B" />
        {!mini && (
          <text x={startX} y={midY + 22} textAnchor="middle" fill="#475569" fontSize="8" fontWeight="600" letterSpacing="0.1em">
            PARKING
          </text>
        )}

        {/* Destination point (Pickup) — pulsing */}
        {!isReady && (
          <>
            <circle cx={endX} cy={midY} r={mini ? 16 : 24} fill="#22C55E" opacity="0.06" filter={`url(#destGlow-${uid})`}>
              <animate attributeName="r" values={mini ? "12;20;12" : "16;28;16"} dur="2.5s" repeatCount="indefinite" />
              <animate attributeName="opacity" values="0.08;0.02;0.08" dur="2.5s" repeatCount="indefinite" />
            </circle>
            <circle cx={endX} cy={midY} r={mini ? 10 : 14} fill="#22C55E" opacity="0.04">
              <animate attributeName="r" values={mini ? "8;14;8" : "10;18;10"} dur="2s" repeatCount="indefinite" />
            </circle>
          </>
        )}
        <circle
          cx={endX} cy={midY}
          r={mini ? 5 : 8}
          fill={isReady ? '#22C55E' : '#064E3B'}
          stroke="#22C55E"
          strokeWidth={isReady ? 3 : 2}
        />
        {isReady && (
          <text x={endX} y={midY + 1} textAnchor="middle" dominantBaseline="central" fill="white" fontSize="8" fontWeight="bold">✓</text>
        )}
        {!mini && (
          <text x={endX} y={midY + 22} textAnchor="middle" fill="#475569" fontSize="8" fontWeight="600" letterSpacing="0.1em">
            PICKUP
          </text>
        )}

        {/* ── The Car ─────────────────────────────── */}
        <g
          style={{
            transform: `translate(${carPos.x}px, ${carPos.y}px) rotate(${tangentAngle}deg) scale(${carScale})`,
            transition: 'transform 1s cubic-bezier(0.25, 0.46, 0.45, 0.94)',
          }}
        >
          {/* Headlight beam */}
          {isMoving && !mini && (
            <ellipse cx="24" cy="0" rx="18" ry="6" fill="#93C5FD" opacity="0.08" filter={`url(#headlight-${uid})`} />
          )}

          {/* Ground shadow */}
          <ellipse cx="0" cy={mini ? 10 : 14} rx={mini ? 12 : 18} ry={mini ? 3 : 5} fill="black" opacity="0.4" />

          {/* Car body */}
          <g transform={`translate(${mini ? -12 : -16}, ${mini ? -8 : -12})`} filter={`url(#carShadow-${uid})`}>
            {/* Chassis */}
            <rect x="0" y={mini ? 5 : 7} width={mini ? 24 : 32} height={mini ? 9 : 13} rx="3" fill="#6366F1" />
            {/* Roof highlight */}
            <rect x={mini ? 2 : 3} y={mini ? 5 : 7} width={mini ? 20 : 26} height="2" rx="1" fill="#818CF8" opacity="0.4" />
            {/* Cabin */}
            <rect x={mini ? 5 : 7} y="0" width={mini ? 11 : 16} height={mini ? 7 : 9} rx="2" fill="#4F46E5" />
            {/* Windows */}
            <rect x={mini ? 7 : 9} y={mini ? 1 : 2} width={mini ? 4 : 6} height={mini ? 4 : 5} rx="1" fill="#A5B4FC" opacity="0.9" />
            <rect x={mini ? 12 : 16} y={mini ? 1 : 2} width={mini ? 3 : 5} height={mini ? 4 : 5} rx="1" fill="#A5B4FC" opacity="0.8" />
            {/* Wheels */}
            <circle cx={mini ? 5 : 7} cy={mini ? 14 : 20} r={mini ? 2.5 : 3.5} fill="#0F172A" />
            <circle cx={mini ? 5 : 7} cy={mini ? 14 : 20} r={mini ? 1 : 1.5} fill="#334155" />
            <circle cx={mini ? 19 : 25} cy={mini ? 14 : 20} r={mini ? 2.5 : 3.5} fill="#0F172A" />
            <circle cx={mini ? 19 : 25} cy={mini ? 14 : 20} r={mini ? 1 : 1.5} fill="#334155" />
            {/* Tail light */}
            {isMoving && <rect x="-1" y={mini ? 7 : 9} width="3" height={mini ? 3 : 5} rx="1" fill="#EF4444" opacity="0.9" />}
            {/* Headlight */}
            {isMoving && <rect x={mini ? 22 : 30} y={mini ? 7 : 9} width="3" height={mini ? 3 : 5} rx="1" fill="#FDE68A" opacity="0.95" />}
          </g>
        </g>
      </svg>
    </div>
  );
}
