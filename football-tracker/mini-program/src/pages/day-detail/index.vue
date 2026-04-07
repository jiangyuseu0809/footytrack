<template>
  <view class="page">
    <!-- Header -->
    <view class="header">
      <view class="header-back" @tap="goBack">
        <text class="header-back-icon">‹</text>
      </view>
      <text class="header-title">{{ dateStr }} 训练总结</text>
    </view>

    <scroll-view scroll-y class="scroll-area">
      <!-- Core Stats Panel -->
      <view class="section">
        <view class="core-panel">
          <text class="core-panel-title">核心数据</text>
          <view class="core-grid">
            <view class="core-item" :class="'core-item--' + getDayLevel('sessions', daySummary.sessions)">
              <text class="core-item-value">{{ daySummary.sessions }}</text>
              <text class="core-item-label">比赛场次</text>
            </view>
            <view class="core-item" :class="'core-item--' + getDayLevel('calories', daySummary.calories)">
              <text class="core-item-value">{{ daySummary.calories }}</text>
              <text class="core-item-label">热量(kcal)</text>
            </view>
            <view class="core-item" :class="'core-item--' + getDayLevel('distance', daySummary.distance)">
              <text class="core-item-value">{{ daySummary.distance }}</text>
              <text class="core-item-label">距离(km)</text>
            </view>
            <view class="core-item" :class="'core-item--' + getDayLevel('sprints', daySummary.sprints)">
              <text class="core-item-value">{{ daySummary.sprints }}</text>
              <text class="core-item-label">冲刺次数</text>
            </view>
            <view class="core-item" :class="'core-item--' + getDayLevel('duration', daySummary.duration)">
              <text class="core-item-value">{{ daySummary.duration }}</text>
              <text class="core-item-label">时长(分钟)</text>
            </view>
            <view class="core-item" :class="'core-item--' + getDayLevel('maxHR', daySummary.maxHR)">
              <text class="core-item-value">{{ daySummary.maxHR }}</text>
              <text class="core-item-label">最高心率</text>
            </view>
            <view class="core-item" :class="'core-item--' + getDayLevel('avgHR', daySummary.avgHR)">
              <text class="core-item-value">{{ daySummary.avgHR }}</text>
              <text class="core-item-label">平均心率</text>
            </view>
            <view class="core-item" :class="'core-item--' + getDayLevel('maxSpeed', daySummary.maxSpeed)">
              <text class="core-item-value">{{ daySummary.maxSpeed }}</text>
              <text class="core-item-label">最高时速</text>
            </view>
            <view class="core-item" :class="'core-item--' + getDayLevel('avgSpeed', daySummary.avgSpeed)">
              <text class="core-item-value">{{ daySummary.avgSpeed }}</text>
              <text class="core-item-label">平均时速</text>
            </view>
          </view>
          <view class="core-legend">
            <view class="core-legend-item">
              <view class="core-legend-dot core-legend-dot--good" />
              <text class="core-legend-text">出色</text>
            </view>
            <view class="core-legend-item">
              <view class="core-legend-dot core-legend-dot--normal" />
              <text class="core-legend-text">一般</text>
            </view>
            <view class="core-legend-item">
              <view class="core-legend-dot core-legend-dot--low" />
              <text class="core-legend-text">待提升</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Day Ability Radar -->
      <view class="section">
        <view class="card">
          <text class="card-title">能力雷达</text>
          <view class="radar-wrap">
            <image v-if="dayRadarImage" :src="dayRadarImage" class="radar-img" mode="aspectFit" />
            <view v-else class="radar-placeholder">
              <text class="radar-placeholder-text">加载中...</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Per-Session Cards -->
      <view class="section section--last">
        <view
          v-for="(session, idx) in matchedSessions"
          :key="session.id"
          class="swipe-wrapper"
        >
          <view
            class="swipe-content"
            :style="{ transform: `translateX(${getSwipeOffset(session.id)}px)` }"
            @touchstart="onTouchStart($event, session.id)"
            @touchmove="onTouchMove($event, session.id)"
            @touchend="onTouchEnd(session.id)"
            @tap="onCardTap(session)"
          >
            <view class="session-card" :class="{ 'session-card--swiped': getSwipeOffset(session.id) < 0 }">
              <view class="session-header">
                <text class="session-title">训练 {{ idx + 1 }}</text>
                <text class="session-time">{{ formatTimeRange(session) }}</text>
                <text class="session-chevron">›</text>
              </view>

              <view class="session-divider" />

              <!-- 6-stat grid -->
              <view class="session-stats">
                <view class="session-stat-item">
                  <text class="session-stat-label">时长</text>
                  <text class="session-stat-value">{{ sessionDuration(session) }}分钟</text>
                </view>
                <view class="session-stat-item">
                  <text class="session-stat-label">距离</text>
                  <text class="session-stat-value">{{ formatDistance(session.totalDistanceMeters) }}</text>
                </view>
                <view class="session-stat-item">
                  <text class="session-stat-label">热量</text>
                  <text class="session-stat-value">{{ Math.round(session.caloriesBurned || 0) }}kcal</text>
                </view>
              </view>
              <view class="session-stats">
                <view class="session-stat-item">
                  <text class="session-stat-label">冲刺</text>
                  <text class="session-stat-value">{{ session.sprintCount || 0 }}次</text>
                </view>
                <view class="session-stat-item">
                  <text class="session-stat-label">最高心率</text>
                  <text class="session-stat-value">{{ session.maxHeartRate || '--' }}</text>
                </view>
                <view class="session-stat-item">
                  <text class="session-stat-label">平均心率</text>
                  <text class="session-stat-value">{{ session.avgHeartRate || '--' }}</text>
                </view>
              </view>

              <!-- Score -->
              <view class="session-score-row">
                <text class="session-score-label">表现评分</text>
                <text class="session-score-value">{{ computePerformanceScore(session).toFixed(1) }}</text>
              </view>
            </view>
          </view>
          <view class="swipe-delete-btn" @tap="confirmDeleteSession(session)">
            <text class="swipe-delete-text">删除</text>
          </view>
        </view>
      </view>
    </scroll-view>

    <!-- Offscreen canvases -->
    <canvas canvas-id="dayRadarCanvas" id="dayRadarCanvas" class="offscreen-canvas" />
  </view>
