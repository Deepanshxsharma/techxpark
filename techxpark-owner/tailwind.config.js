/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#2845D6',
          dark: '#1E36B5',
          light: '#4C63E8',
        },
        brand: {
          bg: '#F6F8FF',
          sidebar: '#0F172A',
        },
        success: '#16A34A',
        error: '#EF4444',
        warning: '#F59E0B',
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
