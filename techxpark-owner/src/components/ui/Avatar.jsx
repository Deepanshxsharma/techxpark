import React from 'react';

const sizes = {
    sm: 'w-8 h-8 text-xs',
    md: 'w-10 h-10 text-sm flex-shrink-0',
    lg: 'w-12 h-12 text-base',
};

export default function Avatar({ name, src, size = 'md', status, className = '' }) {
    const getInitials = (name) => {
        if (!name) return '??';
        const parts = name.trim().split(' ');
        if (parts.length >= 2) return `${parts[0][0]}${parts[1][0]}`.toUpperCase();
        return name.slice(0, 2).toUpperCase();
    };

    return (
        <div className={`relative inline-block ${className}`}>
            {src ? (
                <img src={src} alt={name} className={`${sizes[size]} rounded-[10px] object-cover`} />
            ) : (
                <div className={`${sizes[size]} rounded-[10px] bg-gradient-to-br from-primary to-primary-light flex items-center justify-center text-white font-semibold shadow-sm`}>
                    {getInitials(name)}
                </div>
            )}

            {status === 'online' && (
                <span className="absolute bottom-0 right-0 block h-2.5 w-2.5 rounded-full bg-success ring-2 ring-white translate-x-1/4 translate-y-1/4" />
            )}
            {status === 'offline' && (
                <span className="absolute bottom-0 right-0 block h-2.5 w-2.5 rounded-full bg-slate-300 ring-2 ring-white translate-x-1/4 translate-y-1/4" />
            )}
        </div>
    );
}
