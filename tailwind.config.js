/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        surface: {
          DEFAULT: '#F8F7F4',
          mid: '#FFFFFF',
          up: '#F0EFEB'
        },
        accent: {
          DEFAULT: '#2B9B8F',
          light: '#3DB5A8',
          dark: '#1F7A70',
          subtle: 'rgba(43,155,143,0.08)'
        },
        cold: '#7C9AB5',
        muted: '#9B97A2',
        success: '#34B888',
        warning: '#E5A63E',
        danger: '#E25B5B',
        cream: '#2D2A33'
      },
      fontFamily: {
        logo: ['"Plus Jakarta Sans"', 'sans-serif'],
        heading: ['"Plus Jakarta Sans"', 'sans-serif'],
        display: ['"Plus Jakarta Sans"', 'sans-serif'],
        body: ['"Inter"', 'sans-serif']
      },
      fontSize: {
        'xs': ['0.8125rem', { lineHeight: '1.25rem' }],
        'sm': ['0.9375rem', { lineHeight: '1.375rem' }],
        'base': ['1.0625rem', { lineHeight: '1.625rem' }],
        'lg': ['1.1875rem', { lineHeight: '1.75rem' }],
      },
      animation: {
        'fade-in': 'fadeIn 0.3s ease-out',
        'slide-up': 'slideUp 0.3s ease-out',
        'pulse-accent': 'pulseAccent 2s infinite',
        'pop': 'pop 0.3s cubic-bezier(0.34, 1.56, 0.64, 1)',
        'wiggle': 'wiggle 0.5s ease-in-out',
        'confetti': 'confetti 0.6s ease-out',
      },
      keyframes: {
        fadeIn: { '0%': { opacity: '0' }, '100%': { opacity: '1' } },
        slideUp: { '0%': { opacity: '0', transform: 'translateY(12px)' }, '100%': { opacity: '1', transform: 'translateY(0)' } },
        pulseAccent: { '0%, 100%': { opacity: '1' }, '50%': { opacity: '0.6' } },
        pop: { '0%': { transform: 'scale(0.95)', opacity: '0.8' }, '50%': { transform: 'scale(1.02)' }, '100%': { transform: 'scale(1)', opacity: '1' } },
        wiggle: { '0%, 100%': { transform: 'rotate(0deg)' }, '25%': { transform: 'rotate(-3deg)' }, '75%': { transform: 'rotate(3deg)' } },
        confetti: { '0%': { transform: 'scale(0) rotate(0deg)', opacity: '0' }, '50%': { transform: 'scale(1.2) rotate(180deg)', opacity: '1' }, '100%': { transform: 'scale(1) rotate(360deg)', opacity: '1' } },
      },
      screens: {
        desktop: '900px'
      },
      borderRadius: {
        'sm': '0.75rem'
      },
      boxShadow: {
        'soft': '0 2px 8px rgba(0,0,0,0.04), 0 1px 2px rgba(0,0,0,0.03)',
        'card': '0 4px 12px rgba(0,0,0,0.05), 0 1px 3px rgba(0,0,0,0.04)',
        'glow': '0 0 20px rgba(43,155,143,0.15)',
      }
    }
  },
  plugins: []
};
