<template>
  <view class="page">
    <!-- Header -->
    <view class="header">
      <text class="header-title">FootyTrack</text>
      <view v-if="isWatchConnected" class="watch-badge connected">
        <text class="watch-badge-text">⌚ 已连接</text>
      </view>
      <view v-else class="watch-badge disconnected" @tap="goBindWatch">
        <text class="watch-badge-text">⌚ 连接 Watch</text>
      </view>
    </view>

    <scroll-view scroll-y class="scroll-content">
      <!-- Upcoming Matches -->
      <view v-if="visibleMatches.length" class="section">
        <view class="upcoming-list">
          <view
            v-for="m in visibleMatches"
            :key="m.id"
            class="upcoming-card"
            @tap="goMatchDetail(m.id)"
          >
            <view class="upcoming-card-top">
              <text class="upcoming-name">{{ m.title }}</text>
              <view class="match-status-tag" :class="'match-status--' + getMatchStatus(m.matchDate).type">
                <text class="match-status-tag-text">{{ getMatchStatus(m.matchDate).label }}</text>
              </view>
              <text class="upcoming-arrow">›</text>
            </view>
            <view class="upcoming-info-rows">
              <view class="upcoming-info-row">
                <text class="upcoming-info-icon">📍</text>
                <text class="upcoming-info-text">{{ m.location }}</text>
              </view>
              <view class="upcoming-info-row">
                <text class="upcoming-info-icon">📅</text>
                <text class="upcoming-info-text">{{ formatMatchTime(m.matchDate) }}</text>
              </view>
              <view class="upcoming-info-row">
                <text class="upcoming-info-icon">👥</text>
                <text class="upcoming-info-text">{{ m.registrationCount }}/{{ m.maxPlayers || m.groups * m.playersPerGroup }} 人已报名</text>
              </view>
            </view>
          </view>
        </view>
      </view>

      <!-- Time Range Toggle -->
      <view class="section">
        <view class="toggle-bar">
          <view
            class="toggle-item"
            :class="{ active: timeRange === 'week' }"
            @tap="timeRange = 'week'"
          >
            <text class="toggle-text" :class="{ active: timeRange === 'week' }">本周数据</text>
          </view>
          <view
            class="toggle-item"
            :class="{ active: timeRange === 'today' }"
            @tap="timeRange = 'today'"
          >
            <text class="toggle-text" :class="{ active: timeRange === 'today' }">今日数据</text>
          </view>
        </view>
      </view>

      <!-- Matches Count -->
      <view class="section">
        <view class="match-count-card">
          <view class="match-count-left">
            <text class="match-count-label">{{ timeRange === 'week' ? '本周' : '今日' }}踢球次数</text>
            <text class="match-count-value">{{ currentStats.matches }}</text>
          </view>
          <view class="match-count-icon">
            <text class="match-count-emoji">📅</text>
          </view>
        </view>
      </view>

      <!-- Core Stats Grid -->
      <view class="section">
        <view class="stats-grid">
          <view class="stats-card">
            <view class="stats-icon-box orange-red">
              <text class="stats-icon">🔥</text>
            </view>
            <text class="stats-label">热量消耗</text>
            <text class="stats-value">{{ currentStats.calories }}</text>
            <text class="stats-unit">kcal</text>
          </view>
          <view class="stats-card">
            <view class="stats-icon-box blue">
              <text class="stats-icon">📍</text>
            </view>
            <text class="stats-label">跑动距离</text>
            <text class="stats-value">{{ currentStats.distance }}</text>
            <text class="stats-unit">km</text>
          </view>
          <view class="stats-card">
            <view class="stats-icon-box yellow-orange">
              <text class="stats-icon">⚡</text>
            </view>
            <text class="stats-label">冲刺次数</text>
            <text class="stats-value">{{ currentStats.sprints }}</text>
            <text class="stats-unit">次</text>
          </view>
          <view class="stats-card">
            <view class="stats-icon-box purple">
              <text class="stats-icon">⏱️</text>
            </view>
            <text class="stats-label">运动时间</text>
            <text class="stats-value">{{ currentStats.duration }}</text>
            <text class="stats-unit">分钟</text>
          </view>
          <view class="stats-card">
            <view class="stats-icon-box pink-red">
              <text class="stats-icon">❤️</text>
            </view>
            <text class="stats-label">最高心率</text>
            <text class="stats-value">{{ currentStats.maxHeartRate }}</text>
            <text class="stats-unit">bpm</text>
          </view>
          <view class="stats-card">
            <view class="stats-icon-box green-teal">
              <text class="stats-icon">❤️</text>
            </view>
            <text class="stats-label">平均心率</text>
            <text class="stats-value">{{ currentStats.avgHeartRate }}</text>
            <text class="stats-unit">bpm</text>
          </view>
        </view>
      </view>

      <!-- Ability Radar Placeholder -->
      <view class="section">
        <view class="chart-card">
          <view class="chart-header">
            <text class="chart-header-icon">🎯</text>
            <text class="chart-header-title">{{ timeRange === 'week' ? '本周能力分析' : '今日能力分析' }}</text>
          </view>
          <view class="radar-canvas-wrap">
            <image v-if="radarImage" :src="radarImage" class="radar-image" mode="aspectFit" />
          </view>
        </view>
      </view>

      <!-- Heat Map (today only) -->
      <view v-if="timeRange === 'today'" class="section">
        <view class="chart-card">
          <text class="chart-card-title">今日跑动热力图</text>
          <view class="heatmap-box">
            <view class="field-outline">
              <view class="field-center-line" />
              <view class="field-center-circle" />
            </view>
            <image v-if="heatmapImage" :src="heatmapImage" class="heatmap-image" mode="aspectFill" />
          </view>
          <view class="heatmap-legend">
            <text class="legend-text">低活跃度</text>
            <view class="legend-bar" />
            <text class="legend-text">高活跃度</text>
          </view>
        </view>
      </view>

      <!-- Share Button -->
      <view class="section section--last">
        <view class="share-btn" @tap="handleShare">
          <text class="share-btn-text">📤 分享{{ timeRange === 'week' ? '本周' : '今日' }}运动数据</text>
        </view>
      </view>
    </scroll-view>

    <!-- Hidden canvas for radar chart rendering -->
    <canvas canvas-id="radarCanvas" id="radarCanvas" class="offscreen-canvas" />
    <canvas canvas-id="heatmapCanvas" id="heatmapCanvas" class="offscreen-canvas offscreen-canvas--heatmap" />
  </view>
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { getSessions, getMatches, isLoggedIn, type SessionDto, type Match } from '../../utils/api'
import { formatDateTime, formatWeekday } from '../../utils/format'

