/** App color palette — WeChat-style dark theme */
export const colors = {
  // Backgrounds
  darkBg: '#0a0a0a',
  cardBg: '#1a1a1a',
  cardBgLight: '#252525',
  divider: '#2a2a2a',

  // Primary accents
  wechatGreen: '#07c160',
  wechatGreenDark: '#05a850',

  // Text
  textPrimary: '#FFFFFF',
  textSecondary: '#999999',
  textMuted: '#666666',

  // Data colors
  heartRate: '#FF4757',
  heartRateLight: '#FF6B81',
  calories: '#FFA502',
  caloriesLight: '#FF6348',
  speed: '#2ED573',
  speedLight: '#7BED9F',
  distance: '#3B82F6',
  distanceLight: '#60A5FA',

  // UI
  blue: '#3B82F6',
  indigo: '#4F46E5',
  red: '#EF4444',
  orange: '#FF9800',
  yellow: '#FFEB3B',
  purple: '#A855F7',
  pink: '#EC4899',
  teal: '#14B8A6',
}

/** Convert hex to rgba */
export function rgba(hex: string, alpha: number): string {
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  return `rgba(${r},${g},${b},${alpha})`
}
