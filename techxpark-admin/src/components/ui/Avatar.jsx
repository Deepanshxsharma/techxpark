import React from 'react';

export default function Avatar({
    name = '',
    src,
    size = 'md',
    status = null,
    className = ''
}) {
    const initials = name ? name.substring(0, 2).toUpperCase() : '?';

    // Hash string to pick a predictable gradient color for letters
    let hash = 0;
    for (let i = 0; i < name.length; i++) {
        hash = name.charCodeAt(i) + ((hash << 5) - hash);
    }
    const colorIndex = Math.abs(hash) % 5;

    const gradients = [
        'from-blue-500 to-indigo-600',
        'from-emerald-400 to-teal-500',
        'from-rose-400 to-red-500',
        'from-amber-400 to-orange-500',
        'from-purple-500 to-fuchsia-600',
        'from-yellow-400 to-amber-600' // Gold gradient for Super Admin (index 5)
    ];

    const isSuperAdmin = name.toLowerCase() === 'super admin';
    const bgGradient = isSuperAdmin ? gradients[5] : gradients[colorIndex];

    const sizeClasses = {
        sm: 'w-8 h-8 text-[11px]',
        md: 'w-10 h-10 text-[14px]',
        lg: 'w-14 h-14 text-[18px]',
        xl: 'w-20 h-20 text-[24px]',
    };

    const statusColors = {
        online: 'bg-success',
        offline: 'bg-text-tertiary',
        busy: 'bg-error',
        away: 'bg-warning',
    };

    return (
        <div className={`relative inline-block ${className}`}>
            <div className={`${sizeClasses[size]} rounded-full flex items-center justify-center font-bold text-white shadow-sm border border-black/5 bg-gradient-to-br ${bgGradient} overflow-hidden`}>
                {src ? (
                    <img src={src} alt={name} className="w-full h-full object-cover" />
                ) : (
                    <span>{initials}</span>
                )}
            </div>

            {status && (
                <div className={`absolute bottom-0 right-0 w-[25%] h-[25%] rounded-full border-2 border-white ${statusColors[status]}`}></div>
            )}
        </div>
    );
}
