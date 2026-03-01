import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { useSlots } from '../hooks/useSlots';
import { useSensors } from '../hooks/useSensors';
import { toast } from 'react-hot-toast';
import { RadioTower, AlertTriangle, BatteryWarning, Wifi, Cpu, Loader2, CheckCircle2, Search, SearchCode, XCircle } from 'lucide-react';
import { useSearchParams } from 'react-router-dom';

import StatCard from '../components/ui/StatCard';
import DataTable from '../components/ui/DataTable';
import Badge from '../components/ui/Badge';
import Button from '../components/ui/Button';

export default function SensorManager() {
    const { ownerData } = useAuth();
    const lotId = ownerData?.assignedLotId;
    const { slots } = useSlots(lotId);
    const { pingSensor, linkSensorToSlot, unlinkSensor, loading: sensorLoading } = useSensors(lotId);

    const [searchParams, setSearchParams] = useSearchParams();
    const initialTab = searchParams.get('tab') || 'health';
    const [activeTab, setActiveTab] = useState(initialTab);

    useEffect(() => {
        if (searchParams.get('tab')) {
            setActiveTab(searchParams.get('tab'));
        }
    }, [searchParams]);

    const setTab = (tab) => {
        setActiveTab(tab);
        setSearchParams({ tab });
    };

    // CONNECT TAB STATE
    const [connectStep, setConnectStep] = useState(1);
    const [selectedSlotForSensor, setSelectedSlotForSensor] = useState(null);
    const [inputSensorId, setInputSensorId] = useState('');

    useEffect(() => {
        const slotIdFromUrl = searchParams.get('slot');
        if (slotIdFromUrl && slots.length > 0) {
            const slot = slots.find(s => s.id === slotIdFromUrl);
            if (slot) {
                setSelectedSlotForSensor(slot);
                setConnectStep(2);
                setTab('connect');
            }
        }
    }, [searchParams, slots]);

    // HEALTH TAB STATE
    const sensorsList = slots.filter(s => s.sensorId).map(s => {
        // Mocking RTDB live states for the UI structure
        return {
            ...s,
            status: 'online',
            battery: 85,
            signal: 92,
            lastPing: new Date()
        }
    });

    const onlineCount = sensorsList.filter(s => s.status === 'online').length;
    const offlineCount = sensorsList.filter(s => s.status === 'offline').length;
    const errorCount = sensorsList.filter(s => s.status === 'error').length;
    const lowBatCount = sensorsList.filter(s => s.battery !== undefined && s.battery < 20).length;

    const handleTestConnection = async () => {
        if (!inputSensorId) return toast.error("Enter a Sensor ID");
        try {
            await pingSensor(inputSensorId);
            toast.success(`Hardware verified. Signal: Good`);
            setConnectStep(3);
        } catch (e) {
            toast.error("Sensor not responding. Wake it up and try again.");
        }
    };

    const handleConfirmLink = async () => {
        if (!selectedSlotForSensor || !inputSensorId) return;
        try {
            await linkSensorToSlot(inputSensorId, selectedSlotForSensor.id);
            toast.success(`Success! Sensor ${inputSensorId} is now live on Slot ${selectedSlotForSensor.id}`);
            // Reset
            setConnectStep(1);
            setSelectedSlotForSensor(null);
            setInputSensorId('');
            setSearchParams({});
            setTab('health');
        } catch (e) {
            toast.error("Failed to map sensor. Check permissions.");
        }
    };

    const columns = [
        {
            header: 'Slot Area',
            accessor: 'id',
            render: (row) => (
                <div className="flex flex-col">
                    <span className="font-bold text-text-primary text-base">{row.id}</span>
                    <span className="text-[11px] font-semibold text-text-tertiary uppercase tracking-[0.8px] mt-0.5">LEVEL {row.floor}</span>
                </div>
            )
        },
        {
            header: 'Hardware ID',
            accessor: 'sensorId',
            render: (row) => (
                <span className="font-mono text-xs font-bold text-text-primary bg-bg-light border border-border rounded-md px-2.5 py-1">
                    {row.sensorId}
                </span>
            )
        },
        {
            header: 'Status',
            accessor: 'status',
            render: (row) => (
                row.status === 'online' ? (
                    <Badge variant="success" dot pulse>Online</Badge>
                ) : (
                    <Badge variant="error" dot>Offline</Badge>
                )
            )
        },
        {
            header: 'Power',
            accessor: 'battery',
            render: (row) => (
                <div className="flex items-center gap-3 w-32">
                    <div className="flex-1 h-1.5 bg-slate-100 rounded-full overflow-hidden border border-border">
                        <div className={`h-full ${row.battery > 20 ? 'bg-success' : 'bg-error'}`} style={{ width: `${row.battery}%` }}></div>
                    </div>
                    <span className={`font-mono text-xs font-semibold ${row.battery > 20 ? 'text-text-secondary' : 'text-error'}`}>{row.battery}%</span>
                </div>
            )
        },
        {
            header: 'Signal',
            accessor: 'signal',
            render: (row) => (
                <div className="flex gap-[3px] items-end h-[14px]">
                    {[1, 2, 3, 4].map(bar => (
                        <div key={bar} className={`w-[3px] rounded-t-[1px] ${bar <= Math.ceil(row.signal / 25) ? 'bg-primary' : 'bg-slate-200'}`} style={{ height: `${bar * 25}%` }}></div>
                    ))}
                </div>
            )
        },
        {
            header: 'Actions',
            accessor: 'actions',
            align: 'right',
            render: (row) => (
                <div className="flex items-center justify-end gap-2">
                    <Button
                        variant="secondary"
                        size="sm"
                        onClick={(e) => {
                            e.stopPropagation();
                            toast.promise(pingSensor(row.sensorId), {
                                loading: 'Pinging...',
                                success: 'Sensor responded successfully!',
                                error: 'Hardware offline.'
                            });
                        }}
                    >
                        Ping
                    </Button>
                    <Button
                        variant="danger"
                        size="sm"
                        onClick={(e) => {
                            e.stopPropagation();
                            if (window.confirm("Are you sure you want to unmap this sensor?")) {
                                unlinkSensor(row.id);
                            }
                        }}
                    >
                        Unmap
                    </Button>
                </div>
            )
        }
    ];

    return (
        <div className="space-y-6 flex flex-col h-[calc(100vh-64px-48px)] w-full max-w-[1400px] mx-auto animate-in fade-in duration-300">

            {/* Premium Tab Navigation */}
            <div className="flex bg-bg-light border border-border p-1 rounded-xl w-fit shadow-xs">
                <button
                    onClick={() => setTab('health')}
                    className={`px-6 py-2 rounded-lg text-sm font-semibold transition-all duration-200 ${activeTab === 'health'
                            ? 'bg-white text-text-primary shadow-sm border border-border/50'
                            : 'text-text-secondary hover:text-text-primary hover:bg-white/50 border border-transparent'
                        }`}
                >
                    Health Dashboard
                </button>
                <button
                    onClick={() => setTab('connect')}
                    className={`px-6 py-2 rounded-lg text-sm font-semibold transition-all duration-200 ${activeTab === 'connect'
                            ? 'bg-white text-text-primary shadow-sm border border-border/50'
                            : 'text-text-secondary hover:text-text-primary hover:bg-white/50 border border-transparent'
                        }`}
                >
                    Connect Wizard
                </button>
            </div>

            {/* ----------- HEALTH TAB ----------- */}
            {activeTab === 'health' && (
                <div className="flex-1 flex flex-col gap-6 w-full animate-in fade-in slide-in-from-bottom-2">
                    {/* Top Stats */}
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 shrink-0">
                        <StatCard icon={RadioTower} title="Online Sensors" value={onlineCount} color="success" />
                        <StatCard icon={XCircle} title="Offline / Missing" value={offlineCount} color="error" />
                        <StatCard icon={AlertTriangle} title="Hardware Errors" value={errorCount} color="warning" />
                        <StatCard icon={BatteryWarning} title="Low Battery Alert" value={lowBatCount} color="error" />
                    </div>

                    {/* Hardware Table Container */}
                    <div className="flex-1 flex flex-col">
                        <div className="flex justify-between items-center mb-4">
                            <div>
                                <h3 className="text-base font-bold text-text-primary tracking-tight">Hardware Fleet Status</h3>
                                <p className="text-xs text-text-tertiary mt-0.5">Real-time telemetry and ping status from installed pucks</p>
                            </div>
                            <div className="flex gap-3">
                                <div className="relative">
                                    <Search className="w-4 h-4 text-text-tertiary absolute left-3 top-1/2 -translate-y-1/2" />
                                    <input type="text" placeholder="Search ID or Slot..." className="pl-9 pr-4 py-2 bg-white border border-border rounded-lg text-sm font-medium focus:ring-1 focus:ring-primary focus:border-primary outline-none transition-all w-64 shadow-xs" />
                                </div>
                                <Button variant="secondary" icon={Wifi}>
                                    Ping Fleet
                                </Button>
                            </div>
                        </div>

                        <DataTable columns={columns} data={sensorsList} />
                    </div>
                </div>
            )}

            {/* ----------- CONNECT TAB ----------- */}
            {activeTab === 'connect' && (
                <div className="flex-1 bg-white rounded-[14px] border border-border shadow-sm overflow-hidden flex animate-in fade-in slide-in-from-bottom-2">

                    {/* Wizard Steps Sidebar */}
                    <div className="w-[320px] bg-bg-light border-r border-border p-8 flex flex-col gap-6 shrink-0">
                        <h3 className="font-bold text-text-primary text-lg flex items-center gap-2.5 mb-6 tracking-tight">
                            <Cpu className="w-6 h-6 text-primary" /> Setup Wizard
                        </h3>

                        <div className={`p-5 rounded-xl border-[1.5px] transition-all duration-300 ${connectStep >= 1 ? 'bg-white border-primary shadow-sm' : 'border-dashed border-border text-text-tertiary'}`}>
                            <span className={`text-[11px] font-bold tracking-[1px] uppercase mb-1 block ${connectStep >= 1 ? 'text-primary' : 'text-text-tertiary'}`}>Step 1</span>
                            <p className={`font-bold text-base ${connectStep >= 1 ? 'text-text-primary' : ''}`}>Target Slot</p>
                            {selectedSlotForSensor && (
                                <div className="mt-3 flex items-center gap-2">
                                    <span className="px-2.5 py-1 bg-primary-light/10 text-primary rounded-md text-xs font-mono font-bold border border-primary/20">{selectedSlotForSensor.id}</span>
                                    <CheckCircle2 className="w-4 h-4 text-primary" />
                                </div>
                            )}
                        </div>

                        {connectStep > 1 && <div className="w-px h-6 bg-primary mx-auto opacity-30"></div>}

                        <div className={`p-5 rounded-xl border-[1.5px] transition-all duration-300 ${connectStep >= 2 ? 'bg-white border-primary shadow-sm' : 'border-dashed border-border text-text-tertiary'}`}>
                            <span className={`text-[11px] font-bold tracking-[1px] uppercase mb-1 block ${connectStep >= 2 ? 'text-primary' : 'text-text-tertiary'}`}>Step 2</span>
                            <p className={`font-bold text-base ${connectStep >= 2 ? 'text-text-primary' : ''}`}>Hardware ID</p>
                            {inputSensorId && connectStep === 3 && (
                                <div className="mt-3 flex items-center gap-2">
                                    <span className="px-2.5 py-1 bg-success-bg text-success-text rounded-md text-xs font-mono font-bold border border-success/20">{inputSensorId}</span>
                                    <CheckCircle2 className="w-4 h-4 text-success" />
                                </div>
                            )}
                        </div>

                        {connectStep > 2 && <div className="w-px h-6 bg-primary mx-auto opacity-30"></div>}

                        <div className={`p-5 rounded-xl border-[1.5px] transition-all duration-300 ${connectStep >= 3 ? 'bg-white border-primary shadow-sm' : 'border-dashed border-border text-text-tertiary'}`}>
                            <span className={`text-[11px] font-bold tracking-[1px] uppercase mb-1 block ${connectStep >= 3 ? 'text-primary' : 'text-text-tertiary'}`}>Step 3</span>
                            <p className={`font-bold text-base ${connectStep >= 3 ? 'text-text-primary' : ''}`}>Confirm & Map</p>
                        </div>
                    </div>

                    {/* Wizard Content Area */}
                    <div className="flex-1 p-12 overflow-y-auto bg-white relative">
                        {connectStep === 1 && (
                            <div className="max-w-[700px] mx-auto animate-in slide-in-from-right-8 fade-in duration-300">
                                <h2 className="text-[28px] font-bold text-text-primary mb-2 tracking-tight">Select target slot</h2>
                                <p className="text-text-secondary text-[15px] mb-12">Choose a physical parking space from your lot to link with new hardware.</p>

                                <div className="flex flex-wrap gap-4">
                                    {slots.length === 0 ? (
                                        <div className="text-text-tertiary py-12 w-full text-center">No slots defined in your lot yet.</div>
                                    ) : (
                                        slots.map(s => (
                                            <button
                                                key={s.id}
                                                onClick={() => { setSelectedSlotForSensor(s); setConnectStep(2); }}
                                                disabled={s.sensorId}
                                                className={`
                                                    relative w-[90px] h-[110px] rounded-xl flex flex-col items-center justify-center border-[1.5px] font-bold transition-all duration-200
                                                    ${s.sensorId
                                                        ? 'bg-bg-light border-border text-text-tertiary cursor-not-allowed opacity-60'
                                                        : 'bg-white border-border text-text-primary hover:border-primary hover:shadow-primary hover:scale-[1.03] hover:text-primary'}
                                                `}
                                            >
                                                <span className="text-[22px] font-mono leading-none">{s.id}</span>
                                                <span className="text-[11px] font-semibold mt-2 opacity-60 uppercase tracking-[1px]">LVL {s.floor}</span>
                                                {s.sensorId && (
                                                    <div className="absolute top-2 right-2 flex items-center justify-center">
                                                        <CheckCircle2 className="w-4 h-4 text-success" />
                                                    </div>
                                                )}
                                            </button>
                                        ))
                                    )}
                                </div>
                            </div>
                        )}

                        {connectStep === 2 && (
                            <div className="max-w-[560px] mx-auto animate-in slide-in-from-right-8 fade-in duration-300 mt-8">
                                <div className="w-14 h-14 bg-primary-light/10 text-primary border border-primary/20 rounded-2xl flex items-center justify-center mb-6 shadow-sm">
                                    <SearchCode className="w-7 h-7" />
                                </div>
                                <h2 className="text-[28px] font-bold text-text-primary mb-3 tracking-tight">Identify hardware</h2>
                                <p className="text-text-secondary text-[15px] mb-10 leading-relaxed">Enter the Serial Number (SN) printed on the back of the puck sensor, or scan its QR code.</p>

                                <div className="bg-white p-8 rounded-[14px] border border-border shadow-sm">
                                    <label className="block text-[13px] font-semibold text-text-secondary mb-2 uppercase tracking-[0.5px]">Sensor Serial Number</label>
                                    <input
                                        type="text"
                                        value={inputSensorId}
                                        onChange={(e) => setInputSensorId(e.target.value.toUpperCase())}
                                        className="w-full px-5 py-4 rounded-xl border border-border focus:ring-1 focus:ring-primary focus:border-primary font-mono text-[24px] tracking-[4px] font-semibold text-text-primary placeholder:text-text-tertiary transition-all shadow-xs"
                                        placeholder="TX-A04B"
                                        autoFocus
                                    />
                                    <p className="text-[13px] text-text-tertiary font-medium mt-4 flex items-center gap-2">
                                        <AlertTriangle className="w-4 h-4 text-warning" /> Ensure the sensor is powered on and within range.
                                    </p>

                                    <div className="flex gap-4 mt-10">
                                        <Button
                                            variant="secondary"
                                            size="lg"
                                            onClick={() => { setConnectStep(1); setInputSensorId(''); }}
                                            className="px-8"
                                        >
                                            Back
                                        </Button>
                                        <Button
                                            variant="primary"
                                            size="lg"
                                            onClick={handleTestConnection}
                                            disabled={sensorLoading || inputSensorId.length < 4}
                                            loading={sensorLoading}
                                            className="flex-1"
                                        >
                                            Test Connection
                                        </Button>
                                    </div>
                                </div>
                            </div>
                        )}

                        {connectStep === 3 && (
                            <div className="max-w-[560px] mx-auto animate-in slide-in-from-right-8 fade-in duration-300 mt-8">
                                <div className="w-14 h-14 bg-success-bg text-success border border-success/20 rounded-2xl flex items-center justify-center mb-6 shadow-sm">
                                    <CheckCircle2 className="w-7 h-7" />
                                </div>
                                <h2 className="text-[28px] font-bold text-text-primary mb-3 tracking-tight">Confirm mapping</h2>
                                <p className="text-text-secondary text-[15px] mb-10 leading-relaxed">Hardware verified. Please confirm the mapping below to bring this sensor online in your Live Map.</p>

                                <div className="bg-white border border-border rounded-[14px] p-8 mb-10 space-y-6 shadow-sm relative overflow-hidden">

                                    <div className="flex justify-between items-center border-b border-border pb-6">
                                        <span className="text-text-secondary font-semibold">Target Slot</span>
                                        <div className="flex items-center gap-3">
                                            <span className="font-mono text-[18px] font-bold text-text-primary bg-bg-light px-4 py-1.5 rounded-lg border border-border">{selectedSlotForSensor?.id}</span>
                                            <span className="text-[11px] font-bold text-text-tertiary bg-surface-hover border border-border px-2.5 py-1 rounded uppercase tracking-[0.8px]">Level {selectedSlotForSensor?.floor}</span>
                                        </div>
                                    </div>
                                    <div className="flex justify-between items-center pt-2">
                                        <span className="text-text-secondary font-semibold">Hardware SN</span>
                                        <span className="font-mono text-[18px] font-bold text-primary bg-primary-light/10 px-4 py-1.5 rounded-lg border border-primary/20">{inputSensorId}</span>
                                    </div>
                                </div>

                                <div className="flex gap-4">
                                    <Button
                                        variant="secondary"
                                        size="lg"
                                        onClick={() => setConnectStep(2)}
                                        className="px-8"
                                    >
                                        Back
                                    </Button>
                                    <Button
                                        variant="primary"
                                        size="lg"
                                        onClick={handleConfirmLink}
                                        disabled={sensorLoading}
                                        loading={sensorLoading}
                                        className="flex-1 bg-success hover:bg-green-600 shadow-sm"
                                    >
                                        Finalize & Sync
                                    </Button>
                                </div>
                            </div>
                        )}
                    </div>
                </div>
            )}
        </div>
    );
}
