import React, { useState, useEffect } from 'react';
import { db } from '../firebase';
import {
    collection,
    query,
    where,
    orderBy,
    limit,
    getDocs,
    onSnapshot,
    getCountFromServer,
    Timestamp
} from 'firebase/firestore';
import {
    startOfDay,
    endOfDay,
    subDays,
    format,
    formatDistanceToNow
} from 'date-fns';
import {
    Car,
    Wallet,
    CalendarCheck,
    Users,
    Activity,
    KeyRound
} from 'lucide-react';
import {
    LineChart,
    Line,
    XAxis,
    YAxis,
    CartesianGrid,
    Tooltip,
    ResponsiveContainer,
    BarChart,
    Bar
} from 'recharts';
import StatCard from '../components/ui/StatCard';
import Card from '../components/ui/Card';
import Badge from '../components/ui/Badge';
import toast from 'react-hot-toast';

export default function Dashboard() {
    const [loading, setLoading] = useState(true);
    const [stats, setStats] = useState({
        users: 0,
        lots: 0,
        bookings: 0,
        revenue: 0,
        pendingRequests: 0
    });
    const [revenueChartData, setRevenueChartData] = useState([]);
    const [lotRevenueData, setLotRevenueData] = useState([]);
    const [totalSlots, setTotalSlots] = useState(0);
    const [freeSlots, setFreeSlots] = useState(0);
    const [totalLots, setTotalLots] = useState(0);
    const [recentBookings, setRecentBookings] = useState([]);
    const [activityFeed, setActivityFeed] = useState([]);

    const fetchDashboardData = async () => {
        try {
            const usersCountSnap = await getCountFromServer(
                query(collection(db, 'users'), where('role', '==', 'customer'))
            );
            const lotsCountSnap = await getCountFromServer(collection(db, 'parking_locations'));

            const todayStart = Timestamp.fromDate(startOfDay(new Date()));
            const todayEnd = Timestamp.fromDate(endOfDay(new Date()));
            const todayBookingsSnap = await getDocs(
                query(
                    collection(db, 'bookings'),
                    where('createdAt', '>=', todayStart),
                    where('createdAt', '<=', todayEnd)
                )
            );

            const todayRevenue = todayBookingsSnap.docs.reduce(
                (sum, bookingDoc) => sum + Number(bookingDoc.data().amount || 0),
                0
            );

            setStats((prev) => ({
                ...prev,
                users: usersCountSnap.data().count,
                lots: lotsCountSnap.data().count,
                bookings: todayBookingsSnap.size,
                revenue: todayRevenue
            }));

            const chartData = [];
            for (let i = 29; i >= 0; i -= 1) {
                const date = subDays(new Date(), i);
                const dayStart = Timestamp.fromDate(startOfDay(date));
                const dayEnd = Timestamp.fromDate(endOfDay(date));
                const dayBookingsSnap = await getDocs(
                    query(
                        collection(db, 'bookings'),
                        where('createdAt', '>=', dayStart),
                        where('createdAt', '<=', dayEnd)
                    )
                );
                const dayRevenue = dayBookingsSnap.docs.reduce(
                    (sum, bookingDoc) => sum + Number(bookingDoc.data().amount || 0),
                    0
                );
                chartData.push({
                    date: format(date, 'MMM dd'),
                    revenue: dayRevenue
                });
            }
            setRevenueChartData(chartData);

            const lotsSnap = await getDocs(collection(db, 'parking_locations'));
            const byLot = [];
            for (const lotDoc of lotsSnap.docs) {
                const lotBookingsSnap = await getDocs(
                    query(collection(db, 'bookings'), where('parkingId', '==', lotDoc.id))
                );
                const lotRevenue = lotBookingsSnap.docs.reduce(
                    (sum, bookingDoc) => sum + Number(bookingDoc.data().amount || 0),
                    0
                );
                byLot.push({
                    name: lotDoc.data().name || 'Unnamed Lot',
                    revenue: lotRevenue
                });
            }
            setLotRevenueData(byLot.sort((a, b) => b.revenue - a.revenue));

            const recentSnap = await getDocs(
                query(
                    collection(db, 'bookings'),
                    orderBy('createdAt', 'desc'),
                    limit(10)
                )
            );
            setRecentBookings(recentSnap.docs.map((d) => ({ id: d.id, ...d.data() })));
        } catch (error) {
            console.error('Dashboard fetch error:', error);
            toast.error('Failed to load dashboard data');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchDashboardData();

        const unsubRequests = onSnapshot(
            query(collection(db, 'access_requests'), where('status', '==', 'pending')),
            (snap) => {
                setStats((prev) => ({ ...prev, pendingRequests: snap.size }));
            },
            (error) => {
                console.error('Pending requests listener error:', error);
            }
        );

        const unsubLots = onSnapshot(
            query(collection(db, 'parking_locations')),
            (snap) => {
                let slots = 0;
                let free = 0;
                snap.docs.forEach((lotDoc) => {
                    const lot = lotDoc.data();
                    slots += Number(lot.total_slots || 0);
                    free += Number(lot.available_slots || 0);
                });
                setTotalLots(snap.size);
                setTotalSlots(slots);
                setFreeSlots(free);
            },
            (error) => {
                console.error('Parking lots listener error:', error);
            }
        );

        const unsubFeed = onSnapshot(
            query(collection(db, 'bookings'), orderBy('createdAt', 'desc'), limit(20)),
            (snap) => {
                const feed = snap.docs.map((bookingDoc) => {
                    const booking = bookingDoc.data();
                    const createdAt = booking.createdAt?.toDate();
                    return {
                        id: bookingDoc.id,
                        message: `🆕 ${booking.userName || 'User'} booked slot ${booking.slotId || '-'} at ${booking.parkingName || 'Unknown lot'}`,
                        time: createdAt
                            ? formatDistanceToNow(createdAt, { addSuffix: true })
                            : 'just now'
                    };
                });
                setActivityFeed(feed);
            },
            (error) => {
                console.error('Activity listener error:', error);
            }
        );

        return () => {
            unsubRequests();
            unsubLots();
            unsubFeed();
        };
    }, []);

    if (loading) {
        return (
            <div className="h-[60vh] flex items-center justify-center">
                <div className="w-12 h-12 border-4 border-primary border-t-transparent rounded-full animate-spin" />
            </div>
        );
    }

    const occupiedSlots = Math.max(totalSlots - freeSlots, 0);
    const occupancyRate = totalSlots > 0 ? Math.round((occupiedSlots / totalSlots) * 100) : 0;

    return (
        <div className="space-y-6 animate-fade-in pb-10">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-2">
                <div>
                    <h1 className="text-2xl font-bold text-text-primary tracking-tight">Platform Dashboard</h1>
                    <p className="text-sm font-medium text-text-secondary mt-1">Welcome back. Here's what's happening across TechXPark.</p>
                </div>
                <div className="flex items-center gap-3">
                    <div className="flex items-center gap-2 text-sm font-medium text-text-secondary bg-surface border border-border px-3 py-1.5 rounded-lg">
                        <span className="w-2 h-2 rounded-full bg-success animate-pulse" />
                        Live Updates
                    </div>
                </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-4">
                <StatCard title="Today's Revenue" value={`₹${stats.revenue.toLocaleString()}`} icon={Wallet} />
                <StatCard title="Today's Bookings" value={stats.bookings.toLocaleString()} icon={CalendarCheck} />
                <StatCard title="Total Users" value={stats.users.toLocaleString()} icon={Users} />
                <StatCard title="Total Lots" value={stats.lots.toLocaleString()} icon={Car} />
                <StatCard title="Pending Requests" value={stats.pendingRequests.toLocaleString()} icon={KeyRound} />
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                <Card className="col-span-1 lg:col-span-2 flex flex-col pt-5 px-6 pb-6">
                    <div className="flex items-center justify-between mb-6">
                        <div>
                            <h2 className="text-base font-bold text-text-primary">Revenue Overview</h2>
                            <p className="text-sm text-text-secondary font-medium">Platform-wide earnings over the last 30 days</p>
                        </div>
                    </div>
                    <div className="flex-1 min-h-[300px] w-full mt-2">
                        <ResponsiveContainer width="100%" height="100%">
                            <LineChart data={revenueChartData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#E8ECF4" />
                                <XAxis dataKey="date" axisLine={false} tickLine={false} tick={{ fill: '#9AA5BC', fontSize: 12, fontWeight: 500 }} dy={10} />
                                <YAxis axisLine={false} tickLine={false} tick={{ fill: '#9AA5BC', fontSize: 12, fontWeight: 500 }} tickFormatter={(value) => `₹${value}`} />
                                <Tooltip contentStyle={{ borderRadius: '12px', border: '1px solid #E8ECF4', boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)', fontWeight: 600 }} formatter={(val) => [`₹${val}`, 'Revenue']} />
                                <Line type="monotone" dataKey="revenue" stroke="#2845D6" strokeWidth={3} dot={false} />
                            </LineChart>
                        </ResponsiveContainer>
                    </div>
                </Card>

                <Card className="col-span-1 pt-5 px-6 pb-6 flex flex-col">
                    <h2 className="text-base font-bold text-text-primary mb-1">Platform Occupancy</h2>
                    <p className="text-sm text-text-secondary font-medium mb-6">Live parking lot status</p>
                    <div className="flex-1 space-y-4">
                        <div className="flex items-center justify-between">
                            <span className="text-sm font-semibold text-text-secondary">Total Lots</span>
                            <span className="text-sm font-bold text-text-primary">{totalLots}</span>
                        </div>
                        <div className="flex items-center justify-between">
                            <span className="text-sm font-semibold text-text-secondary">Occupied Slots</span>
                            <span className="text-sm font-bold text-error">{occupiedSlots}</span>
                        </div>
                        <div className="flex items-center justify-between">
                            <span className="text-sm font-semibold text-text-secondary">Free Slots</span>
                            <span className="text-sm font-bold text-success">{freeSlots}</span>
                        </div>
                        <div className="pt-4 border-t border-border">
                            <div className="flex items-center justify-between mb-2">
                                <span className="text-xs font-bold text-text-tertiary uppercase tracking-wider">Occupancy Rate</span>
                                <span className="text-xs font-bold text-primary">{occupancyRate}%</span>
                            </div>
                            <div className="w-full bg-bg-light h-2 rounded-full overflow-hidden">
                                <div className="bg-primary h-full transition-all duration-500" style={{ width: `${occupancyRate}%` }} />
                            </div>
                        </div>
                    </div>
                </Card>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                <Card className="col-span-1 lg:col-span-2 pt-5 px-6 pb-6">
                    <h2 className="text-base font-bold text-text-primary mb-1">Revenue by Location</h2>
                    <p className="text-sm text-text-secondary font-medium mb-6">Comparing top performing parking lots</p>
                    <div className="h-[280px] w-full">
                        <ResponsiveContainer width="100%" height="100%">
                            <BarChart data={lotRevenueData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#E8ECF4" />
                                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fill: '#9AA5BC', fontSize: 10, fontWeight: 500 }} dy={10} />
                                <YAxis axisLine={false} tickLine={false} tick={{ fill: '#9AA5BC', fontSize: 12, fontWeight: 500 }} />
                                <Tooltip cursor={{ fill: '#F4F6FB' }} contentStyle={{ borderRadius: '12px', border: '1px solid #E8ECF4', boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)' }} formatter={(val) => [`₹${val}`, 'Revenue']} />
                                <Bar dataKey="revenue" fill="#2845D6" radius={[4, 4, 0, 0]} barSize={32} />
                            </BarChart>
                        </ResponsiveContainer>
                    </div>

                    <div className="mt-6 overflow-x-auto">
                        <table className="w-full text-left text-sm">
                            <thead className="text-text-tertiary uppercase text-[11px] font-bold border-b border-border">
                                <tr>
                                    <th className="pb-3">User</th>
                                    <th className="pb-3">Lot</th>
                                    <th className="pb-3">Slot</th>
                                    <th className="pb-3">Amount</th>
                                    <th className="pb-3">Status</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-border">
                                {recentBookings.map((booking) => (
                                    <tr key={booking.id} className="hover:bg-bg-light transition-colors">
                                        <td className="py-3 font-semibold text-text-primary">{booking.userName || 'Guest'}</td>
                                        <td className="py-3 text-text-secondary">{booking.parkingName || '-'}</td>
                                        <td className="py-3 text-text-secondary">{booking.slotId || '-'}</td>
                                        <td className="py-3 font-bold text-text-primary">₹{Number(booking.amount || 0).toLocaleString()}</td>
                                        <td className="py-3">
                                            <Badge variant={booking.status === 'completed' ? 'success' : booking.status === 'cancelled' ? 'error' : 'warning'}>
                                                {booking.status || 'unknown'}
                                            </Badge>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </Card>

                <div className="col-span-1 space-y-6">
                    <Card padding="p-0" className="overflow-hidden">
                        <div className="px-5 py-4 border-b border-border bg-surface-hover/50 flex items-center justify-between">
                            <div className="flex items-center gap-2">
                                <KeyRound className="w-4 h-4 text-warning" />
                                <h3 className="text-sm font-bold text-text-primary">Access Requests</h3>
                            </div>
                            <Badge variant="warning">{stats.pendingRequests} Pending</Badge>
                        </div>
                        <div className="p-4 text-center">
                            <p className="text-sm text-text-secondary mb-3">There are {stats.pendingRequests} owners waiting for approval.</p>
                            <a href="/admin/requests" className="text-xs font-bold text-primary hover:underline">View All Requests →</a>
                        </div>
                    </Card>

                    <Card padding="p-0">
                        <div className="px-5 py-4 border-b border-border flex items-center gap-2 bg-surface-hover/50">
                            <Activity className="w-4 h-4 text-primary" />
                            <h3 className="text-sm font-bold text-text-primary">System Activity</h3>
                        </div>
                        <div className="p-5">
                            {activityFeed.length === 0 ? (
                                <p className="text-center text-xs font-medium text-text-tertiary pb-2">No recent activity</p>
                            ) : (
                                <div className="space-y-6 relative before:absolute before:inset-0 before:ml-2.5 before:-translate-x-px md:before:mx-auto md:before:translate-x-0 before:h-full before:w-0.5 before:bg-border">
                                    {activityFeed.map((activity) => (
                                        <div key={activity.id} className="relative flex items-center group">
                                            <div className="flex items-center justify-center w-6 h-6 rounded-full border-2 border-white bg-bg-light shadow-sm shrink-0 z-10">
                                                <Activity className="w-3 h-3 text-primary" strokeWidth={3} />
                                            </div>
                                            <div className="ml-4 flex-1 p-3 rounded-xl border border-border bg-surface shadow-sm">
                                                <div className="flex items-center justify-between mb-1">
                                                    <span className="text-[10px] font-bold text-text-tertiary uppercase">{activity.time}</span>
                                                </div>
                                                <p className="text-[12px] font-semibold text-text-secondary leading-snug">{activity.message}</p>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            )}
                        </div>
                    </Card>
                </div>
            </div>
        </div>
    );
}
