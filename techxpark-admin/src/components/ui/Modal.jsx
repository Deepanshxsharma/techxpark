import React, { useEffect } from 'react';
import { X } from 'lucide-react';

export default function Modal({
    isOpen,
    onClose,
    title,
    children,
    size = 'md',
    footer
}) {
    // Prevent body scroll when open
    useEffect(() => {
        if (isOpen) {
            document.body.style.overflow = 'hidden';
        } else {
            document.body.style.overflow = 'unset';
        }
        return () => {
            document.body.style.overflow = 'unset';
        };
    }, [isOpen]);

    if (!isOpen) return null;

    const sizeClasses = {
        sm: 'max-w-md',
        md: 'max-w-xl',
        lg: 'max-w-3xl',
        xl: 'max-w-5xl'
    };

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6">
            {/* Backdrop */}
            <div
                className="absolute inset-0 bg-sidebar-bg/60 backdrop-blur-sm transition-opacity"
                onClick={onClose}
            ></div>

            {/* Modal Panel */}
            <div className={`relative w-full ${sizeClasses[size]} bg-white rounded-2xl shadow-[0_20px_60px_-15px_rgba(0,0,0,0.3)] border border-border flex flex-col max-h-[90vh] overflow-hidden animate-scale-in`}>

                {/* Header */}
                <div className="flex flex-shrink-0 items-center justify-between p-5 sm:p-6 border-b border-border bg-surface">
                    <h2 className="text-xl font-bold text-text-primary tracking-tight">{title}</h2>
                    <button
                        onClick={onClose}
                        className="w-8 h-8 rounded-lg flex items-center justify-center text-text-tertiary hover:bg-bg-light hover:text-text-primary transition-colors"
                    >
                        <X className="w-5 h-5" />
                    </button>
                </div>

                {/* Body */}
                <div className="flex-1 overflow-y-auto p-5 sm:p-6 scrollbar-none">
                    {children}
                </div>

                {/* Footer */}
                {footer && (
                    <div className="flex flex-shrink-0 items-center justify-end gap-3 p-5 sm:p-6 border-t border-border bg-bg-light">
                        {footer}
                    </div>
                )}

            </div>
        </div>
    );
}
