import React from 'react';
import { Search } from 'lucide-react';
import Button from './Button';

export default function EmptyState({
    icon: Icon = Search,
    title = "No data found",
    subtitle = "We couldn't find any matching records.",
    actionLabel,
    onAction
}) {
    return (
        <div className="flex flex-col items-center justify-center p-12 text-center h-full">
            <div className="w-16 h-16 bg-surface-2 text-text-tertiary rounded-full flex items-center justify-center mb-4 border border-border">
                <Icon className="w-8 h-8" />
            </div>
            <h3 className="text-base font-semibold text-text-primary mb-1">{title}</h3>
            <p className="text-sm text-text-secondary max-w-sm mb-6 leading-relaxed">
                {subtitle}
            </p>
            {actionLabel && onAction && (
                <Button variant="secondary" onClick={onAction}>
                    {actionLabel}
                </Button>
            )}
        </div>
    );
}
