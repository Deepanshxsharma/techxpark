import React, { useEffect } from 'react';
import { X } from 'lucide-react';

export default function Drawer({
    isOpen,
    onClose,
    title,
    children,
    footer
}) {
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

    return (
        <div className="fixed inset-0 z-50 overflow-hidden">
            {/* Backdrop */}
            <div
                className="absolute inset-0 bg-sidebar-bg/60 backdrop-blur-sm transition-opacity animate-fade-in"
                onClick={onClose}
            ></div>

            {/* Slide-over panel */}
            <div className="fixed inset-y-0 right-0 flex max-w-full pl-10">
                <div className="w-screen max-w-md transform transition-transform ease-in-out duration-300 animate-[slideInRight_0.3s_ease-out]">
                    <div className="flex h-full flex-col bg-white shadow-2xl border-l border-border">

                        {/* Header */}
                        <div className="flex items-center justify-between px-6 py-5 border-b border-border bg-surface">
                            <h2 className="text-xl font-bold text-text-primary tracking-tight">{title}</h2>
                            <button
                                type="button"
                                className="w-8 h-8 rounded-lg flex items-center justify-center text-text-tertiary hover:bg-bg-light hover:text-text-primary transition-colors focus:outline-none"
                                onClick={onClose}
                            >
                                <span className="sr-only">Close panel</span>
                                <X className="h-5 w-5" aria-hidden="true" />
                            </button>
                        </div>

                        {/* Content */}
                        <div className="relative flex-1 overflow-y-auto p-6 scrollbar-none">
                            {children}
                        </div>

                        {/* Footer */}
                        {footer && (
                            <div className="flex shrink-0 justify-end gap-3 px-6 py-5 border-t border-border bg-bg-light">
                                {footer}
                            </div>
                        )}

                    </div>
                </div>
            </div>
        </div>
    );
}