const timeRange = ref<'week' | 'today'>('week')
const sessions = ref<SessionDto[]>([])
const upcomingMatches = ref<Match[]>([])
const isWatchConnected = ref(false)
const radarImage = ref('')
const heatmapImage = ref('')

const weekSessions = computed(() => {
  const now = new Date()
  const weekStart = new Date(now)
  weekStart.setDate(now.getDate() - now.getDay())
  weekStart.setHours(0, 0, 0, 0)
  return sessions.value.filter(s => s.startTime >= weekStart.getTime())
})

const todaySessions = computed(() => {
  const now = new Date()
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  return sessions.value.filter(s => s.startTime >= todayStart)
})

const currentStats = computed(() => {
  const list = timeRange.value === 'week' ? weekSessions.value : todaySessions.value
  const totalDistance = list.reduce((sum, s) => sum + (s.totalDistanceMeters || 0), 0)
  const totalCalories = Math.round(list.reduce((sum, s) => sum + (s.caloriesBurned || 0), 0))
  const totalSprints = list.reduce((sum, s) => sum + (s.sprintCount || 0), 0)
  const totalDuration = Math.round(list.reduce((sum, s) => sum + ((s.endTime - s.startTime) / 60000), 0))
  const maxHR = list.length ? Math.max(...list.map(s => s.maxHeartRate || 0)) : 0
  const avgHR = list.length ? Math.round(list.reduce((sum, s) => sum + (s.avgHeartRate || 0), 0) / list.length) : 0
  return {
    matches: list.length,
    calories: totalCalories,
    distance: (totalDistance / 1000).toFixed(1),
    sprints: totalSprints,
    duration: totalDuration,
    maxHeartRate: maxHR,
    avgHeartRate: avgHR,
  }
})

