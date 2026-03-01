import React from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import SkeletonLoader from './SkeletonLoader';

export default function DataTable({
    columns,
    data,
    loading = false,
    onRowClick,
    pagination,
    emptyState
}) {
    return (
        <div className="bg-white border border-border rounded-[14px] overflow-hidden shadow-xs flex flex-col h-full">
            <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                    <thead>
                        <tr className="bg-surface-2 border-b border-border">
                            {columns.map((col, i) => (
                                <th
                                    key={i}
                                    className={`px-5 py-3 text-[11px] font-semibold text-text-tertiary uppercase tracking-[0.8px] ${col.align === 'right' ? 'text-right' : ''} ${col.className || ''}`}
                                >
                                    {col.header}
                                </th>
                            ))}
                        </tr>
                    </thead>
                    <tbody>
                        {loading ? (
                            Array.from({ length: 5 }).map((_, rowIndex) => (
                                <tr key={rowIndex} className="border-b border-border/50">
                                    {columns.map((col, colIndex) => (
                                        <td key={colIndex} className="px-5 py-4">
                                            <SkeletonLoader height="h-5" className="w-3/4 rounded-md" />
                                        </td>
                                    ))}
                                </tr>
                            ))
                        ) : data.length === 0 ? (
                            <tr>
                                <td colSpan={columns.length} className="p-0">
                                    {emptyState || (
                                        <div className="py-12 text-center text-text-tertiary">
                                            No data available
                                        </div>
                                    )}
                                </td>
                            </tr>
                        ) : (
                            data.map((row, rowIndex) => (
                                <tr
                                    key={row.id || rowIndex}
                                    onClick={() => onRowClick && onRowClick(row)}
                                    className={`border-b border-surface-2 hover:bg-surface-2 transition-colors duration-150 ${onRowClick ? 'cursor-pointer' : ''}`}
                                >
                                    {columns.map((col, colIndex) => (
                                        <td
                                            key={colIndex}
                                            className={`px-5 py-4 ${col.align === 'right' ? 'text-right' : ''} ${col.cellClassName || ''}`}
                                        >
                                            {col.render ? col.render(row) : row[col.accessor]}
                                        </td>
                                    ))}
                                </tr>
                            ))
                        )}
                    </tbody>
                </table>
            </div>

            {/* Footer / Pagination */}
            {pagination && !loading && data.length > 0 && (
                <div className="mt-auto px-5 py-3 border-t border-border bg-white flex items-center justify-between text-sm text-text-secondary">
                    <div>
                        Showing <span className="font-medium text-text-primary">1-{Math.min(20, data.length)}</span> of <span className="font-medium text-text-primary">{data.length}</span> results
                    </div>
                    <div className="flex items-center gap-2">
                        <button className="p-1.5 rounded-md hover:bg-surface-hover text-text-tertiary hover:text-text-primary disabled:opacity-50" disabled>
                            <ChevronLeft className="w-4 h-4" />
                        </button>
                        <button className="p-1.5 rounded-md hover:bg-surface-hover text-text-tertiary hover:text-text-primary">
                            <ChevronRight className="w-4 h-4" />
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}
