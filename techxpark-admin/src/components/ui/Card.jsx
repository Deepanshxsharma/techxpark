import React from 'react';

export default function Card({
    children,
    className = '',
    padding = 'p-6',
    onClick,
    hover = false
}) {
    const Component = onClick ? 'button' : 'div';

    return (
        <Component
            onClick={onClick}
            className={`
                bg-surface 
                rounded-2xl 
                border 
                border-border 
                shadow-sm 
                ${padding}
                ${hover ? 'transition-all duration-200 hover:shadow-md hover:border-[#D1D5DB] cursor-pointer' : ''}
                ${onClick ? 'text-left w-full focus:outline-none focus:ring-2 focus:ring-primary/50' : ''}
                ${className}
            `}
        >
            {children}
        </Component>
    );
}