const abilityData = computed(() => {
  const list = timeRange.value === 'week' ? weekSessions.value : todaySessions.value
  if (list.length === 0) {
    return [
      { ability: '速度', value: 0 },
      { ability: '耐力', value: 0 },
      { ability: '爆发力', value: 0 },
      { ability: '灵活性', value: 0 },
      { ability: '体能', value: 0 },
      { ability: '持久力', value: 0 },
    ]
  }
  const avgSpeed = list.reduce((s, v) => s + (v.avgSpeedKmh || 0), 0) / list.length
  const maxSpeed = Math.max(...list.map(s => s.maxSpeedKmh || 0))
  const avgDist = list.reduce((s, v) => s + (v.totalDistanceMeters || 0), 0) / list.length / 1000
  const totalSprints = list.reduce((s, v) => s + (v.sprintCount || 0), 0)
  return [
    { ability: '速度', value: Math.min(100, Math.round(maxSpeed * 4)) },
    { ability: '耐力', value: Math.min(100, Math.round(avgDist * 15)) },
    { ability: '爆发力', value: Math.min(100, Math.round(totalSprints * 5)) },
    { ability: '灵活性', value: Math.min(100, Math.round(avgSpeed * 8)) },
    { ability: '体能', value: Math.min(100, Math.round((avgDist + avgSpeed) * 6)) },
    { ability: '持久力', value: Math.min(100, Math.round(avgDist * 12)) },
  ]
})

async function loadData() {
  if (!isLoggedIn()) return
  try {
    const [sessRes, matchRes] = await Promise.all([getSessions(), getMatches()])
    sessions.value = sessRes.sessions
    upcomingMatches.value = matchRes.matches
  } catch (e) {
    console.error('Failed to load home data', e)
  }
}

function getMatchStatus(matchDate: number): { type: string; label: string } {
  const now = Date.now()
  const diff = now - matchDate
  if (diff < 0) return { type: 'upcoming', label: '即将开赛' }
  if (diff < 2 * 3600 * 1000) return { type: 'live', label: '进行中' }
  return { type: 'finished', label: '比赛完结' }
}

const visibleMatches = computed(() => {
  const now = Date.now()
  const twelveHours = 12 * 3600 * 1000
  return upcomingMatches.value.filter(m => now - m.matchDate < twelveHours)
})

function formatMatchTime(ts: number): string {
  return `${formatWeekday(ts)} ${formatDateTime(ts)}`
}

function goMatchDetail(id: string) {
  uni.navigateTo({ url: `/pages/match-detail/index?id=${id}` })
}

function goBindWatch() {
  uni.navigateTo({ url: '/pages/bind-watch/index' })
}

function handleShare() {
  // WeChat share placeholder
}

