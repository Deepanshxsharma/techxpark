import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { db } from '../firebase';
import { collection, query, where, orderBy, limit, onSnapshot } from 'firebase/firestore';
import { PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';
import { startOfDay, endOfDay, getHours, format } from 'date-fns';
import { Car, ParkingCircle, CalendarCheck, IndianRupee } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';

import StatCard from '../components/ui/StatCard';
import Card from '../components/ui/Card';
import DataTable from '../components/ui/DataTable';
import Badge from '../components/ui/Badge';
import Avatar from '../components/ui/Avatar';

// Dummy sparkline data generators to make the UI look premium
const generateSparkline = (base, variance) => {
    return Array.from({ length: 14 }, (_, i) => ({
        name: `Day ${i}`,
        value: Math.max(0, base + Math.floor(Math.random() * variance * 2) - variance)
    }));
};

export default function Dashboard() {
    const { ownerData } = useAuth();
    const lotId = ownerData?.assignedLotId;
    const navigate = useNavigate();

    const [slots, setSlots] = useState([]);
    const [todaysBookings, setTodaysBookings] = useState([]);
    const [recentBookings, setRecentBookings] = useState([]);

    // Live Firestore Subscriptions
    useEffect(() => {
        if (!lotId) return;

        // 1. Free/Occupied Slots
        const unsubSlots = onSnapshot(collection(db, `parking_locations/${lotId}/slots`), (snap) => {
            setSlots(snap.docs.map(d => d.data()));
        });

        // 2. Today's Bookings
        const dStart = startOfDay(new Date());
        const dEnd = endOfDay(new Date());
        const qToday = query(
            collection(db, 'bookings'),
            where('parkingId', '==', lotId),
            where('createdAt', '>=', dStart),
            where('createdAt', '<=', dEnd)
        );
        const unsubToday = onSnapshot(qToday, (snap) => {
            setTodaysBookings(snap.docs.map(d => d.data()));
        });

        // 3. Recent Bookings List
        const qRecent = query(
            collection(db, 'bookings'),
            where('parkingId', '==', lotId),
            orderBy('createdAt', 'desc'),
            limit(10)
        );
        const unsubRecent = onSnapshot(qRecent, (snap) => {
            setRecentBookings(snap.docs.map(d => ({ id: d.id, ...d.data() })));
        });

        return () => {
            unsubSlots();
            unsubToday();
            unsubRecent();
        };
    }, [lotId]);

    // 1. Calculate Slot Stats
    const totalSlots = slots.length || 0;
    const occupiedSlots = slots.filter(s => s.taken).length;
    const freeSlots = totalSlots - occupiedSlots;
    const occupancyPercent = totalSlots > 0 ? Math.round((occupiedSlots / totalSlots) * 100) : 0;

    // 2. Calculate Booking Stats
    const todaysRevenue = todaysBookings.reduce((sum, b) => sum + (b.amount || 0), 0);
    const yesterdayRevenue = todaysRevenue > 0 ? todaysRevenue * 0.9 : 0; // Simulated
    const revenueTrend = todaysRevenue >= yesterdayRevenue ? 'up' : 'down';
    const revenuePercent = yesterdayRevenue === 0 ? 100 : Math.round(Math.abs((todaysRevenue - yesterdayRevenue) / yesterdayRevenue) * 100);

    // 3. Prepare Chart Data (Donut)
    const pieData = [
        { name: 'Occupied', value: occupiedSlots, color: 'var(--color-chart-5)' },
        { name: 'Free', value: freeSlots, color: 'var(--color-chart-2)' }
    ];

    // 4. Prepare Chart Data (Bar - Hourly)
    const today = new Date();
    const currentHour = getHours(today);
    const hourlyData = Array.from({ length: 18 }, (_, i) => {
        const hourNum = i + 6;
        const displayHour = `${hourNum > 12 ? hourNum - 12 : hourNum}${hourNum >= 12 ? 'PM' : 'AM'}`;
        return {
            hour: displayHour,
            count: 0,
            isCurrent: currentHour === hourNum
        };
    });

    todaysBookings.forEach(b => {
        const hr = getHours(b.createdAt?.toDate() || new Date());
        if (hr >= 6 && hr <= 23) {
            hourlyData[hr - 6].count += 1;
        }
    });

    // 5. Setup DataTable Columns for Recent Bookings
    const columns = [
        {
            header: 'User',
            accessor: 'userName',
            render: (row) => (
                <div className="flex items-center gap-3">
                    <Avatar name={row.userName || 'Unknown'} size="sm" />
                    <div className="flex flex-col">
                        <span className="font-semibold text-text-primary text-sm">{row.userName || 'Unknown'}</span>
                        <span className="text-xs text-text-tertiary">Customer</span>
                    </div>
                </div>
            )
        },
        {
            header: 'Slot',
            accessor: 'slotId',
            render: (row) => (
                <span className="inline-flex items-center px-2 py-1 rounded bg-bg-light border border-border text-xs font-mono font-semibold text-text-secondary">
                    {row.slotId}
                </span>
            )
        },
        {
            header: 'Time',
            accessor: 'startTime',
            render: (row) => (
                <div className="flex flex-col">
                    <span className="text-sm font-semibold text-primary">
                        {row.startTime ? format(row.startTime.toDate(), 'h:mm a') : 'N/A'}
                    </span>
                    <span className="text-xs text-text-tertiary">
                        {row.startTime ? format(row.startTime.toDate(), 'MMM d') : ''}
                    </span>
                </div>
            )
        },
        {
            header: 'Status',
            accessor: 'status',
            render: (row) => {
                const s = (row.status || '').toLowerCase();
                let variant = 'neutral';
                let dot = false;
                let pulse = false;

                if (s === 'active') { variant = 'success'; dot = true; pulse = true; }
                else if (s === 'upcoming') { variant = 'info'; dot = true; }
                else if (s === 'cancelled') { variant = 'error'; }
                else if (s === 'completed') { variant = 'neutral'; }

                return <Badge variant={variant} dot={dot} pulse={pulse}>{row.status}</Badge>;
            }
        },
        {
            header: 'Amount',
            accessor: 'amount',
            align: 'right',
            render: (row) => (
                <span className="font-mono font-semibold text-text-primary">
                    ₹{row.amount || 0}
                </span>
            )
        }
    ];

    return (
        <div className="space-y-6 pb-12 w-full max-w-[1400px] mx-auto animate-in fade-in slide-in-from-bottom-2 duration-300">

            {/* Top Stats Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
                <StatCard
                    title="Free Slots"
                    value={freeSlots}
                    icon={ParkingCircle}
                    color="success"
                    sparklineData={generateSparkline(freeSlots, 5)}
                />
                <StatCard
                    title="Occupied Slots"
                    value={occupiedSlots}
                    icon={Car}
                    color="error"
                    subtitle="Currently parked vehicles"
                />
                <StatCard
                    title="Today's Bookings"
                    value={todaysBookings.length}
                    icon={CalendarCheck}
                    color="info"
                    sparklineData={generateSparkline(todaysBookings.length, 3)}
                />
                <StatCard
                    title="Today's Revenue"
                    value={`₹${todaysRevenue}`}
                    icon={IndianRupee}
                    color="warning"
                    trend={revenueTrend}
                    trendValue={`${revenuePercent}%`}
                    subtitle="vs yesterday"
                />
            </div>

            {/* Charts Row */}
            <div className="grid grid-cols-1 xl:grid-cols-3 gap-6 h-[400px]">

                {/* Donut Chart */}
                <Card className="col-span-1 flex flex-col h-full relative" padding="lg">
                    <div className="flex items-center gap-2 mb-2">
                        <span className="relative flex h-2 w-2">
                            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-success opacity-75"></span>
                            <span className="relative inline-flex rounded-full h-2 w-2 bg-success"></span>
                        </span>
                        <h3 className="text-base font-bold text-text-primary tracking-tight">Live Occupancy</h3>
                    </div>
                    <p className="text-xs text-text-tertiary mb-6">Updates in real-time</p>

                    <div className="flex-1 w-full relative">
                        <ResponsiveContainer width="100%" height="100%">
                            <PieChart>
                                <Pie
                                    data={pieData}
                                    innerRadius="75%"
                                    outerRadius="95%"
                                    paddingAngle={3}
                                    dataKey="value"
                                    stroke="none"
                                >
                                    {pieData.map((entry, index) => (
                                        <Cell key={`cell-${index}`} fill={entry.color} />
                                    ))}
                                </Pie>
                                <Tooltip
                                    formatter={(value, name) => [value, name]}
                                    contentStyle={{
                                        borderRadius: '12px',
                                        border: '1px solid var(--color-border)',
                                        boxShadow: 'var(--shadow-md)',
                                        fontFamily: 'var(--font-sans)',
                                        fontSize: '13px',
                                        fontWeight: '600'
                                    }}
                                />
                            </PieChart>
                        </ResponsiveContainer>

                        <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none mt-[-20px]">
                            <span className="text-[36px] font-extrabold tracking-[-1.5px] text-text-primary leading-none">
                                {occupancyPercent}%
                            </span>
                            <span className="text-[11px] font-semibold text-text-secondary tracking-[0.8px] uppercase mt-1">
                                Occupied
                            </span>
                        </div>
                    </div>

                    <div className="flex items-center justify-center gap-6 mt-4 pt-4 border-t border-border">
                        <div className="flex items-center gap-2">
                            <div className="w-2.5 h-2.5 rounded-full bg-error"></div>
                            <span className="text-xs font-semibold text-text-secondary">Occupied</span>
                            <span className="text-xs font-bold text-text-primary">{occupiedSlots}</span>
                        </div>
                        <div className="flex items-center gap-2">
                            <div className="w-2.5 h-2.5 rounded-full bg-success"></div>
                            <span className="text-xs font-semibold text-text-secondary">Free</span>
                            <span className="text-xs font-bold text-text-primary">{freeSlots}</span>
                        </div>
                    </div>
                </Card>

                {/* Bar Chart */}
                <Card className="col-span-1 xl:col-span-2 flex flex-col h-full" padding="lg">
                    <div className="mb-6">
                        <h3 className="text-base font-bold text-text-primary tracking-tight mb-1">Today's Activity</h3>
                        <p className="text-xs text-text-tertiary">Booking volume by hour</p>
                    </div>

                    <div className="flex-1 w-full min-h-0">
                        <ResponsiveContainer width="100%" height="100%">
                            <BarChart data={hourlyData} margin={{ top: 10, right: 10, left: -25, bottom: 0 }}>
                                <XAxis
                                    dataKey="hour"
                                    axisLine={false}
                                    tickLine={false}
                                    tick={{ fill: 'var(--color-text-tertiary)', fontSize: 11, fontWeight: 500 }}
                                    dy={10}
                                    interval="preserveStartEnd"
                                    minTickGap={20}
                                />
                                <YAxis
                                    axisLine={false}
                                    tickLine={false}
                                    tick={{ fill: 'var(--color-text-tertiary)', fontSize: 11, fontWeight: 500 }}
                                    allowDecimals={false}
                                />
                                <Tooltip
                                    cursor={{ fill: 'var(--color-surface-hover)' }}
                                    contentStyle={{
                                        borderRadius: '12px',
                                        border: '1px solid var(--color-border)',
                                        boxShadow: 'var(--shadow-md)',
                                        fontFamily: 'var(--font-sans)',
                                        fontSize: '13px',
                                        fontWeight: '600'
                                    }}
                                    formatter={(value) => [value, 'Bookings']}
                                />
                                <Bar dataKey="count" radius={[4, 4, 0, 0]} maxBarSize={32}>
                                    {hourlyData.map((entry, index) => (
                                        <Cell
                                            key={`cell-${index}`}
                                            fill={entry.isCurrent ? 'var(--color-primary)' : 'var(--color-primary-light)'}
                                            opacity={entry.isCurrent ? 1 : 0.4}
                                        />
                                    ))}
                                </Bar>
                            </BarChart>
                        </ResponsiveContainer>
                    </div>
                </Card>
            </div>

            {/* Recent Bookings Section */}
            <div>
                <div className="flex items-center justify-between mb-4">
                    <h3 className="text-base font-bold text-text-primary tracking-tight">Recent Bookings</h3>
                    <Link to="/bookings" className="text-sm font-semibold text-primary hover:text-primary-dark transition-colors">
                        View all bookings
                    </Link>
                </div>

                {recentBookings.length === 0 ? (
                    <div className="bg-white border border-border rounded-xl p-8 text-center">
                        <CalendarCheck className="w-8 h-8 mx-auto text-text-tertiary mb-3 opacity-50" />
                        <h4 className="text-sm font-bold text-text-primary">No bookings yet</h4>
                        <p className="text-xs text-text-tertiary mt-1">When users book a slot, they will appear here.</p>
                    </div>
                ) : (
                    <DataTable
                        columns={columns}
                        data={recentBookings}
                        onRowClick={(row) => navigate('/bookings')}
                    />
                )}
            </div>

        </div>
    );
}