</template>

<script setup lang="ts">
import { ref, computed, reactive, nextTick } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { getSessions, deleteSession, ensureLogin, type SessionDto } from '../../utils/api'
import { formatDistance, computePerformanceScore } from '../../utils/format'
import { computeAbilityData, drawRadarChart } from '../../utils/charts'

const dateStr = ref('')
const targetIds = ref<string[]>([])
const allSessions = ref<SessionDto[]>([])
const dayRadarImage = ref('')

const matchedSessions = computed(() => {
  const idSet = new Set(targetIds.value)
  return allSessions.value
    .filter(s => idSet.has(s.id))
    .sort((a, b) => a.startTime - b.startTime)
})

const daySummary = computed(() => {
  const list = matchedSessions.value
  const totalDist = list.reduce((sum, s) => sum + (s.totalDistanceMeters || 0), 0)
  const totalCal = list.reduce((sum, s) => sum + (s.caloriesBurned || 0), 0)
  const totalDur = Math.round(list.reduce((sum, s) => sum + ((s.endTime - s.startTime) / 60000), 0))
  const totalSprints = list.reduce((sum, s) => sum + (s.sprintCount || 0), 0)
  const maxHR = list.length ? Math.max(...list.map(s => s.maxHeartRate || 0)) : 0
  const avgHR = list.length ? Math.round(list.reduce((sum, s) => sum + (s.avgHeartRate || 0), 0) / list.length) : 0
  const maxSpeed = list.length ? Math.max(...list.map(s => s.maxSpeedKmh || 0)) : 0
  const avgSpeed = list.length ? list.reduce((sum, s) => sum + (s.avgSpeedKmh || 0), 0) / list.length : 0
  return {
    sessions: list.length,
    duration: totalDur,
    distance: (totalDist / 1000).toFixed(1),
    calories: Math.round(totalCal),
    sprints: totalSprints,
    maxHR: maxHR || '--',
    avgHR: avgHR || '--',
    maxSpeed: maxSpeed ? maxSpeed.toFixed(1) : '--',
    avgSpeed: avgSpeed ? avgSpeed.toFixed(1) : '--',
  }
})

function sessionDuration(s: SessionDto): number {
  return Math.round((s.endTime - s.startTime) / 60000)
}

function getDayLevel(metric: string, value: number | string): string {
  const v = typeof value === 'string' ? parseFloat(value) : value
  if (!v) return 'low'
  const thresholds: Record<string, [number, number]> = {
    sessions:  [2, 1],
    calories:  [300, 100],
    distance:  [3, 1],
    sprints:   [8, 3],
    duration:  [45, 15],
    maxHR:     [170, 140],
    avgHR:     [140, 110],
    maxSpeed:  [20, 12],
    avgSpeed:  [8, 4],
  }
  const [good, normal] = thresholds[metric] || [1, 0]
  if (v >= good) return 'good'
  if (v >= normal) return 'normal'
  return 'low'
}

