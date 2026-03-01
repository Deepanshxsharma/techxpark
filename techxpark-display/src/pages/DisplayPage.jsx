import useConfig from '../hooks/useConfig';
import useTheme from '../hooks/useTheme';
import useLotData from '../hooks/useLotData';
import useAntiBurn from '../hooks/useAntiBurn';
import IndoorDisplay from '../components/IndoorDisplay';
import OutdoorDisplay from '../components/OutdoorDisplay';
import SetupScreen from '../components/SetupScreen';

export default function DisplayPage() {
    const cfg = useConfig();
    useTheme(cfg.mode === 'outdoor' ? 'dark' : cfg.theme);
    const data = useLotData(cfg.lotId);
    const { shift, isDimmed } = useAntiBurn();

    if (!cfg.lotId) return <SetupScreen />;
    if (data.loading) return <LoadingScreen />;

    const style = {
        transform: `translate(${shift.x}px, ${shift.y}px)`,
        filter: isDimmed ? 'brightness(0.4)' : `brightness(${cfg.brightness / 100})`,
        transition: 'transform 2s ease, filter 5s ease',
    };

    return (
        <div className="pixel-shift w-screen h-screen" style={style}>
            {cfg.mode === 'outdoor'
                ? <OutdoorDisplay cfg={cfg} data={data} />
                : <IndoorDisplay cfg={cfg} data={data} />}
            {data.offline && <OfflineBanner />}
        </div>
    );
}

function LoadingScreen() {
    return (
        <div className="w-screen h-screen flex items-center justify-center" style={{ background: 'var(--bg)' }}>
            <div className="text-center">
                <div className="text-6xl mb-4">🅿️</div>
                <div className="font-mono text-xl font-bold" style={{ color: 'var(--text-primary)' }}>TechXPark Display</div>
                <div className="mt-2 text-sm" style={{ color: 'var(--text-secondary)' }}>Connecting to live data…</div>
                <div className="mt-6 w-48 h-1 bg-gray-200 rounded-full overflow-hidden mx-auto">
                    <div className="h-full bg-primary rounded-full animate-pulse" style={{ width: '60%' }} />
                </div>
            </div>
        </div>
    );
}

function OfflineBanner() {
    return (
        <div className="fixed bottom-4 left-4 flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold"
            style={{ background: 'rgba(245,158,11,0.9)', color: '#fff', zIndex: 100 }}>
            <span>⚠️</span> Connection lost — showing cached data
        </div>
    );
}
