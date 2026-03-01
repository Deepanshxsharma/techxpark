import React from 'react';

export default function Badge({
    children,
    variant = 'neutral',
    dot = false,
    pulse = false,
    className = ''
}) {
    const variants = {
        success: 'bg-success-bg text-success-text border-success/20',
        error: 'bg-error-bg text-error-text border-error/20',
        warning: 'bg-warning-bg text-warning border-warning/20',
        info: 'bg-info-bg text-primary border-primary/20',
        neutral: 'bg-surface-hover text-text-secondary border-border',
    };

    const dotColors = {
        success: 'bg-success',
        error: 'bg-error',
        warning: 'bg-warning',
        info: 'bg-primary',
        neutral: 'bg-text-tertiary',
    };

    return (
        <div className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md border text-[12px] font-bold uppercase tracking-[0.5px] ${variants[variant]} ${className}`}>
            {dot && (
                <span className="relative flex h-2 w-2">
                    {pulse && (
                        <span className={`animate-ping absolute inline-flex h-full w-full rounded-full opacity-75 ${dotColors[variant]}`}></span>
                    )}
                    <span className={`relative inline-flex rounded-full h-2 w-2 ${dotColors[variant]}`}></span>
                </span>
            )}
            {children}
        </div>
    );
}
