/** @type {import('tailwindcss').Config} */
export default {
    content: [
      "./index.html",
      "./src/**/*.{js,ts,jsx,tsx}",
    ],
    theme: {
      extend: {
        colors: {
          primary: 'var(--primary)',
          'primary-dark': 'var(--primary-dark)',
          'primary-light': 'var(--primary-light)',
          'bg-light': 'var(--bg)',
          surface: 'var(--surface)',
          'surface-hover': 'var(--border)',
          border: 'var(--border)',
          'text-primary': 'var(--text-primary)',
          'text-secondary': 'var(--text-secondary)',
          'text-tertiary': 'var(--text-tertiary)',
          success: 'var(--success)',
          'success-bg': 'rgba(13, 158, 110, 0.1)',
          'success-text': '#065F46', // Darker success for text
          error: 'var(--error)',
          'error-bg': 'rgba(229, 57, 59, 0.1)',
          'error-text': '#991B1B', // Darker error for text
          warning: 'var(--warning)',
          'warning-bg': 'rgba(217, 119, 6, 0.1)',
          info: 'var(--primary)',
          'info-bg': 'rgba(40, 69, 214, 0.1)',
          'sidebar-bg': 'var(--sidebar-bg)',
          'sidebar-border': 'var(--sidebar-border)',
          'sidebar-text': 'rgba(255, 255, 255, 0.7)',
          'sidebar-hover': 'rgba(255, 255, 255, 0.05)',
          'sidebar-active': 'rgba(40, 69, 214, 0.15)',
          'sidebar-active-border': 'var(--primary)',
        },
        fontFamily: {
          sans: ['Inter', 'sans-serif'],
          mono: ['JetBrains Mono', 'monospace'],
        },
        boxShadow: {
            'sm': '0 1px 2px 0 rgba(0, 0, 0, 0.05)',
            'md': '0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.03)',
            'lg': '0 10px 15px -3px rgba(0, 0, 0, 0.05), 0 4px 6px -2px rgba(0, 0, 0, 0.025)',
            'xl': '0 20px 25px -5px rgba(0, 0, 0, 0.05), 0 10px 10px -5px rgba(0, 0, 0, 0.02)',
            'primary': '0 4px 14px 0 rgba(40,69,214,0.3)',
        }
      },
    },
    plugins: [],
  }
