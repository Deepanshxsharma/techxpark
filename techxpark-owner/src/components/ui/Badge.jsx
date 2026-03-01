import React from 'react';

const variantStyles = {
    success: 'bg-success-bg text-success-text',
    error: 'bg-error-bg text-error-text',
    warning: 'bg-warning-bg text-warning-text',
    info: 'bg-info-bg text-info-text',
    neutral: 'bg-slate-100 text-slate-600',
};

const dotColors = {
    success: 'bg-success',
    error: 'bg-error',
    warning: 'bg-warning',
    info: 'bg-info',
    neutral: 'bg-slate-400',
};

export default function Badge({
    variant = 'neutral',
    dot = false,
    pulse = false,
    children,
    className = ''
}) {
    return (
        <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[11px] uppercase tracking-[0.8px] font-semibold ${variantStyles[variant] || variantStyles.neutral} ${className}`}>
            {dot && (
                <span className="relative flex h-1.5 w-1.5">
                    {pulse && (
                        <span className={`animate-ping absolute inline-flex h-full w-full rounded-full opacity-75 ${dotColors[variant]}`}></span>
                    )}
                    <span className={`relative inline-flex rounded-full h-1.5 w-1.5 ${dotColors[variant]}`}></span>
                </span>
            )}
            {children}
        </span>
    );
}
