import React from 'react';

export default function SkeletonLoader({
    rows = 1,
    height = 'h-4',
    className = ''
}) {
    return (
        <div className={`space-y-3 w-full ${className}`}>
            {Array.from({ length: rows }).map((_, i) => (
                <div
                    key={i}
                    className={`w-full bg-slate-200 rounded animate-[pulse_1.5s_ease-in-out_infinite] ${height}`}
                    style={{ opacity: 1 - (i * 0.15) }} // Fade out each subsequent row slightly
                ></div>
            ))}
        </div>
    );
}
