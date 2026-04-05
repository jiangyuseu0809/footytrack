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
      <!-- Day Summary Card -->
      <view class="section">
        <view class="summary-card">
          <text class="summary-title">全天汇总</text>
          <view class="summary-grid">
            <view class="summary-item">
              <text class="summary-value">{{ daySummary.duration }}</text>
              <text class="summary-label">分钟</text>
            </view>
            <view class="summary-item">
              <text class="summary-value">{{ daySummary.distance }}</text>
              <text class="summary-label">公里</text>
            </view>
            <view class="summary-item">
              <text class="summary-value">{{ daySummary.calories }}</text>
              <text class="summary-label">千卡</text>
            </view>
          </view>
          <view class="summary-grid summary-grid--second">
            <view class="summary-item">
              <text class="summary-value">{{ daySummary.sprints }}</text>
              <text class="summary-label">冲刺</text>
            </view>
            <view class="summary-item">
              <text class="summary-value">{{ daySummary.maxHR }}</text>
              <text class="summary-label">最高心率</text>
            </view>
            <view class="summary-item">
              <text class="summary-value">{{ daySummary.avgHR }}</text>
              <text class="summary-label">平均心率</text>
            </view>
          </view>
          <view class="summary-grid summary-grid--second">
            <view class="summary-item">
              <text class="summary-value">{{ daySummary.maxSpeed }}</text>
              <text class="summary-label">最高时速</text>
            </view>
            <view class="summary-item">
              <text class="summary-value">{{ daySummary.avgSpeed }}</text>
              <text class="summary-label">平均时速</text>
            </view>
            <view class="summary-item">
              <text class="summary-value">{{ daySummary.sessions }}</text>
              <text class="summary-label">比赛场次</text>
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
import { getSessions, deleteSession, isLoggedIn, type SessionDto } from '../../utils/api'
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

function formatTimeRange(s: SessionDto): string {
  const start = new Date(s.startTime)
  const end = new Date(s.endTime)
  const fmt = (d: Date) => `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
  return `${fmt(start)} - ${fmt(end)}`
}

// --- Swipe to delete ---
const DELETE_BTN_W = 80
const swipeState = reactive<Record<string, { startX: number; offset: number; swiping: boolean }>>({})

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
    swipeState[key] = { startX: 0, offset: 0, swiping: false }
  }
  swipeState[key].startX = e.touches[0].clientX
  swipeState[key].swiping = false
}

function onTouchMove(e: TouchEvent, key: string) {
  if (!swipeState[key]) return
  const dx = e.touches[0].clientX - swipeState[key].startX
  if (Math.abs(dx) > 10) swipeState[key].swiping = true
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
  if (!isLoggedIn()) return
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
// Summary Card
// ============================================================
.summary-card {
  background: linear-gradient(135deg, $green, $greenDark);
  border-radius: 32rpx;
  padding: 36rpx 32rpx;
  box-shadow: 0 8rpx 32rpx rgba(7, 193, 96, 0.2);
}

.summary-title {
  font-size: 30rpx;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.9);
  display: block;
  margin-bottom: 24rpx;
}

.summary-grid {
  display: flex;
  justify-content: space-between;
}

.summary-grid--second {
  margin-top: 24rpx;
  padding-top: 24rpx;
  border-top: 1rpx solid rgba(255, 255, 255, 0.15);
}

.summary-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  flex: 1;
}

.summary-value {
  font-size: 44rpx;
  font-weight: 700;
  color: $textPrimary;
  line-height: 1;
}

.summary-label {
  font-size: 24rpx;
  color: rgba(255, 255, 255, 0.8);
  margin-top: 8rpx;
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
