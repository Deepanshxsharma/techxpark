import { format, formatDistanceToNow } from 'date-fns';

export const formatCurrency = (amount) => {
    if (!amount && amount !== 0) return '₹0';
    return '₹' + Number(amount).toLocaleString('en-IN');
};

export const formatDate = (timestamp) => {
    if (!timestamp) return 'Unknown';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return format(date, 'MMM dd, yyyy');
};

export const formatTime = (timestamp) => {
    if (!timestamp) return '';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return format(date, 'hh:mm a');
};

export const formatTimeAgo = (timestamp) => {
    if (!timestamp) return '';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return formatDistanceToNow(date, { addSuffix: true });
};

export const getOccupancyColor = (percent) => {
    if (percent < 50) return '#0D9E6E';
    if (percent < 80) return '#D97706';
    return '#E5393B';
};

export const getStatusBadge = (status) => {
    const styles = {
        active: 'bg-green-100 text-green-700',
        upcoming: 'bg-blue-100 text-blue-700',
        completed: 'bg-gray-100 text-gray-600',
        cancelled: 'bg-red-100 text-red-700',
        pending: 'bg-yellow-100 text-yellow-700',
        approved: 'bg-green-100 text-green-700',
        rejected: 'bg-red-100 text-red-700',
        none: 'bg-gray-100 text-gray-500',
        suspended: 'bg-red-100 text-red-700',
    };
    return styles[status] || 'bg-gray-100 text-gray-600';
};

export const exportToCSV = (data, filename) => {
    if (!data || data.length === 0) return;
    const headers = Object.keys(data[0]);
    const csv = [
        headers.join(','),
        ...data.map(row =>
            headers.map(h => {
                let val = row[h] ?? '';
                if (typeof val === 'string' && (val.includes(',') || val.includes('"'))) {
                    val = `"${val.replace(/"/g, '""')}"`;
                }
                return val;
            }).join(',')
        )
    ].join('\n');

    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `${filename}_${format(new Date(), 'yyyy-MM-dd')}.csv`;
    link.click();
    URL.revokeObjectURL(link.href);
};
