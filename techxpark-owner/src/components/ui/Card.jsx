import React from 'react';

const paddings = {
    none: 'p-0',
    sm: 'p-4',
    md: 'p-6',
    lg: 'p-8',
};

export default function Card({
    padding = 'md',
    hover = false,
    clickable = false,
    className = '',
    children,
    ...props
}) {
    return (
        <div
            className={`bg-surface border border-border rounded-[14px] shadow-sm ${paddings[padding]} ${hover ? 'transition-all duration-200 hover:shadow-md hover:-translate-y-[1px]' : ''} ${clickable ? 'cursor-pointer active:scale-[0.98]' : ''} ${className}`}
            {...props}
        >
            {children}
        </div>
    );
}
