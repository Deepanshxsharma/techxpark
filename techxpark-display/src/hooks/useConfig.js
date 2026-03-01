import { useMemo } from 'react';
import { useSearchParams } from 'react-router-dom';

/** Parse URL query params into a config object */
export default function useConfig() {
  const [params] = useSearchParams();
  return useMemo(() => ({
    lotId:      params.get('lot') || null,
    mode:       params.get('mode') || 'indoor',
    floor:      params.get('floor') || 'all',
    cycle:      params.get('cycle') !== 'false',
    cycleTime:  parseInt(params.get('cycle_time') || '15', 10),
    theme:      params.get('theme') || 'auto',
    ticker:     params.get('ticker') !== 'false',
    qr:         params.get('qr') !== 'false',
    weather:    params.get('weather') !== 'false',
    brightness: parseInt(params.get('brightness') || '100', 10),
    v1:         parseInt(params.get('v1') || '5', 10),
    v2:         parseInt(params.get('v2') || '5', 10),
    v3:         parseInt(params.get('v3') || '5', 10),
    transition: params.get('transition') || 'fade',
  }), [params]);
}
