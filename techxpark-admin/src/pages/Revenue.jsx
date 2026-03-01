import React, { useState, useEffect } from 'react';
import { Wallet, TrendingUp, Calendar, CreditCard, Download, Loader2 } from 'lucide-react';
import Card from '../components/ui/Card';
import Button from '../components/ui/Button';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar, Cell } from 'recharts';
import { db } from '../firebase';
import { collection, query, getDocs, where, Timestamp } from 'firebase/firestore';
import { startOfDay, endOfDay, subDays, subMonths, subYears, format } from 'date-fns';
import toast from 'react-hot-toast';
import { formatCurrency, exportToCSV } from '../utils/helpers';

export default function Revenue() {
    const [timeframe, setTimeframe] = useState('30d');
    const [loading, setLoading] = useState(true);
    const [totalRevenue, setTotalRevenue] = useState(0);
    const [prevRevenue, setPrevRevenue] = useState(0);
    const [chartData, setChartData] = useState([]);
    const [lotRevenueData, setLotRevenueData] = useState([]);
    const [totalBookingsCount, setTotalBookingsCount] = useState(0);

    useEffect(() => {
        fetchRevenueData();
    }, [timeframe]);

    const getDateRange = () => {
        const now = new Date();
        if (timeframe === '7d') return { start: subDays(now, 6), end: now, prevStart: subDays(now, 13), prevEnd: subDays(now, 7) };
        if (timeframe === '30d') return { start: subDays(now, 29), end: now, prevStart: subDays(now, 59), prevEnd: subDays(now, 30) };
        return { start: subYears(now, 1), end: now, prevStart: subYears(now, 2), prevEnd: subYears(now, 1) };
    };

    const fetchRevenueData = async () => {
        setLoading(true);
        try {
            const { start, end, prevStart, prevEnd } = getDateRange();
            const startTs = Timestamp.fromDate(startOfDay(start));
            const endTs = Timestamp.fromDate(endOfDay(end));
            const prevStartTs = Timestamp.fromDate(startOfDay(prevStart));
            const prevEndTs = Timestamp.fromDate(endOfDay(prevEnd));

            // Fetch current period bookings
            const currentSnap = await getDocs(
                query(collection(db, 'bookings'), where('createdAt', '>=', startTs), where('createdAt', '<=', endTs))
            );
            const currentBookings = currentSnap.docs.map(d => ({ id: d.id, ...d.data() }));

            // Fetch previous period bookings for growth %
            const prevSnap = await getDocs(
                query(collection(db, 'bookings'), where('createdAt', '>=', prevStartTs), where('createdAt', '<=', prevEndTs))
            );

            const currentTotal = currentBookings.reduce((s, b) => s + Number(b.amount || b.totalAmount || 0), 0);
            const prevTotal = prevSnap.docs.reduce((s, d) => s + Number(d.data().amount || d.data().totalAmount || 0), 0);

            setTotalRevenue(currentTotal);
            setPrevRevenue(prevTotal);
            setTotalBookingsCount(currentBookings.length);

            // Build daily chart data
            const days = timeframe === '7d' ? 7 : timeframe === '30d' ? 30 : 12;
            const daily = [];

            if (timeframe === '1y') {
                // Monthly aggregation for year view
                for (let i = 11; i >= 0; i--) {
                    const monthStart = startOfDay(subMonths(new Date(), i));
                    const monthEnd = endOfDay(i === 0 ? new Date() : subMonths(new Date(), i - 1));
                    const monthRevenue = currentBookings
                        .filter(b => {
                            const d = b.createdAt?.toDate?.() || new Date(b.createdAt);
                            return d >= monthStart && d <= monthEnd;
                        })
                        .reduce((s, b) => s + Number(b.amount || b.totalAmount || 0), 0);
                    daily.push({ name: format(monthStart, 'MMM yy'), revenue: monthRevenue });
                }
            } else {
                for (let i = days - 1; i >= 0; i--) {
                    const date = subDays(new Date(), i);
                    const dayStr = format(date, 'yyyy-MM-dd');
                    const dayRevenue = currentBookings
                        .filter(b => {
                            const d = b.createdAt?.toDate?.() || new Date(b.createdAt);
                            return format(d, 'yyyy-MM-dd') === dayStr;
                        })
                        .reduce((s, b) => s + Number(b.amount || b.totalAmount || 0), 0);
                    daily.push({ name: format(date, timeframe === '7d' ? 'EEE' : 'dd MMM'), revenue: dayRevenue });
                }
            }
            setChartData(daily);

            // Revenue by lot
            const lotsSnap = await getDocs(collection(db, 'parking_locations'));
            const lotMap = {};
            lotsSnap.docs.forEach(d => { lotMap[d.id] = d.data().name || 'Unnamed Lot'; });

            const byLot = {};
            currentBookings.forEach(b => {
                const lotId = b.parkingId || b.parkingLocationId || '';
                const lotName = lotMap[lotId] || 'Unknown';
                byLot[lotName] = (byLot[lotName] || 0) + Number(b.amount || b.totalAmount || 0);
            });

            const sortedLots = Object.entries(byLot)
                .map(([name, value]) => ({ name, value }))
                .sort((a, b) => b.value - a.value)
                .slice(0, 8);

            setLotRevenueData(sortedLots);
        } catch (error) {
            console.error('Revenue fetch error:', error);
            toast.error('Failed to load revenue data');
        } finally {
            setLoading(false);
        }
    };

    const growthPercent = prevRevenue > 0 ? (((totalRevenue - prevRevenue) / prevRevenue) * 100).toFixed(1) : 0;
    const platformCut = Math.round(totalRevenue * 0.15);

    const handleExport = () => {
        const rows = chartData.map(d => ({ Date: d.name, Revenue: d.revenue }));
        exportToCSV(rows, 'revenue_report');
        toast.success('Revenue CSV exported');
    };

    if (loading) {
        return (
            <div className="h-[60vh] flex items-center justify-center">
                <Loader2 className="w-8 h-8 text-primary animate-spin" />
            </div>
        );
    }

    return (
        <div className="space-y-6 animate-fade-in pb-10">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-border pb-6">
                <div>
                    <h1 className="text-2xl font-bold text-text-primary tracking-tight">Platform Revenue</h1>
                    <p className="text-sm font-medium text-text-secondary mt-1">Financial analytics and settlement tracking.</p>
                </div>
                <div className="flex items-center gap-3">
                    <div className="bg-surface border border-border rounded-lg p-1 flex text-sm font-semibold">
                        {['7d', '30d', '1y'].map(t => (
                            <button
                                key={t}
                                className={`px-4 py-1.5 rounded-md transition-colors ${timeframe === t ? 'bg-bg-light text-text-primary shadow-sm' : 'text-text-secondary hover:text-text-primary'}`}
                                onClick={() => setTimeframe(t)}
                            >{t.toUpperCase()}</button>
                        ))}
                    </div>
                    <Button variant="secondary" icon={Download} onClick={handleExport}>Statement</Button>
                </div>
            </div>

            {/* Metrics Overview */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <Card className="bg-gradient-to-br from-[#0A0F1E] to-[#121A33] border-none text-white relative overflow-hidden group">
                    <div className="absolute top-0 right-0 p-6 opacity-20 transform translate-x-4 -translate-y-4 group-hover:scale-110 transition-transform duration-500">
                        <Wallet className="w-24 h-24" />
                    </div>
                    <div className="relative z-10">
                        <p className="text-sm font-bold text-white/70 uppercase tracking-wider mb-2">Total Gross Volume</p>
                        <h2 className="text-4xl font-extrabold tracking-tight mb-4">{formatCurrency(totalRevenue)}</h2>
                        <div className={`flex items-center gap-2 text-sm font-bold ${Number(growthPercent) >= 0 ? 'text-success' : 'text-error'} bg-white/10 px-3 py-1.5 rounded-full inline-flex border border-white/20`}>
                            <TrendingUp className="w-4 h-4" />
                            {Number(growthPercent) >= 0 ? '+' : ''}{growthPercent}% vs last period
                        </div>
                    </div>
                </Card>

                <Card>
                    <div className="flex items-center justify-between mb-4">
                        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center text-primary">
                            <CreditCard className="w-5 h-5" />
                        </div>
                        <span className="text-xs font-bold text-text-tertiary bg-bg-light px-2 py-1 rounded-md border border-border">{totalBookingsCount} bookings</span>
                    </div>
                    <p className="text-[13px] font-bold text-text-tertiary uppercase tracking-wider mb-1">Platform Cut (Est. 15%)</p>
                    <h2 className="text-2xl font-extrabold text-text-primary">{formatCurrency(platformCut)}</h2>
                </Card>

                <Card>
                    <div className="flex items-center justify-between mb-4">
                        <div className="w-10 h-10 rounded-xl bg-warning-bg flex items-center justify-center text-warning">
                            <Calendar className="w-5 h-5" />
                        </div>
                    </div>
                    <p className="text-[13px] font-bold text-text-tertiary uppercase tracking-wider mb-1">Avg per Booking</p>
                    <h2 className="text-2xl font-extrabold text-text-primary">
                        {formatCurrency(totalBookingsCount > 0 ? Math.round(totalRevenue / totalBookingsCount) : 0)}
                    </h2>
                </Card>
            </div>

            {/* Charts Row */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Main Graph */}
                <Card className="col-span-1 lg:col-span-2 pt-5 px-6 pb-6 shadow-sm">
                    <h2 className="text-base font-bold text-text-primary mb-6">Gross Volume Trend</h2>
                    <div className="h-[320px] w-full">
                        <ResponsiveContainer width="100%" height="100%">
                            <AreaChart data={chartData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                                <defs>
                                    <linearGradient id="colorRev" x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="5%" stopColor="#2845D6" stopOpacity={0.4} />
                                        <stop offset="95%" stopColor="#2845D6" stopOpacity={0} />
                                    </linearGradient>
                                </defs>
                                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#E8ECF4" />
                                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fill: '#9AA5BC', fontSize: 12, fontWeight: 500 }} dy={10} />
                                <YAxis axisLine={false} tickLine={false} tick={{ fill: '#9AA5BC', fontSize: 12, fontWeight: 500 }} tickFormatter={(val) => `₹${val / 1000}k`} />
                                <Tooltip contentStyle={{ borderRadius: '12px', border: '1px solid #E8ECF4', boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)', fontWeight: 600 }} formatter={(val) => [formatCurrency(val), 'Revenue']} />
                                <Area type="monotone" dataKey="revenue" stroke="#2845D6" strokeWidth={3} fillOpacity={1} fill="url(#colorRev)" />
                            </AreaChart>
                        </ResponsiveContainer>
                    </div>
                </Card>

                {/* Top Locations */}
                <Card className="col-span-1 pt-5 px-6 pb-6 shadow-sm flex flex-col">
                    <h2 className="text-base font-bold text-text-primary mb-6">Top Earning Lots</h2>
                    {lotRevenueData.length === 0 ? (
                        <div className="flex-1 flex items-center justify-center">
                            <p className="text-sm text-text-tertiary">No revenue data for this period</p>
                        </div>
                    ) : (
                        <div className="flex-1 w-full relative">
                            <ResponsiveContainer width="100%" height="100%">
                                <BarChart data={lotRevenueData} layout="vertical" margin={{ top: 0, right: 0, left: 0, bottom: 0 }}>
                                    <XAxis type="number" hide />
                                    <YAxis dataKey="name" type="category" axisLine={false} tickLine={false} width={120} tick={{ fill: '#5C6B8A', fontSize: 12, fontWeight: 600 }} />
                                    <Tooltip cursor={{ fill: 'transparent' }} contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }} formatter={(val) => [formatCurrency(val), 'Revenue']} />
                                    <Bar dataKey="value" radius={[0, 4, 4, 0]} barSize={24}>
                                        {lotRevenueData.map((entry, index) => (
                                            <Cell key={`cell-${index}`} fill={index === 0 ? '#2845D6' : index === 1 ? '#4C63E8' : '#9AA5BC'} />
                                        ))}
                                    </Bar>
                                </BarChart>
                            </ResponsiveContainer>
                        </div>
                    )}
                </Card>
            </div>
        </div>
    );
}
