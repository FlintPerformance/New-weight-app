import React, { useEffect, useState } from 'react';

export default function Toast({ message, type = 'success' }) {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    // Trigger entrance animation
    requestAnimationFrame(() => setVisible(true));
    const timer = setTimeout(() => setVisible(false), 2600);
    return () => clearTimeout(timer);
  }, [message]);

  const bg = type === 'error' ? 'bg-danger' : type === 'warning' ? 'bg-warning text-surface' : 'bg-accent';
  const icon = type === 'error' ? '!' : type === 'warning' ? '!' : null;

  return (
    <div
      className="fixed left-1/2 -translate-x-1/2 z-[100] pointer-events-none transition-all duration-300"
      style={{
        top: 'calc(env(safe-area-inset-top, 0px) + 12px)',
        opacity: visible ? 1 : 0,
        transform: `translateX(-50%) translateY(${visible ? '0' : '-8px'})`,
      }}
    >
      <div className={`${bg} text-white px-4 py-2.5 rounded-sm shadow-lg text-sm font-medium flex items-center gap-2 max-w-xs`}>
        {icon && (
          <span className="w-5 h-5 rounded-full bg-white/20 flex items-center justify-center text-xs font-bold shrink-0">
            {icon}
          </span>
        )}
        <span>{message}</span>
      </div>
    </div>
  );
}