function drawRadar() {
  const ctx = uni.createCanvasContext('radarCanvas')
  const data = abilityData.value
  const count = data.length
  if (count === 0) return

  // Canvas size in px (will be scaled by device pixel ratio via CSS)
  const size = 280
  const cx = size / 2
  const cy = size / 2
  const maxR = size / 2 - 40
  const levels = 4
  const angleStep = (Math.PI * 2) / count
  const startAngle = -Math.PI / 2

  // Clear
  ctx.clearRect(0, 0, size, size)

  // Draw grid rings
  for (let lv = 1; lv <= levels; lv++) {
    const r = (maxR / levels) * lv
    ctx.beginPath()
    for (let i = 0; i <= count; i++) {
      const angle = startAngle + angleStep * (i % count)
      const x = cx + r * Math.cos(angle)
      const y = cy + r * Math.sin(angle)
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.closePath()
    ctx.setStrokeStyle('rgba(255,255,255,0.08)')
    ctx.setLineWidth(1)
    ctx.stroke()
  }

  // Draw axis lines
  for (let i = 0; i < count; i++) {
    const angle = startAngle + angleStep * i
    ctx.beginPath()
    ctx.moveTo(cx, cy)
    ctx.lineTo(cx + maxR * Math.cos(angle), cy + maxR * Math.sin(angle))
    ctx.setStrokeStyle('rgba(255,255,255,0.06)')
    ctx.setLineWidth(1)
    ctx.stroke()
  }

  // Draw data area
  ctx.beginPath()
  for (let i = 0; i <= count; i++) {
    const idx = i % count
    const angle = startAngle + angleStep * idx
    const r = (data[idx].value / 100) * maxR
    const x = cx + r * Math.cos(angle)
    const y = cy + r * Math.sin(angle)
    if (i === 0) ctx.moveTo(x, y)
    else ctx.lineTo(x, y)
  }
  ctx.closePath()
  ctx.setFillStyle('rgba(7,193,96,0.3)')
  ctx.fill()
  ctx.setStrokeStyle('#07c160')
  ctx.setLineWidth(2)
  ctx.stroke()

  // Draw data points
  for (let i = 0; i < count; i++) {
    const angle = startAngle + angleStep * i
    const r = (data[i].value / 100) * maxR
    const x = cx + r * Math.cos(angle)
    const y = cy + r * Math.sin(angle)
    ctx.beginPath()
    ctx.arc(x, y, 3, 0, Math.PI * 2)
    ctx.setFillStyle('#07c160')
    ctx.fill()
  }

  // Draw labels
  ctx.setFontSize(11)
  ctx.setTextAlign('center')
  ctx.setTextBaseline('middle')
  ctx.setFillStyle('#999999')
  for (let i = 0; i < count; i++) {
    const angle = startAngle + angleStep * i
    const labelR = maxR + 20
    const x = cx + labelR * Math.cos(angle)
    const y = cy + labelR * Math.sin(angle)
    ctx.fillText(data[i].ability, x, y)
  }

  ctx.draw(false, () => {
    setTimeout(() => {
      uni.canvasToTempFilePath({
        canvasId: 'radarCanvas',
        success: (res) => { radarImage.value = res.tempFilePath },
        fail: (err) => { console.error('canvasToTempFilePath fail', err) },
      })
    }, 150)
  })
}

interface TrackPoint {
  latitude: number
  longitude: number
  speed: number
}

function parseTrackPoints(sessions: SessionDto[]): TrackPoint[] {
  const points: TrackPoint[] = []
  for (const s of sessions) {
    if (!s.trackPointsData) continue
    try {
      const json = decodeURIComponent(escape(atob(s.trackPointsData)))
      const arr = JSON.parse(json) as any[]
      for (const p of arr) {
        if (p.latitude && p.longitude) {
          points.push({ latitude: p.latitude, longitude: p.longitude, speed: p.speed || 0 })
        }
      }
    } catch {}
  }
  return points
}

function drawHeatmap() {
  const ctx = uni.createCanvasContext('heatmapCanvas')
  const w = 350
  const h = 263 // 4:3 ratio

  ctx.clearRect(0, 0, w, h)

  // Dark green base (low activity)
  ctx.setFillStyle('#0a2a0f')
  ctx.fillRect(0, 0, w, h)

  const points = parseTrackPoints(todaySessions.value)

  if (points.length > 0) {
    // Compute bounding box
    let minLat = Infinity, maxLat = -Infinity, minLng = Infinity, maxLng = -Infinity
    for (const p of points) {
      if (p.latitude < minLat) minLat = p.latitude
      if (p.latitude > maxLat) maxLat = p.latitude
      if (p.longitude < minLng) minLng = p.longitude
      if (p.longitude > maxLng) maxLng = p.longitude
    }

    // Add padding
    const latPad = Math.max((maxLat - minLat) * 0.1, 0.0002)
    const lngPad = Math.max((maxLng - minLng) * 0.1, 0.0002)
    minLat -= latPad; maxLat += latPad
    minLng -= lngPad; maxLng += lngPad

    const latRange = maxLat - minLat || 0.001
    const lngRange = maxLng - minLng || 0.001

    // Find max speed for normalization
    const maxSpeed = Math.max(...points.map(p => p.speed), 1)

    // Draw heat blobs
    for (const p of points) {
      const x = ((p.longitude - minLng) / lngRange) * w
      const y = (1 - (p.latitude - minLat) / latRange) * h // flip Y
      const intensity = Math.min(p.speed / maxSpeed, 1)
      const radius = 8 + intensity * 8

      // Color: green(low) → yellow → red(high)
      let r: number, g: number, b: number
      if (intensity < 0.5) {
        const t = intensity * 2
        r = Math.round(22 + t * (234 - 22))
        g = Math.round(163 + t * (179 - 163))
        b = Math.round(74 - t * 74)
      } else {
        const t = (intensity - 0.5) * 2
        r = Math.round(234 + t * (239 - 234))
        g = Math.round(179 - t * (179 - 68))
        b = Math.round(0 + t * 68)
      }

      const alpha = 0.35 + intensity * 0.35
      ctx.beginPath()
      ctx.arc(x, y, radius, 0, Math.PI * 2)
      ctx.setFillStyle(`rgba(${r},${g},${b},${alpha})`)
      ctx.fill()
    }
  }

  ctx.draw(false, () => {
    setTimeout(() => {
      uni.canvasToTempFilePath({
        canvasId: 'heatmapCanvas',
        success: (res) => { heatmapImage.value = res.tempFilePath },
        fail: (err) => { console.error('heatmap canvasToTempFilePath fail', err) },
      })
    }, 150)
  })
}

watch([timeRange, abilityData], () => {
  nextTick(() => {
    setTimeout(() => drawRadar(), 100)
    setTimeout(() => drawHeatmap(), 100)
  })
})

onShow(() => {
  loadData()
  nextTick(() => {
    setTimeout(() => drawRadar(), 300)
    setTimeout(() => drawHeatmap(), 400)
  })
})
</script>

<style lang="scss" scoped>
$pageBg: #0a0a0a;
$cardBg: #1a1a1a;
$border: 1rpx solid #2a2a2a;
$green: #07c160;
$greenDark: #05a850;
$textPrimary: #FFFFFF;
$textSecondary: #999;
$textMuted: #666;

.page {
  min-height: 100vh;
  background: $pageBg;
  display: flex;
  flex-direction: column;
}

.scroll-content {
  flex: 1;
  height: calc(100vh - 260rpx);
}

// ============================================================
// Header
// ============================================================
.header {
  background: linear-gradient(135deg, $green, $greenDark);
  padding: 100rpx 32rpx 48rpx;
  box-shadow: 0 8rpx 32rpx rgba(7, 193, 96, 0.2);
}

.header-title {
  font-size: 44rpx;
  font-weight: 700;
  color: $textPrimary;
  display: block;
  margin-bottom: 20rpx;
}

.watch-badge {
  display: inline-flex;
  align-items: center;
  padding: 10rpx 20rpx;
  border-radius: 100rpx;
}

.watch-badge.connected {
  background: rgba(255, 255, 255, 0.2);
}

.watch-badge.disconnected {
  background: #FFFFFF;
}

.watch-badge-text {
  font-size: 24rpx;
  font-weight: 500;
}

.watch-badge.connected .watch-badge-text {
  color: $textPrimary;
}

.watch-badge.disconnected .watch-badge-text {
  color: $green;
}

// ============================================================
// Sections
// ============================================================
.section {
  padding: 0 32rpx 24rpx;
  &:first-child {
    padding-top: 24rpx;
  }
}

.section--last {
  padding-bottom: 160rpx;
}

// ============================================================
// Upcoming Matches
// ============================================================
.upcoming-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.upcoming-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 28rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.upcoming-card-top {
  display: flex;
  align-items: center;
  margin-bottom: 20rpx;
}

.upcoming-name {
  flex: 1;
  font-size: 30rpx;
  font-weight: 600;
  color: $textPrimary;
}

.match-status-tag {
  padding: 4rpx 16rpx;
  border-radius: 8rpx;
  margin-right: 12rpx;
  flex-shrink: 0;
}

.match-status--upcoming {
  background: rgba(7, 193, 96, 0.15);
}

.match-status--live {
  background: rgba(250, 204, 21, 0.2);
}

.match-status--finished {
  background: rgba(255, 255, 255, 0.08);
}

.match-status-tag-text {
  font-size: 22rpx;
  font-weight: 500;
}

.match-status--upcoming .match-status-tag-text {
  color: $green;
}

.match-status--live .match-status-tag-text {
  color: #FACC15;
}

.match-status--finished .match-status-tag-text {
  color: $textSecondary;
}

.upcoming-arrow {
  font-size: 36rpx;
  color: $textMuted;
  font-weight: 300;
  flex-shrink: 0;
}

.upcoming-info-rows {
  display: flex;
  flex-direction: column;
  gap: 10rpx;
  padding-left: 28rpx;
}

.upcoming-info-row {
  display: flex;
  align-items: center;
  gap: 10rpx;
}

.upcoming-info-icon {
  font-size: 22rpx;
  flex-shrink: 0;
}

.upcoming-info-text {
  font-size: 24rpx;
  color: $textSecondary;
}

// ============================================================
// Toggle Bar
// ============================================================
.toggle-bar {
  display: flex;
  background: $cardBg;
  border-radius: 100rpx;
  padding: 4rpx;
  border: $border;
}

.toggle-item {
  flex: 1;
  padding: 16rpx 0;
  border-radius: 100rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.3s;

  &.active {
    background: $green;
    box-shadow: 0 4rpx 16rpx rgba(7, 193, 96, 0.5);
  }
}

.toggle-text {
  font-size: 28rpx;
  font-weight: 500;
  color: $textMuted;

  &.active {
    color: $textPrimary;
  }
}

// ============================================================
// Match Count Card
// ============================================================
.match-count-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 36rpx 32rpx;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.match-count-left {
  display: flex;
  flex-direction: column;
}

.match-count-label {
  font-size: 28rpx;
  color: #ccc;
  margin-bottom: 8rpx;
}

.match-count-value {
  font-size: 72rpx;
  font-weight: 700;
  color: $green;
  line-height: 1;
}

.match-count-icon {
  width: 112rpx;
  height: 112rpx;
  border-radius: 32rpx;
  background: linear-gradient(135deg, $green, $greenDark);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 24rpx rgba(7, 193, 96, 0.3);
}

.match-count-emoji {
  font-size: 56rpx;
}

// ============================================================
// Stats Grid
// ============================================================
.stats-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16rpx;
}

