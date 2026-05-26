const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://yhklvtzonvgzkodysawu.supabase.co',
);
const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inloa2x2dHpvbnZnemtvZHlzYXd1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0OTgyMzYsImV4cCI6MjA5MTA3NDIzNn0.K0sxdzG1C1ytFU7Zb-ZCY2tCyEG2ryVUE-7SNdmo7xc',
);
const String functionsBase = '$supabaseUrl/functions/v1';
const String restBase = '$supabaseUrl/rest/v1';
