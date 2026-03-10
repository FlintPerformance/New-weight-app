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
      animation: {
        'fade-in': 'fadeIn 0.3s ease-out',
        'slide-up': 'slideUp 0.3s ease-out',
        'pulse-accent': 'pulseAccent 2s infinite'
      },
      keyframes: {
        fadeIn: { '0%': { opacity: '0' }, '100%': { opacity: '1' } },
        slideUp: { '0%': { opacity: '0', transform: 'translateY(12px)' }, '100%': { opacity: '1', transform: 'translateY(0)' } },
        pulseAccent: { '0%, 100%': { opacity: '1' }, '50%': { opacity: '0.6' } }
      },
      screens: {
        desktop: '900px'
      },
      borderRadius: {
        'sm': '0.5rem'
      }
    }
  },
  plugins: []
};
