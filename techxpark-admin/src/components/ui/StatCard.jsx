import React from 'react';
import Card from './Card';
import { AreaChart, Area, ResponsiveContainer } from 'recharts';

export default function StatCard({
    title,
    value,
    subtitle,
    icon: Icon,
    trend,
    trendLabel,
    sparklineData,
    className = ''
}) {
    const isPositive = trend > 0;
    const isNegative = trend < 0;

    return (
        <Card className={`relative overflow-hidden group ${className}`}>
            <div className="flex justify-between items-start mb-4">
                <div>
                    <h3 className="text-text-secondary font-semibold text-[13px] mb-1">{title}</h3>
                    <div className="text-[28px] font-extrabold text-text-primary tracking-tight leading-none mb-2">
                        {value}
                    </div>
                </div>

                {Icon && (
                    <div className="w-10 h-10 rounded-xl bg-bg-light border border-border flex items-center justify-center text-text-secondary group-hover:bg-info-bg group-hover:text-primary transition-colors">
                        <Icon className="w-5 h-5" />
                    </div>
                )}
            </div>

            <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                    {trend !== undefined && (
                        <div className={`flex items-center text-[12px] font-bold px-1.5 py-0.5 rounded-md ${isPositive ? 'bg-success-bg text-success' :
                                isNegative ? 'bg-error-bg text-error' :
                                    'bg-surface-hover text-text-secondary'
                            }`}>
                            {isPositive ? '+' : ''}{trend}%
                        </div>
                    )}
                    {(subtitle || trendLabel) && (
                        <span className="text-[12px] text-text-tertiary font-medium">
                            {trendLabel || subtitle}
                        </span>
                    )}
                </div>
            </div>

            {/* Sparkline overlay at the bottom */}
            {sparklineData && sparklineData.length > 0 && (
                <div className="absolute bottom-0 left-0 right-0 h-12 opacity-20 pointer-events-none">
                    <ResponsiveContainer width="100%" height="100%">
                        <AreaChart data={sparklineData}>
                            <defs>
                                <linearGradient id="colorAvg" x1="0" y1="0" x2="0" y2="1">
                                    <stop offset="5%" stopColor={isNegative ? '#E5393B' : '#2845D6'} stopOpacity={0.8} />
                                    <stop offset="95%" stopColor={isNegative ? '#E5393B' : '#2845D6'} stopOpacity={0} />
                                </linearGradient>
                            </defs>
                            <Area
                                type="monotone"
                                dataKey="value"
                                stroke={isNegative ? '#E5393B' : '#2845D6'}
                                fillOpacity={1}
                                fill="url(#colorAvg)"
                                strokeWidth={2}
                            />
                        </AreaChart>
                    </ResponsiveContainer>
                </div>
            )}
        </Card>
    );
}
