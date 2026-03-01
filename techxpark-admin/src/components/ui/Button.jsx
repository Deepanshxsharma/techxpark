import React from 'react';
import { Loader2 } from 'lucide-react';

export default function Button({
    children,
    variant = 'primary',
    className = '',
    loading = false,
    icon: Icon,
    ...props
}) {
    const baseClasses = "relative flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl font-bold text-[14px] transition-all duration-200 outline-none select-none disabled:opacity-50 disabled:cursor-not-allowed overflow-hidden active:scale-[0.98]";

    const variants = {
        primary: "bg-primary text-white shadow-[0_4px_14px_0_rgba(40,69,214,0.3)] hover:bg-primary-dark hover:shadow-[0_6px_20px_rgba(40,69,214,0.23)]",
        secondary: "bg-surface text-text-primary border border-border hover:bg-bg-light hover:border-[#D1D5DB] shadow-sm",
        danger: "bg-error text-white shadow-[0_4px_14px_0_rgba(229,57,59,0.3)] hover:bg-[#C92A2A]",
        ghost: "bg-transparent text-text-secondary hover:bg-surface-hover hover:text-text-primary",
    };

    return (
        <button
            className={`${baseClasses} ${variants[variant]} ${className}`}
            disabled={loading || props.disabled}
            {...props}
        >
            {loading && <Loader2 className="w-4 h-4 animate-spin shrink-0 absolute left-4" />}
            {Icon && !loading && <Icon className="w-4 h-4 shrink-0 opacity-80" strokeWidth={2.5} />}
            <span className={loading ? "opacity-0" : ""}>{children}</span>
        </button>
    );
}
