import React, { useState, useEffect } from 'react';
import { Wifi, WifiOff, MapPin, Activity, Search, RefreshCcw, Loader2 } from 'lucide-react';
import { db } from '../firebase';
import { collection, getDocs, getDoc, doc } from 'firebase/firestore';
import { ref, onValue } from 'firebase/database';
import { rtdb } from '../firebase';
import Card from '../components/ui/Card';
import Button from '../components/ui/Button';
import Badge from '../components/ui/Badge';

export default function Sensors() {
    const [sensors, setSensors] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [stats, setStats] = useState({ total: 0, online: 0, offline: 0, lowBattery: 0 });
    const [lotMap, setLotMap] = useState({});
    const [lotFilter, setLotFilter] = useState('all');

    // Fetch lot names once so we can map sensor IDs to real lot names
    useEffect(() => {
        const fetchLots = async () => {
            try {
                const lotsSnap = await getDocs(collection(db, 'parking_locations'));
                const map = {};
                lotsSnap.docs.forEach(d => {
                    map[d.id] = d.data().name || 'Unnamed Lot';
                });
                setLotMap(map);
            } catch (e) {
                console.error('Failed to fetch lots for sensors:', e);
            }
        };
        fetchLots();
    }, []);

    useEffect(() => {
        const sensorsRef = ref(rtdb, 'sensor_slots');
        const unsubscribe = onValue(sensorsRef, (snapshot) => {
            const data = snapshot.val() || {};
            const arr = [];
            let onlineCount = 0;
            let offlineCount = 0;
            let lowBattCount = 0;
            const now = Date.now();

            Object.keys(data).forEach(sensorId => {
                const s = data[sensorId];
                const isOffline = (now - (s.lastPing || 0)) > 60000;
                // Use actual battery value from RTDB, default to 100 if not present
                const battery = typeof s.battery === 'number' ? s.battery : 100;
                // Use actual signal from RTDB, default to -50 if not present
                const signal = typeof s.signal === 'number' ? s.signal : -50;

                if (isOffline) offlineCount++; else onlineCount++;
                if (battery < 20) lowBattCount++;

                // Parse sensor ID to get lot and slot info
                // Sensor IDs may be structured as "lotId_slotId" or similar
                const parts = sensorId.split('_');
                const lotId = s.lotId || s.parkingLocationId || (parts.length > 1 ? parts[0] : '');
                const slotId = s.slotId || s.bay || (parts.length > 1 ? parts.slice(1).join('_') : sensorId);

                arr.push({
                    id: sensorId,
                    taken: s.taken || false,
                    battery: battery,
                    signal: signal,
                    lastPing: s.lastPing,
                    isOffline: isOffline,
                    lotId: lotId,
                    lotName: lotMap[lotId] || (lotId ? `Lot ${lotId.substring(0, 6)}` : 'Unknown'),
                    bay: slotId
                });
            });

            setStats({ total: arr.length, online: onlineCount, offline: offlineCount, lowBattery: lowBattCount });
            setSensors(arr);
            setLoading(false);
        });

        return () => unsubscribe();
    }, [lotMap]);

    // Get unique lot names for filter
    const uniqueLots = [...new Set(sensors.map(s => s.lotName))].sort();

    const filteredSensors = sensors.filter(s => {
        const matchSearch = s.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
            s.lotName.toLowerCase().includes(searchTerm.toLowerCase());
        if (!matchSearch) return false;
        if (lotFilter !== 'all' && s.lotName !== lotFilter) return false;
        return true;
    });

    if (loading) {
        return (
            <div className="h-[60vh] flex items-center justify-center">
                <Loader2 className="w-8 h-8 text-primary animate-spin" />
            </div>
        );
    }

    return (
        <div className="space-y-6 animate-fade-in pb-10">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-text-primary tracking-tight">Hardware Sensors</h1>
                    <p className="text-sm font-medium text-text-secondary mt-1">Platform-wide IoT device health and connectivity.</p>
                </div>
            </div>

            {stats.offline > 0 && (
                <div className="bg-error-bg border border-error/30 rounded-2xl p-4 flex items-start gap-4 animate-scale-in">
                    <div className="w-10 h-10 rounded-full bg-error flex items-center justify-center text-white shrink-0 mt-0.5 shadow-sm">
                        <WifiOff className="w-5 h-5" />
                    </div>
                    <div className="flex-1">
                        <h3 className="text-[15px] font-bold text-error mb-1">Attention Required: {stats.offline} Sensors Offline</h3>
                        <p className="text-sm font-medium text-error-text leading-relaxed max-w-2xl">
                            {stats.offline} parking sensors have not pinged the server in the last 60 seconds. This may cause inaccurate availability data for customers.
                        </p>
                    </div>
                </div>
            )}

            {/* Stats Overview */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <Card className="bg-surface">
                    <p className="text-[12px] font-bold text-text-tertiary uppercase tracking-wider mb-1">Total Deployed</p>
                    <h2 className="text-3xl font-extrabold text-text-primary">{stats.total}</h2>
                </Card>
                <Card className="bg-surface relative overflow-hidden">
                    <div className="absolute top-0 right-0 w-16 h-16 bg-success/10 rounded-bl-full border-b border-l border-success/20"></div>
                    <p className="text-[12px] font-bold text-text-tertiary uppercase tracking-wider mb-1">Online (Syncing)</p>
                    <h2 className="text-3xl font-extrabold text-success">{stats.online}</h2>
                </Card>
                <Card className="bg-surface relative overflow-hidden">
                    <div className="absolute top-0 right-0 w-16 h-16 bg-error/10 rounded-bl-full border-b border-l border-error/20"></div>
                    <p className="text-[12px] font-bold text-text-tertiary uppercase tracking-wider mb-1">Offline Nodes</p>
                    <h2 className="text-3xl font-extrabold text-error">{stats.offline}</h2>
                </Card>
                <Card className="bg-surface relative overflow-hidden">
                    <div className="absolute top-0 right-0 w-16 h-16 bg-warning/10 rounded-bl-full border-b border-l border-warning/20"></div>
                    <p className="text-[12px] font-bold text-text-tertiary uppercase tracking-wider mb-1">Low Battery (&lt;20%)</p>
                    <h2 className="text-3xl font-extrabold text-warning">{stats.lowBattery}</h2>
                </Card>
            </div>

            {/* Main Grid */}
            <Card className="bg-surface p-0 flex flex-col">
                <div className="p-5 border-b border-border flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                    <h3 className="font-bold text-text-primary inline-flex items-center gap-2">
                        <Activity className="w-5 h-5 text-primary" />
                        Live Sensor Fleet
                    </h3>
                    <div className="flex items-center gap-3">
                        {uniqueLots.length > 1 && (
                            <select
                                value={lotFilter}
                                onChange={(e) => setLotFilter(e.target.value)}
                                className="px-3 py-2 bg-bg-light border border-border rounded-lg text-sm font-medium focus:outline-none focus:border-primary"
                            >
                                <option value="all">All Lots</option>
                                {uniqueLots.map(name => (
                                    <option key={name} value={name}>{name}</option>
                                ))}
                            </select>
                        )}
                        <div className="relative max-w-sm w-full">
                            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-text-tertiary" />
                            <input
                                type="text"
                                placeholder="Find by ID or Lot..."
                                value={searchTerm}
                                onChange={(e) => setSearchTerm(e.target.value)}
                                className="w-full pl-10 pr-4 py-2 bg-bg-light border border-border rounded-lg text-sm font-medium focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all"
                            />
                        </div>
                    </div>
                </div>

                <div className="overflow-x-auto">
                    <table className="w-full text-left border-collapse">
                        <thead>
                            <tr className="bg-bg-light/50 border-b border-border">
                                <th className="py-3 px-6 text-[11px] font-bold text-text-secondary uppercase tracking-wider">Sensor ID</th>
                                <th className="py-3 px-6 text-[11px] font-bold text-text-secondary uppercase tracking-wider">Location</th>
                                <th className="py-3 px-6 text-[11px] font-bold text-text-secondary uppercase tracking-wider">State</th>
                                <th className="py-3 px-6 text-[11px] font-bold text-text-secondary uppercase tracking-wider">Battery</th>
                                <th className="py-3 px-6 text-[11px] font-bold text-text-secondary uppercase tracking-wider">Signal</th>
                                <th className="py-3 px-6 text-[11px] font-bold text-text-secondary uppercase tracking-wider">Last Ping</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-border">
                            {filteredSensors.length === 0 ? (
                                <tr>
                                    <td colSpan={6} className="py-12 text-center text-text-secondary text-sm">No sensors matching query.</td>
                                </tr>
                            ) : (
                                filteredSensors.map(sensor => (
                                    <tr key={sensor.id} className="hover:bg-bg-light/30 transition-colors">
                                        <td className="py-3.5 px-6">
                                            <div className="flex items-center gap-2">
                                                {sensor.isOffline ? (
                                                    <WifiOff className="w-4 h-4 text-error" />
                                                ) : (
                                                    <Wifi className="w-4 h-4 text-success" />
                                                )}
                                                <span className="font-mono font-bold text-[13px] text-text-primary">{sensor.id}</span>
                                            </div>
                                        </td>
                                        <td className="py-3.5 px-6">
                                            <div className="flex flex-col">
                                                <span className="font-bold text-text-primary text-[13px]">{sensor.lotName}</span>
                                                <span className="text-[11px] font-medium text-text-secondary flex items-center gap-1">
                                                    <MapPin className="w-3 h-3" /> {sensor.bay}
                                                </span>
                                            </div>
                                        </td>
                                        <td className="py-3.5 px-6">
                                            <Badge variant={sensor.taken ? 'error' : 'success'}>
                                                {sensor.taken ? 'Occupied' : 'Vacant'}
                                            </Badge>
                                        </td>
                                        <td className="py-3.5 px-6">
                                            <div className="flex items-center gap-2 w-24">
                                                <div className={`text-[12px] font-bold ${sensor.battery < 20 ? 'text-error' : 'text-text-primary'}`}>
                                                    {sensor.battery}%
                                                </div>
                                                <div className="flex-1 h-1.5 bg-border rounded-full overflow-hidden">
                                                    <div
                                                        className={`h-full rounded-full ${sensor.battery < 20 ? 'bg-error' : sensor.battery < 50 ? 'bg-warning' : 'bg-success'}`}
                                                        style={{ width: `${sensor.battery}%` }}
                                                    ></div>
                                                </div>
                                            </div>
                                        </td>
                                        <td className="py-3.5 px-6">
                                            <span className="font-mono text-[12px] font-semibold text-text-secondary">{sensor.signal} dBm</span>
                                        </td>
                                        <td className="py-3.5 px-6 text-[12px] font-medium text-text-secondary">
                                            {sensor.lastPing ? new Date(sensor.lastPing).toLocaleTimeString() : 'Never'}
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
            </Card>
        </div>
    );
}
