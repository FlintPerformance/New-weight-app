import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || 'https://ytvnytocmratapdwmzns.supabase.co';
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0dm55dG9jbXJhdGFwZHdtem5zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5OTE0MTEsImV4cCI6MjA4ODU2NzQxMX0.rGNqxoqDp-ySeLulS-2VAriht21NFMkY_tbBwabF5hM';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
