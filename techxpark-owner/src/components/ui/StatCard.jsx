import React, { useState, useEffect } from 'react';
import Card from './Card';
import { LineChart, Line, ResponsiveContainer } from 'recharts';

// Simple count up hook for the 1.2s animation
function useCountUp(endValue, duration = 1200) {
    const [value, setValue] = useState(0);

    useEffect(() => {
        let startTimestamp = null;
        let animationFrame;

        const easeOutExpo = (x) => {
            return x === 1 ? 1 : 1 - Math.pow(2, -10 * x);
        };

        const step = (timestamp) => {
            if (!startTimestamp) startTimestamp = timestamp;
            const progress = Math.min((timestamp - startTimestamp) / duration, 1);

            const easedProgress = easeOutExpo(progress);
            setValue(Math.floor(easedProgress * endValue));

            if (progress < 1) {
                animationFrame = window.requestAnimationFrame(step);
            } else {
                setValue(endValue); // Ensure it reaches exact value
            }
        };

        animationFrame = window.requestAnimationFrame(step);

        return () => window.cancelAnimationFrame(animationFrame);
    }, [endValue, duration]);

    return value;
}

export default function StatCard({
    title,
    value,
    icon: Icon,
    color = 'success', // success, error, info, warning
    trend,
    trendValue,
    sparklineData,
    subtitle
}) {
    const animatedValue = useCountUp(typeof value === 'number' ? value : parseInt(value) || 0);

    const colorStyles = {
        success: { bg: 'bg-success-bg', text: 'text-success', line: 'var(--color-success)' },
        error: { bg: 'bg-error-bg', text: 'text-error', line: 'var(--color-error)' },
        info: { bg: 'bg-info-bg', text: 'text-primary', line: 'var(--color-primary)' },
        warning: { bg: 'bg-orange-50', text: 'text-warning', line: 'var(--color-warning)' },
    };

    const style = colorStyles[color] || colorStyles.info;

    return (
        <Card hover padding="none" className="p-6 flex flex-col h-full bg-white border border-border rounded-[14px]">
            <div className="flex justify-between items-start mb-4">
                <div className="flex items-center gap-2">
                    {color === 'success' && <span className="flex w-2 h-2 rounded-full bg-success"></span>}
                    {color === 'error' && <span className="flex w-2 h-2 rounded-full bg-error"></span>}
                    {color === 'info' && <span className="flex w-2 h-2 rounded-full bg-primary"></span>}
                    {color === 'warning' && <span className="flex w-2 h-2 rounded-full bg-warning"></span>}
                    <h3 className="text-[13px] font-medium text-text-secondary">{title}</h3>
                </div>
                <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${style.bg} ${style.text}`}>
                    <Icon className="w-5 h-5" />
                </div>
            </div>

            <div className="flex justify-between items-end mb-4">
                <div className="text-[32px] font-extrabold tracking-[-1px] text-text-primary leading-none">
                    {typeof value === 'number' ? animatedValue : value}
                </div>
                {trend && (
                    <div className={`px-2 py-1 rounded-full text-xs font-medium flex items-center gap-1
            ${trend === 'up' ? 'bg-success-bg text-success-text' : 'bg-error-bg text-error-text'}
          `}>
                        {trend === 'up' ? '↑' : '↓'} {trendValue}
                    </div>
                )}
            </div>

            {sparklineData && sparklineData.length > 0 && (
                <div className="h-8 w-full mt-auto mb-2">
                    <ResponsiveContainer width="100%" height="100%">
                        <LineChart data={sparklineData}>
                            <Line
                                type="monotone"
                                dataKey="value"
                                stroke={style.line}
                                strokeWidth={1.5}
                                dot={false}
                                isAnimationActive={true}
                            />
                        </LineChart>
                    </ResponsiveContainer>
                </div>
            )}

            {subtitle && (
                <div className="text-xs text-text-tertiary mt-auto">
                    {subtitle}
                </div>
            )}
        </Card>
    );
}
