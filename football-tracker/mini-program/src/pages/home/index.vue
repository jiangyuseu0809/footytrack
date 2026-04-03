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
            <view class="heat-point heat-1" />
            <view class="heat-point heat-2" />
            <view class="heat-point heat-3" />
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
  </view>
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { getSessions, isLoggedIn, type SessionDto } from '../../utils/api'

const timeRange = ref<'week' | 'today'>('week')
const sessions = ref<SessionDto[]>([])
const isWatchConnected = ref(false)
const radarImage = ref('')

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
    const res = await getSessions()
    sessions.value = res.sessions
  } catch (e) {
    console.error('Failed to load home data', e)
  }
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

watch([timeRange, abilityData], () => {
  nextTick(() => {
    setTimeout(() => drawRadar(), 100)
  })
})

onShow(() => {
  loadData()
  nextTick(() => {
    setTimeout(() => drawRadar(), 300)
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
  background: linear-gradient(135deg, #0a2a0f, #2a2a0a, #2a0a0a);
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

.heat-point {
  position: absolute;
  border-radius: 50%;
  filter: blur(20rpx);
}

.heat-1 {
  top: 30%;
  left: 22%;
  width: 120rpx;
  height: 120rpx;
  background: rgba(239, 68, 68, 0.5);
}

.heat-2 {
  top: 45%;
  left: 45%;
  width: 160rpx;
  height: 160rpx;
  background: rgba(249, 115, 22, 0.5);
}

.heat-3 {
  top: 60%;
  right: 22%;
  width: 120rpx;
  height: 120rpx;
  background: rgba(234, 179, 8, 0.5);
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