.stats-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 24rpx;
  display: flex;
  flex-direction: column;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.stats-icon-box {
  width: 72rpx;
  height: 72rpx;
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 16rpx;
  box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.2);
}

.orange-red { background: linear-gradient(135deg, #fb923c, #ef4444); }
.blue { background: linear-gradient(135deg, #60a5fa, #3b82f6); }
.yellow-orange { background: linear-gradient(135deg, #facc15, #f97316); }
.purple { background: linear-gradient(135deg, #a78bfa, #7c3aed); }
.pink-red { background: linear-gradient(135deg, #f472b6, #ef4444); }
.green-teal { background: linear-gradient(135deg, #4ade80, #14b8a6); }

.stats-icon {
  font-size: 36rpx;
}

.stats-label {
  font-size: 24rpx;
  color: $textSecondary;
  margin-bottom: 8rpx;
}

.stats-value {
  font-size: 44rpx;
  font-weight: 700;
  color: $textPrimary;
  line-height: 1.1;
}

.stats-unit {
  font-size: 22rpx;
  color: $textMuted;
  margin-top: 4rpx;
}

// ============================================================
// Chart Card
// ============================================================
.chart-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 28rpx 32rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.chart-header {
  display: flex;
  align-items: center;
  margin-bottom: 24rpx;
}

.chart-header-icon {
  font-size: 32rpx;
  margin-right: 12rpx;
}

.chart-header-title {
  font-size: 30rpx;
  font-weight: 500;
  color: $textPrimary;
}

.chart-card-title {
  font-size: 30rpx;
  font-weight: 500;
  color: $textPrimary;
  display: block;
  margin-bottom: 24rpx;
}

// ============================================================
// Radar Canvas
// ============================================================
.radar-canvas-wrap {
  display: flex;
  justify-content: center;
  align-items: center;
}

.radar-image {
  width: 560rpx;
  height: 560rpx;
}

.offscreen-canvas {
  position: fixed;
  left: -9999rpx;
  top: -9999rpx;
  width: 280px;
  height: 280px;
}

// ============================================================
// Heat Map
// ============================================================
.heatmap-box {
  aspect-ratio: 4/3;
  border-radius: 20rpx;
  position: relative;
  overflow: hidden;
  border: $border;
  background: #0a2a0f;
}

.heatmap-image {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.field-outline {
  position: absolute;
  top: 24rpx;
  left: 24rpx;
  right: 24rpx;
  bottom: 24rpx;
  border: 2rpx solid rgba(255, 255, 255, 0.15);
}

.field-center-line {
  position: absolute;
  top: 50%;
  left: 0;
  right: 0;
  height: 1rpx;
  background: rgba(255, 255, 255, 0.15);
}

.field-center-circle {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 100rpx;
  height: 100rpx;
  border: 2rpx solid rgba(255, 255, 255, 0.15);
  border-radius: 50%;
  transform: translate(-50%, -50%);
}

.offscreen-canvas--heatmap {
  width: 350px;
  height: 263px;
}

.heatmap-legend {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 16rpx;
  padding: 0 8rpx;
}

.legend-text {
  font-size: 22rpx;
  color: $textMuted;
}

.legend-bar {
  flex: 1;
  height: 12rpx;
  margin: 0 24rpx;
  background: linear-gradient(90deg, #16a34a, #eab308, #ef4444);
  border-radius: 6rpx;
}

// ============================================================
// Share Button
// ============================================================
.share-btn {
  background: linear-gradient(135deg, $green, $greenDark);
  border-radius: 32rpx;
  padding: 28rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 32rpx rgba(7, 193, 96, 0.3);
}

.share-btn-text {
  font-size: 30rpx;
  font-weight: 500;
  color: $textPrimary;
}
</style>
