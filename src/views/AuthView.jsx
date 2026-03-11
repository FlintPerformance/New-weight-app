import React, { useState } from 'react';
import { useAppActions } from '../App';
import { supabase } from '../supabase';

const FEATURES = [
  { icon: ScaleIcon, text: 'Quick and easy daily weigh-ins' },
  { icon: ChartIcon, text: 'Beautiful charts to see your progress' },
  { icon: TargetIcon, text: 'Set goals and celebrate wins' },
  { icon: UsersIcon, text: 'Stay motivated with friends' },
  { icon: SyncIcon, text: 'Your data, everywhere you go' }
];

export default function AuthView() {
  const { signIn, signUp, showToast } = useAppActions();
  const [mode, setMode] = useState('signup');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [loading, setLoading] = useState(false);
  const [resetSent, setResetSent] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      if (mode === 'reset') {
        const { error } = await supabase.auth.resetPasswordForEmail(email, {
          redirectTo: window.location.origin,
        });
        if (error) throw error;
        setResetSent(true);
        showToast('Password reset email sent!', 'success');
      } else if (mode === 'login') {
        await signIn(email, password);
      } else {
        await signUp(email, password, displayName || email.split('@')[0]);
        showToast('Check your email to confirm your account', 'success');
      }
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  const heading = mode === 'signup' ? 'Join Subtle!' : mode === 'login' ? 'Welcome Back!' : 'Forgot Password?';

  return (
    <div className="h-[100dvh] bg-surface flex flex-col items-center justify-center px-6">
      <div className="w-full max-w-sm">
        {/* Brand header */}
        <div className="text-center mb-6">
          <h1 className="font-logo text-5xl tracking-tight font-extrabold text-accent">subtle</h1>
          <p className="text-sm text-muted mt-1.5">Your friendly weight companion</p>
        </div>

        {/* Feature list - compact */}
        {mode !== 'reset' && (
          <div className="flex flex-wrap justify-center gap-x-4 gap-y-1.5 mb-6">
            {FEATURES.map((f, i) => (
              <div key={i} className="flex items-center gap-1.5">
                <f.icon />
                <span className="text-cream/60 text-xs font-body">{f.text}</span>
              </div>
            ))}
          </div>
        )}

        {/* Form heading */}
        <h2 className="font-heading font-bold text-sm text-cream text-center uppercase tracking-wider mb-3">
          {heading}
        </h2>

        {mode === 'reset' && resetSent ? (
          <div className="text-center">
            <div className="bg-success/10 border border-success/20 rounded-sm p-4 mb-4">
              <p className="text-success text-sm font-medium mb-1">Email sent!</p>
              <p className="text-cream/60 text-xs">Check your inbox for a password reset link. It may take a minute to arrive.</p>
            </div>
            <button
              onClick={() => { setMode('login'); setResetSent(false); }}
              className="text-accent text-sm hover:underline"
            >
              Back to sign in
            </button>
          </div>
        ) : (
          <>
            <form onSubmit={handleSubmit} className="space-y-3">
              {mode === 'signup' && (
                <input
                  type="text"
                  value={displayName}
                  onChange={e => setDisplayName(e.target.value)}
                  placeholder="Display name"
                  className="w-full"
                  autoComplete="name"
                />
              )}

              <input
                type="email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="Email"
                required
                className="w-full"
                autoComplete="email"
              />

              {mode !== 'reset' && (
                <input
                  type="password"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="Password (min. 6 characters)"
                  required
                  minLength={6}
                  className="w-full"
                  autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
                />
              )}

              <button
                type="submit"
                disabled={loading}
                className="w-full bg-accent hover:bg-accent-dark hover:shadow-glow text-white font-heading font-bold uppercase tracking-wider py-3 rounded-sm transition-colors disabled:opacity-50 text-sm"
              >
                {loading ? 'Please wait...' : mode === 'reset' ? 'Send Reset Link' : mode === 'login' ? "Let's Go" : 'Get Started'}
              </button>
            </form>

            {mode === 'reset' ? (
              <p className="text-center mt-4 text-cream/60 text-sm">
                <button onClick={() => setMode('login')} className="text-accent hover:underline">
                  Back to sign in
                </button>
              </p>
            ) : (
              <div className="text-center mt-4 space-y-2">
                <p className="text-cream/60 text-sm">
                  {mode === 'login' ? 'New here? ' : 'Already a member? '}
                  <button
                    onClick={() => setMode(mode === 'login' ? 'signup' : 'login')}
                    className="text-accent hover:underline"
                  >
                    {mode === 'login' ? 'Sign up' : 'Sign in'}
                  </button>
                </p>
                {mode === 'login' && (
                  <p>
                    <button
                      onClick={() => setMode('reset')}
                      className="text-cream/50 text-xs hover:text-cream/60 transition-colors"
                    >
                      Need help getting in?
                    </button>
                  </p>
                )}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}

function ScaleIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="text-accent flex-shrink-0">
      <path d="M12 3v17M5 8l7-5 7 5" />
      <rect x="4" y="14" width="16" height="6" rx="1" />
    </svg>
  );
}

function ChartIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="text-accent flex-shrink-0">
      <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
    </svg>
  );
}

function TargetIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="text-accent flex-shrink-0">
      <circle cx="12" cy="12" r="10" />
      <circle cx="12" cy="12" r="6" />
      <circle cx="12" cy="12" r="2" />
    </svg>
  );
}

function UsersIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="text-accent flex-shrink-0">
      <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4-4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M23 21v-2a4 4 0 00-3-3.87" />
      <path d="M16 3.13a4 4 0 010 7.75" />
    </svg>
  );
}

function SyncIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="text-accent flex-shrink-0">
      <polyline points="23 4 23 10 17 10" />
      <polyline points="1 20 1 14 7 14" />
      <path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15" />
    </svg>
  );
}
