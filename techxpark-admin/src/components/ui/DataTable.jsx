import React from 'react';
import { Search, ChevronLeft, ChevronRight, ArrowUpDown } from 'lucide-react';
import Badge from './Badge';
import Avatar from './Avatar';

export default function DataTable({
    columns,
    data,
    onRowClick,
    searchable = true,
    searchTerm = '',
    onSearchChange,
    pagination = true,
    currentPage = 1,
    totalPages = 1,
    onPageChange,
    loading = false
}) {
    return (
        <div className="bg-surface rounded-2xl border border-border shadow-sm overflow-hidden flex flex-col">

            {/* Toolbar */}
            {searchable && (
                <div className="p-5 border-b border-border flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-bg-light/50">
                    <div className="relative max-w-sm w-full">
                        <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-text-tertiary" />
                        <input
                            type="text"
                            placeholder="Search records..."
                            value={searchTerm}
                            onChange={(e) => onSearchChange?.(e.target.value)}
                            className="w-full pl-10 pr-4 py-2 bg-white border border-border rounded-lg text-[13px] font-medium focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all shadow-sm"
                        />
                    </div>
                </div>
            )}

            {/* Table Container */}
            <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                    <thead>
                        <tr className="bg-bg-light/80 border-b border-border">
                            {columns.map((col, idx) => (
                                <th
                                    key={idx}
                                    className={`py-3.5 px-6 text-[11px] font-bold text-text-secondary uppercase tracking-[1px] ${col.sortable ? 'cursor-pointer hover:bg-surface-hover hover:text-text-primary transition-colors group' : ''}`}
                                >
                                    <div className={`flex items-center gap-1 ${col.align === 'right' ? 'justify-end' : col.align === 'center' ? 'justify-center' : 'justify-start'}`}>
                                        {col.header}
                                        {col.sortable && (
                                            <ArrowUpDown className="w-3 h-3 text-border group-hover:text-text-secondary transition-colors" />
                                        )}
                                    </div>
                                </th>
                            ))}
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-border">
                        {loading ? (
                            <tr>
                                <td colSpan={columns.length} className="px-6 py-12 text-center text-text-tertiary">
                                    <div className="flex flex-col items-center justify-center gap-3">
                                        <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin"></div>
                                        <span className="text-[13px] font-medium">Loading data...</span>
                                    </div>
                                </td>
                            </tr>
                        ) : data.length === 0 ? (
                            <tr>
                                <td colSpan={columns.length} className="px-6 py-12 text-center text-text-tertiary">
                                    <span className="text-[13px] font-medium">No records found matching your criteria.</span>
                                </td>
                            </tr>
                        ) : (
                            data.map((row, rowIdx) => (
                                <tr
                                    key={row.id || rowIdx}
                                    onClick={() => onRowClick?.(row)}
                                    className={`group hover:bg-bg-light/50 transition-colors ${onRowClick ? 'cursor-pointer' : ''}`}
                                >
                                    {columns.map((col, colIdx) => (
                                        <td
                                            key={colIdx}
                                            className={`px-6 py-4 text-[13px] ${col.align === 'right' ? 'text-right' : col.align === 'center' ? 'text-center' : 'text-left'}`}
                                        >
                                            {col.cell ? col.cell(row) : row[col.accessor]}
                                        </td>
                                    ))}
                                </tr>
                            ))
                        )}
                    </tbody>
                </table>
            </div>

            {/* Pagination Controls */}
            {pagination && data.length > 0 && !loading && (
                <div className="px-6 py-4 border-t border-border flex items-center justify-between text-[13px]">
                    <span className="font-semibold text-text-secondary">
                        Page <span className="text-text-primary">{currentPage}</span> of <span className="text-text-primary">{totalPages}</span>
                    </span>
                    <div className="flex items-center gap-2">
                        <button
                            disabled={currentPage === 1}
                            onClick={() => onPageChange?.(currentPage - 1)}
                            className="p-1.5 rounded-lg border border-border text-text-secondary hover:bg-bg-light hover:text-text-primary disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                        >
                            <ChevronLeft className="w-4 h-4" />
                        </button>
                        <button
                            disabled={currentPage === totalPages}
                            onClick={() => onPageChange?.(currentPage + 1)}
                            className="p-1.5 rounded-lg border border-border text-text-secondary hover:bg-bg-light hover:text-text-primary disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                        >
                            <ChevronRight className="w-4 h-4" />
                        </button>
                    </div>
                </div>
            )}

        </div>
    );
}
