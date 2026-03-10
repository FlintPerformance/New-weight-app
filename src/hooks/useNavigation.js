import { useState, useCallback } from 'react';

const MAX_STACK = 20;

export function useNavigation(initialView = 'dashboard') {
  const [view, setView] = useState(initialView);
  const [viewStack, setViewStack] = useState([initialView]);

  const navigate = useCallback((newView) => {
    setView(newView);
    setViewStack(prev => {
      // Don't push if already at current view
      if (prev[prev.length - 1] === newView) return prev;
      const next = [...prev, newView];
      // Cap stack size to prevent memory leak
      return next.length > MAX_STACK ? next.slice(-MAX_STACK) : next;
    });
  }, []);

  const goBack = useCallback(() => {
    setViewStack(prev => {
      if (prev.length <= 1) return prev;
      const next = prev.slice(0, -1);
      setView(next[next.length - 1]);
      return next;
    });
  }, []);

  return { view, navigate, goBack };
}
