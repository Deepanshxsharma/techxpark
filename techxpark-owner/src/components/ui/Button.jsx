import React from 'react';

const variants = {
    primary: 'bg-primary text-white hover:bg-primary-dark shadow-primary',
    secondary: 'bg-white text-text-primary border border-border hover:bg-surface-hover shadow-xs',
    ghost: 'bg-transparent text-text-secondary hover:bg-sidebar-hover hover:text-text-primary',
    danger: 'bg-error text-white hover:bg-red-700 shadow-sm',
};

const sizes = {
    sm: 'px-3 py-1.5 text-xs rounded-sm',
    md: 'px-4 py-2 text-sm rounded-md',
    lg: 'px-6 py-3 text-base rounded-lg',
};

export default function Button({
    variant = 'primary',
    size = 'md',
    loading = false,
    icon: Icon,
    children,
    className = '',
    disabled,
    ...props
}) {
    const baseStyle = 'inline-flex items-center justify-center font-medium transition-all duration-100 active:scale-[0.97] disabled:opacity-50 disabled:pointer-events-none';

    return (
        <button
            className={`${baseStyle} ${variants[variant]} ${sizes[size]} ${className}`}
            disabled={disabled || loading}
            {...props}
        >
            {loading && (
                <svg className="animate-spin -ml-1 mr-2 h-4 w-4 currentColor" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
            )}
            {!loading && Icon && <Icon className={`mr-2 ${size === 'sm' ? 'w-4 h-4' : 'w-5 h-5'}`} />}
            {children}
        </button>
    );
}
