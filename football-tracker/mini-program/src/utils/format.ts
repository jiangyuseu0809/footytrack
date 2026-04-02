/** Format seconds into "mm:ss" or "h:mm:ss" */
export function formatDuration(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000)
  const h = Math.floor(totalSeconds / 3600)
  const m = Math.floor((totalSeconds % 3600) / 60)
  const s = totalSeconds % 60
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
  return `${m}:${String(s).padStart(2, '0')}`
}

/** Format distance in meters to "x.x km" or "x m" */
export function formatDistance(meters?: number): string {
  if (!meters) return '0 m'
  if (meters >= 1000) return `${(meters / 1000).toFixed(1)} km`
  return `${Math.round(meters)} m`
}

/** Format date from timestamp (ms) */
export function formatDate(ts: number): string {
  const d = new Date(ts)
  const month = d.getMonth() + 1
  const day = d.getDate()
  return `${month}月${day}日`
}

/** Format date with time */
export function formatDateTime(ts: number): string {
  const d = new Date(ts)
  const month = d.getMonth() + 1
  const day = d.getDate()
  const hours = String(d.getHours()).padStart(2, '0')
  const mins = String(d.getMinutes()).padStart(2, '0')
  return `${month}月${day}日 ${hours}:${mins}`
}

/** Format weekday from timestamp */
export function formatWeekday(ts: number): string {
  const days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
  return days[new Date(ts).getDay()]
}

/** Get "今天" / "昨天" / date string */
export function formatRelativeDate(ts: number): string {
  const now = new Date()
  const d = new Date(ts)
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const target = new Date(d.getFullYear(), d.getMonth(), d.getDate())
  const diff = (today.getTime() - target.getTime()) / 86400000

  if (diff === 0) return '今天'
  if (diff === 1) return '昨天'
  return formatDate(ts)
}

/** Compute performance score (matches iOS logic) */
export function computePerformanceScore(session: {
  avgSpeedKmh?: number
  maxSpeedKmh?: number
  sprintCount?: number
  totalDistanceMeters?: number
  slackIndex?: number
}): number {
  const speed = Math.min(10, ((session.avgSpeedKmh || 0) / 12) * 10)
  const sprint = Math.min(10, ((session.sprintCount || 0) / 20) * 10)
  const dist = Math.min(10, ((session.totalDistanceMeters || 0) / 8000) * 10)
  const discipline = Math.max(0, 10 - (session.slackIndex || 0) / 10)
  const raw = speed * 0.3 + sprint * 0.25 + dist * 0.25 + discipline * 0.2
  return Math.max(6, Math.min(10, Math.round(raw * 10) / 10))
}
