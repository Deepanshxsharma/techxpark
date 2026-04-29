import { Car, User, Clock, MapPin, ArrowRight, Play, CheckCircle2, RotateCcw, Loader2 } from 'lucide-react';
import CountdownTimer from './CountdownTimer';

const STATUS_CONFIG = {
  queued: { color: 'warning', label: 'QUEUED', dotColor: 'bg-warning-500' },
  in_process: { color: 'primary', label: 'IN PROCESS', dotColor: 'bg-primary-500' },
  ready: { color: 'success', label: 'READY', dotColor: 'bg-success-500' },
  collected: { color: 'success', label: 'COLLECTED', dotColor: 'bg-success-500' },
  re_parked: { color: 'error', label: 'RE-PARKED', dotColor: 'bg-error-500' },
};

export default function QueueCard({
  request,
  onStartProcessing,
  onMarkReady,
  onRePark,
  onCollect,
  showActions = true,
  compact = false,
}) {
  const config = STATUS_CONFIG[request.status] || STATUS_CONFIG.queued;
  const requestedTime = request.requestedAt?.toDate
    ? request.requestedAt.toDate()
    : request.requestedAt ? new Date(request.requestedAt) : null;
  const readyTime = request.estimatedReadyTime?.toDate
    ? request.estimatedReadyTime.toDate()
    : request.estimatedReadyTime ? new Date(request.estimatedReadyTime) : null;

  const formatTime = (date) => {
    if (!date) return '--';
    return date.toLocaleTimeString('en-IN', {
      hour: '2-digit',
      minute: '2-digit',
      hour12: true,
      timeZone: 'Asia/Kolkata',
    });
  };

  return (
    <div
      className={`
        card p-4 transition-all duration-300 hover:shadow-card-hover
        ${request.status === 'ready' ? 'border-l-4 border-l-success-500' : ''}
        ${request.status === 'in_process' ? 'border-l-4 border-l-primary-500' : ''}
        ${request.status === 'queued' ? 'border-l-4 border-l-warning-500' : ''}
      `}
    >
      <div className="flex items-start gap-4">
        {/* Queue Position */}
        {request.queuePosition && (
          <div className="flex-shrink-0 w-10 h-10 rounded-full bg-primary-600 text-white flex items-center justify-center font-bold text-sm">
            #{request.queuePosition}
          </div>
        )}

        {/* Content */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between gap-2 mb-1">
            <div className="flex items-center gap-2">
              <Car className="w-4 h-4 text-text-secondary" />
              <span className="font-bold text-base text-text-primary">
                {request.vehicleNumber}
              </span>
            </div>
            {/* Status Badge */}
            <div className={`badge badge-${config.color === 'primary' ? 'blue' : config.color === 'warning' ? 'amber' : config.color === 'success' ? 'green' : 'red'}`}>
              <span className={`w-1.5 h-1.5 rounded-full mr-1.5 ${config.dotColor} pulse-dot`} />
              {config.label}
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-text-secondary">
            <span className="flex items-center gap-1">
              <User className="w-3.5 h-3.5" />
              {request.employeeName}
            </span>
            {request.assignedLifterId && (
              <span className="flex items-center gap-1">
                <ArrowRight className="w-3.5 h-3.5" />
                {request.assignedLifterId.replace('lifter_b1_', 'Lifter ')}
              </span>
            )}
            <span className="flex items-center gap-1">
              <Clock className="w-3.5 h-3.5" />
              {formatTime(requestedTime)}
            </span>
          </div>

          {readyTime && request.status !== 'collected' && request.status !== 're_parked' && (
            <div className="mt-2 text-xs text-text-secondary">
              Ready by <span className="font-semibold text-primary-600">{formatTime(readyTime)}</span>
              {request.status === 'ready' && request.notCollectedDeadline && (
                <span className="ml-3">
                  <CountdownTimer
                    targetTime={request.notCollectedDeadline}
                    className="inline-flex flex-row gap-1"
                  />
                </span>
              )}
            </div>
          )}
        </div>

        {/* Actions */}
        {showActions && (
          <div className="flex-shrink-0 flex flex-col gap-2">
            {request.status === 'queued' && onStartProcessing && (
              <button
                onClick={() => onStartProcessing(request.id)}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-primary-50 text-primary-600 text-sm font-medium hover:bg-primary-100 transition-colors"
              >
                <Play className="w-3.5 h-3.5" />
                Start
              </button>
            )}
            {request.status === 'in_process' && onMarkReady && (
              <button
                onClick={() => onMarkReady(request.id)}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-success-50 text-success-600 text-sm font-medium hover:bg-success-100 transition-colors"
              >
                <CheckCircle2 className="w-3.5 h-3.5" />
                Ready
              </button>
            )}
            {request.status === 'ready' && onRePark && (
              <button
                onClick={() => onRePark(request.id)}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-error-50 text-error-600 text-sm font-medium hover:bg-error-100 transition-colors"
              >
                <RotateCcw className="w-3.5 h-3.5" />
                Re-Park
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
