import { TrendingUp, TrendingDown } from 'lucide-react';

export default function StatsCard({ value, label, icon: Icon, color = 'primary', trend, className = '' }) {
  const colorMap = {
    primary: 'from-primary-500 to-primary-700',
    success: 'from-success-400 to-success-600',
    warning: 'from-warning-400 to-warning-600',
    error: 'from-error-400 to-error-600',
    cyan: 'from-cyan-400 to-cyan-600',
  };
  const bgMap = {
    primary: 'bg-primary-50',
    success: 'bg-success-50',
    warning: 'bg-warning-50',
    error: 'bg-error-50',
    cyan: 'bg-cyan-50',
  };
  const iconColorMap = {
    primary: 'text-primary-600',
    success: 'text-success-600',
    warning: 'text-warning-600',
    error: 'text-error-600',
    cyan: 'text-cyan-600',
  };

  return (
    <div className={`card p-5 relative overflow-hidden group hover:shadow-card-hover transition-all duration-300 ${className}`}>
      {/* Gradient accent bar */}
      <div className={`absolute top-0 left-0 right-0 h-1 bg-gradient-to-r ${colorMap[color]}`} />

      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm font-medium text-text-secondary mb-1">{label}</p>
          <p className="text-3xl font-bold text-text-primary">{value}</p>
          {trend !== undefined && (
            <div className={`flex items-center gap-1 mt-1 text-xs font-medium ${trend >= 0 ? 'text-success-600' : 'text-error-500'}`}>
              {trend >= 0 ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />}
              {Math.abs(trend)}%
            </div>
          )}
        </div>
        {Icon && (
          <div className={`w-11 h-11 rounded-xl ${bgMap[color]} flex items-center justify-center group-hover:scale-110 transition-transform`}>
            <Icon className={`w-5 h-5 ${iconColorMap[color]}`} />
          </div>
        )}
      </div>
    </div>
  );
}
