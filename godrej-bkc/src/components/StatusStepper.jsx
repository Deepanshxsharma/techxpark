import React from 'react';
import { CheckCircle2, Clock, Settings, Car } from 'lucide-react';

const STEPS = [
  { id: 'queued', label: 'Queued', icon: Clock },
  { id: 'in_process', label: 'In Process', icon: Settings },
  { id: 'ready', label: 'Ready', icon: CheckCircle2 },
  { id: 'collected', label: 'Collected', icon: Car },
];

const STATUS_ORDER = ['queued', 'in_process', 'ready', 'collected'];

export default function StatusStepper({ currentStatus }) {
  const currentIndex = STATUS_ORDER.indexOf(currentStatus);
  const isReParked = currentStatus === 're_parked';

  return (
    <div className="flex items-center justify-between w-full max-w-md mx-auto px-2">
      {STEPS.map((step, index) => {
        const Icon = step.icon;
        const isCompleted = currentIndex > index;
        const isActive = currentIndex === index && !isReParked;
        const isPending = currentIndex < index || isReParked;

        return (
          <React.Fragment key={step.id}>
            {/* Step circle */}
            <div className="flex flex-col items-center gap-1.5 relative">
              <div
                className={`
                  w-10 h-10 rounded-full flex items-center justify-center transition-all duration-500
                  ${isCompleted
                    ? 'bg-primary-600 text-white shadow-glow-blue'
                    : isActive
                      ? 'bg-primary-600 text-white animate-ring shadow-glow-blue'
                      : 'bg-gray-100 text-gray-400 border-2 border-gray-200'
                  }
                `}
              >
                <Icon className="w-5 h-5" />
              </div>
              <span
                className={`text-[10px] font-medium ${
                  isCompleted || isActive ? 'text-primary-600' : 'text-gray-400'
                }`}
              >
                {step.label}
              </span>
            </div>

            {/* Connector line */}
            {index < STEPS.length - 1 && (
              <div className="flex-1 mx-1 mb-5">
                <div className="h-0.5 w-full relative rounded-full overflow-hidden bg-gray-200">
                  <div
                    className="absolute inset-y-0 left-0 bg-primary-600 rounded-full transition-all duration-700"
                    style={{
                      width: isCompleted ? '100%' : isActive ? '50%' : '0%',
                    }}
                  />
                </div>
              </div>
            )}
          </React.Fragment>
        );
      })}
    </div>
  );
}
