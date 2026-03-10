import React, { useState } from 'react';

export default function Avatar({ url, name, size = 'md', editable = false, onUpload }) {
  const [uploading, setUploading] = useState(false);
  const initial = (name || '?')[0]?.toUpperCase();

  const sizes = {
    xs: 'w-6 h-6 text-[10px]',
    sm: 'w-8 h-8 text-xs',
    md: 'w-10 h-10 text-sm',
    lg: 'w-12 h-12 text-lg',
    xl: 'w-16 h-16 text-xl'
  };

  const handleFileChange = async (e) => {
    const file = e.target.files?.[0];
    if (!file || !onUpload) return;
    setUploading(true);
    try {
      await onUpload(file);
    } finally {
      setUploading(false);
    }
  };

  const avatar = (
    <div className={`${sizes[size]} rounded-full overflow-hidden flex-shrink-0 relative ${uploading ? 'opacity-50' : ''}`}>
      {url ? (
        <img src={url} alt={name} className="w-full h-full object-cover" />
      ) : (
        <div className="w-full h-full bg-accent/20 flex items-center justify-center text-accent font-bold">
          {initial}
        </div>
      )}
      {editable && (
        <div className="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity cursor-pointer">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-white">
            <path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z" />
            <circle cx="12" cy="13" r="4" />
          </svg>
        </div>
      )}
    </div>
  );

  if (editable) {
    return (
      <label className="cursor-pointer">
        {avatar}
        <input type="file" accept="image/*" onChange={handleFileChange} className="hidden" />
      </label>
    );
  }

  return avatar;
}
