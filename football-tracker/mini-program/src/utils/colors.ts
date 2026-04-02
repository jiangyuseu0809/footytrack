/** App color palette — matches iOS FootballTracker dark theme */
export const colors = {
  // Backgrounds
  darkBg: '#0D1117',
  cardBg: '#1C2333',
  cardBgLight: '#242D3D',
  divider: '#30363D',

  // Primary accents
  neonGreen: '#00E676',
  teal: '#00BFA5',

  // Text
  textPrimary: '#FFFFFF',
  textSecondary: '#8B949E',

  // Data colors
  heartRate: '#FF4757',
  heartRateLight: '#FF6B81',
  calories: '#FFA502',
  caloriesLight: '#FF6348',
  speed: '#2ED573',
  speedLight: '#7BED9F',
  distance: '#00E676',
  distanceLight: '#69F0AE',

  // UI
  blue: '#3B82F6',
  indigo: '#4F46E5',
  red: '#E53935',
  orange: '#FF9800',
  yellow: '#FFEB3B',
}

/** Convert hex to rgba */
export function rgba(hex: string, alpha: number): string {
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  return `rgba(${r},${g},${b},${alpha})`
}