function formatTimeRange(s: SessionDto): string {
  const start = new Date(s.startTime)
  const end = new Date(s.endTime)
  const fmt = (d: Date) => `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
  return `${fmt(start)} - ${fmt(end)}`
}

// --- Swipe to delete ---
const DELETE_BTN_W = 80
const swipeState = reactive<Record<string, { startX: number; startY: number; offset: number; swiping: boolean; direction: '' | 'h' | 'v' }>>({})

function getSwipeOffset(key: string): number {
  return swipeState[key]?.offset || 0
}

function onTouchStart(e: TouchEvent, key: string) {
  for (const k of Object.keys(swipeState)) {
    if (k !== key && swipeState[k].offset < 0) {
      swipeState[k].offset = 0
    }
  }
  if (!swipeState[key]) {
    swipeState[key] = { startX: 0, startY: 0, offset: 0, swiping: false, direction: '' }
  }
  swipeState[key].startX = e.touches[0].clientX
  swipeState[key].startY = e.touches[0].clientY
  swipeState[key].swiping = false
  swipeState[key].direction = ''
}

function onTouchMove(e: TouchEvent, key: string) {
  if (!swipeState[key]) return
  const dx = e.touches[0].clientX - swipeState[key].startX
  const dy = e.touches[0].clientY - swipeState[key].startY

  if (swipeState[key].direction === '' && (Math.abs(dx) > 8 || Math.abs(dy) > 8)) {
    swipeState[key].direction = Math.abs(dx) > Math.abs(dy) ? 'h' : 'v'
  }

  if (swipeState[key].direction !== 'h') return

  swipeState[key].swiping = true
  const prev = swipeState[key].offset
  let next = dx
  if (prev === -DELETE_BTN_W) {
    next = -DELETE_BTN_W + dx
  }
  swipeState[key].offset = Math.max(-DELETE_BTN_W, Math.min(0, next))
}

function onTouchEnd(key: string) {
  if (!swipeState[key]) return
  if (swipeState[key].offset < -DELETE_BTN_W / 2) {
    swipeState[key].offset = -DELETE_BTN_W
  } else {
    swipeState[key].offset = 0
  }
}

function onCardTap(session: SessionDto) {
  if (swipeState[session.id]?.swiping) return
  if (swipeState[session.id]?.offset < 0) {
    swipeState[session.id].offset = 0
    return
  }
  goSessionDetail(session.id)
}

function confirmDeleteSession(session: SessionDto) {
  uni.showModal({
    title: '删除确认',
    content: '确定删除这场训练吗？',
    confirmColor: '#ef4444',
    success: async (res) => {
      if (!res.confirm) return
      try {
        uni.showLoading({ title: '删除中...' })
        await deleteSession(session.id)
        targetIds.value = targetIds.value.filter(id => id !== session.id)
        allSessions.value = allSessions.value.filter(s => s.id !== session.id)
        delete swipeState[session.id]
        uni.hideLoading()
        uni.showToast({ title: '已删除', icon: 'success' })
        // If no sessions left, go back
        if (matchedSessions.value.length === 0) {
          setTimeout(() => uni.navigateBack(), 500)
        } else {
          drawCharts()
        }
      } catch (e) {
        uni.hideLoading()
        uni.showToast({ title: '删除失败', icon: 'none' })
      }
    },
  })
}

function goBack() {
  uni.navigateBack()
}

function goSessionDetail(id: string) {
  uni.navigateTo({ url: `/pages/session-detail/index?id=${id}` })
}

async function loadData() {
  await ensureLogin()
  try {
    const res = await getSessions()
    allSessions.value = res.sessions
    drawCharts()
  } catch (e) {
    console.error('Failed to load sessions', e)
  }
}

function drawCharts() {
  nextTick(() => {
    const sessions = matchedSessions.value
    if (sessions.length === 0) return

    // Day-level radar
    const dayAbility = computeAbilityData(sessions)
    setTimeout(() => {
      drawRadarChart('dayRadarCanvas', dayAbility, (path) => { dayRadarImage.value = path })
    }, 200)
  })
}

onLoad((query) => {
  dateStr.value = (query as any)?.date || ''
  const idsStr = (query as any)?.ids || ''
  targetIds.value = idsStr ? idsStr.split(',') : []
  loadData()
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
}

.scroll-area {
  height: calc(100vh - 200rpx);
}

// ============================================================
// Header
// ============================================================
.header {
  background: $cardBg;
  padding: 120rpx 32rpx 28rpx;
  border-bottom: $border;
  display: flex;
  align-items: center;
  position: relative;
}

.header-back {
  position: absolute;
  left: 20rpx;
  bottom: 20rpx;
  width: 64rpx;
  height: 64rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.header-back-icon {
  font-size: 48rpx;
  color: $textPrimary;
  font-weight: 300;
}

.header-title {
  font-size: 34rpx;
  font-weight: 700;
  color: $textPrimary;
  display: block;
  text-align: center;
  flex: 1;
}

// ============================================================
// Sections
// ============================================================
.section {
  padding: 24rpx 32rpx 0;
}

.section--last {
  padding-bottom: 160rpx;
}

// ============================================================
// Core Stats Panel
// ============================================================
.core-panel {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 28rpx 24rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.core-panel-title {
  font-size: 30rpx;
  font-weight: 600;
  color: $textPrimary;
  display: block;
  margin-bottom: 24rpx;
  padding-left: 4rpx;
}

.core-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 16rpx;
}

.core-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 16rpx 8rpx;
  border-radius: 16rpx;
  background: rgba(255, 255, 255, 0.04);
}

.core-item--good {
  background: rgba(7, 193, 96, 0.15);
}

.core-item--normal {
  background: rgba(250, 204, 21, 0.12);
}

.core-item--low {
  background: rgba(239, 68, 68, 0.12);
}

.core-item-value {
  font-size: 38rpx;
  font-weight: 700;
  color: $textPrimary;
  line-height: 1.1;
}

.core-item-label {
  font-size: 22rpx;
  color: $textMuted;
  margin-top: 6rpx;
}

.core-legend {
  display: flex;
  justify-content: center;
  gap: 32rpx;
  margin-top: 20rpx;
  padding-top: 16rpx;
  border-top: 1rpx solid #2a2a2a;
}

.core-legend-item {
  display: flex;
  align-items: center;
  gap: 8rpx;
}

.core-legend-dot {
  width: 16rpx;
  height: 16rpx;
  border-radius: 4rpx;
}

.core-legend-dot--good {
  background: rgba(7, 193, 96, 0.5);
}

.core-legend-dot--normal {
  background: rgba(250, 204, 21, 0.4);
}

.core-legend-dot--low {
  background: rgba(239, 68, 68, 0.4);
}

.core-legend-text {
  font-size: 22rpx;
  color: $textMuted;
}

// ============================================================
// Card
// ============================================================
.card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 28rpx;
  border: $border;
}

.card-title {
  font-size: 28rpx;
  font-weight: 600;
  color: $textPrimary;
  display: block;
  margin-bottom: 16rpx;
}

// ============================================================
// Radar
// ============================================================
.radar-wrap {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 360rpx;
}

.radar-img {
  width: 360rpx;
  height: 360rpx;
}

.radar-placeholder {
  width: 360rpx;
  height: 360rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.radar-placeholder-text {
  font-size: 24rpx;
  color: $textMuted;
}

// ============================================================
// Swipe Wrapper
// ============================================================
.swipe-wrapper {
  position: relative;
  margin-bottom: 24rpx;
}

.swipe-content {
  position: relative;
  z-index: 1;
  transition: transform 0.2s ease;
}

.swipe-delete-btn {
  position: absolute;
  right: 0;
  top: 0;
  bottom: 0;
  width: 160rpx;
  background: #ef4444;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 0 32rpx 32rpx 0;
}

.swipe-delete-text {
  font-size: 28rpx;
  font-weight: 500;
  color: #FFFFFF;
}

// ============================================================
// Session Cards
// ============================================================
.session-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 28rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
  transition: border-radius 0.2s ease;
}

.session-card--swiped {
  border-radius: 32rpx 0 0 32rpx;
}

.session-header {
  display: flex;
  align-items: center;
  margin-bottom: 16rpx;
}

.session-title {
  font-size: 30rpx;
  font-weight: 600;
  color: $textPrimary;
}

.session-time {
  font-size: 24rpx;
  color: $textSecondary;
  margin-left: 16rpx;
  flex: 1;
}

.session-chevron {
  font-size: 40rpx;
  color: $textMuted;
  font-weight: 300;
}

.session-divider {
  height: 1rpx;
  background: #2a2a2a;
  margin-bottom: 20rpx;
}

// ============================================================
// Session Stats Grid
// ============================================================
.session-stats {
  display: flex;
  gap: 16rpx;
  margin-bottom: 12rpx;
}

.session-stat-item {
  flex: 1;
}

.session-stat-label {
  font-size: 22rpx;
  color: $textMuted;
  display: block;
}

.session-stat-value {
  font-size: 26rpx;
  font-weight: 500;
  color: $textPrimary;
}

// ============================================================
// Score Row
// ============================================================
.session-score-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 20rpx;
  padding-top: 20rpx;
  border-top: 1rpx solid #2a2a2a;
}

.session-score-label {
  font-size: 26rpx;
  color: $textSecondary;
}

.session-score-value {
  font-size: 40rpx;
  font-weight: 700;
  color: $green;
}

// ============================================================
// Offscreen Canvas
// ============================================================
.offscreen-canvas {
  position: fixed;
  left: -9999px;
  top: -9999px;
  width: 280px;
  height: 280px;
}
</style>
