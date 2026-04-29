import { Wrench, CheckCircle2, AlertTriangle, Loader2 } from 'lucide-react';

const STATUS_MAP = {
  idle: { label: 'IDLE', bg: 'bg-success-50', text: 'text-success-600', border: 'border-success-400', icon: CheckCircle2 },
  busy: { label: 'BUSY', bg: 'bg-primary-50', text: 'text-primary-600', border: 'border-primary-400', icon: Loader2 },
  breakdown: { label: 'BREAKDOWN', bg: 'bg-error-50', text: 'text-error-600', border: 'border-error-400', icon: AlertTriangle },
};

export default function LifterStatus({ lifter, onMarkBreakdown, onRestore }) {
  const config = STATUS_MAP[lifter.status] || STATUS_MAP.idle;
  const Icon = config.icon;

  return (
    <div
      className={`
        card p-4 w-48 border-2 ${config.border} transition-all duration-300
        hover:shadow-card-hover
      `}
    >
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <Wrench className="w-4 h-4 text-text-secondary" />
          <span className="font-bold text-sm">{lifter.name || lifter.displayName || lifter.id}</span>
        </div>
      </div>

      <div className={`badge ${config.bg} ${config.text} mb-3`}>
        <Icon className={`w-3 h-3 mr-1 ${lifter.status === 'busy' ? 'animate-spin' : ''}`} />
        {config.label}
      </div>

      {lifter.status === 'busy' && lifter.currentVehicle && (
        <p className="text-xs text-text-secondary mb-2">
          Processing: <span className="font-semibold">{lifter.currentVehicle}</span>
        </p>
      )}

      {lifter.breakdownNote && lifter.status === 'breakdown' && (
        <p className="text-xs text-error-500 mb-2">
          {lifter.breakdownNote}
        </p>
      )}

      <div className="mt-auto">
        {lifter.status !== 'breakdown' && onMarkBreakdown && (
          <button
            onClick={() => onMarkBreakdown(lifter.id)}
            className="w-full text-xs py-1.5 rounded-lg border border-error-200 text-error-500 hover:bg-error-50 transition-colors"
          >
            Mark Breakdown
          </button>
        )}
        {lifter.status === 'breakdown' && onRestore && (
          <button
            onClick={() => onRestore(lifter.id)}
            className="w-full text-xs py-1.5 rounded-lg border border-success-400 text-success-600 hover:bg-success-50 transition-colors"
          >
            Restore
          </button>
        )}
      </div>
    </div>
  );
}
