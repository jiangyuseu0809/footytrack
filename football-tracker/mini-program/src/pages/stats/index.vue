<template>
  <view class="page">
    <!-- Header -->
    <view class="header">
      <text class="header-title">比赛历史</text>
    </view>

    <scroll-view v-if="loaded" scroll-y class="scroll-area">
      <!-- Summary Stats -->
      <view class="section">
        <view class="summary-card">
          <text class="summary-title">累计数据</text>
          <view class="summary-grid">
            <view class="summary-item">
              <text class="summary-value">{{ overviewStats.totalSessions }}</text>
              <text class="summary-label">场比赛</text>
            </view>
            <view class="summary-item">
              <text class="summary-value">{{ overviewStats.totalDistance }}</text>
              <text class="summary-label">公里</text>
            </view>
            <view class="summary-item">
              <text class="summary-value">{{ overviewStats.totalCalories }}</text>
              <text class="summary-label">千卡</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Match List -->
      <view v-if="daySections.length > 0" class="section section--last">
        <view
          v-for="day in daySections"
          :key="day.date"
          class="swipe-wrapper"
        >
          <view
            class="swipe-content"
            :style="{ transform: `translateX(${getSwipeOffset(day.date)}px)` }"
            @touchstart="onTouchStart($event, day.date)"
            @touchmove="onTouchMove($event, day.date)"
            @touchend="onTouchEnd(day.date)"
            @tap="onCardTap(day)"
          >
            <view class="match-card" :class="{ 'match-card--swiped': getSwipeOffset(day.date) < 0 }">
              <view class="match-top">
                <view class="match-info">
                  <text class="match-name">{{ day.dateStr }} {{ day.weekday }}</text>
                  <view class="match-meta">
                    <text class="match-meta-icon">📅</text>
                    <text class="match-meta-text">{{ day.dateStr }}</text>
                    <text class="match-meta-icon" style="margin-left: 16rpx;">📍</text>
                    <text class="match-meta-text">{{ day.sessions.length }}场训练</text>
                  </view>
                </view>
                <text class="match-chevron">›</text>
              </view>
              <view class="match-divider" />
              <view class="match-stats">
                <view class="match-stat-item">
                  <text class="match-stat-label">时长</text>
                  <text class="match-stat-value">{{ day.totalDuration }}分钟</text>
                </view>
                <view class="match-stat-item">
                  <text class="match-stat-label">距离</text>
                  <text class="match-stat-value">{{ formatDistance(day.totalDistance) }}</text>
                </view>
                <view class="match-stat-item">
                  <text class="match-stat-label">热量</text>
                  <text class="match-stat-value">{{ Math.round(day.totalCalories) }}kcal</text>
                </view>
              </view>
            </view>
          </view>
          <view class="swipe-delete-btn" @tap="confirmDeleteDay(day)">
            <text class="swipe-delete-text">删除</text>
          </view>
        </view>
      </view>

      <!-- Empty State -->
      <view v-if="loaded && sessions.length === 0" class="empty-state">
        <view class="empty-icon-box">
          <text class="empty-icon">📅</text>
        </view>
        <text class="empty-title">还没有比赛记录</text>
        <text class="empty-sub">开始你的第一场比赛吧</text>
      </view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed, reactive } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { getSessions, deleteSession, isLoggedIn, type SessionDto } from '../../utils/api'
import { formatDistance, formatDate, formatWeekday, computePerformanceScore } from '../../utils/format'

const sessions = ref<SessionDto[]>([])
const loaded = ref(false)

interface DaySection {
  date: string
  dateStr: string
  weekday: string
  sessions: SessionDto[]
  totalDistance: number
  totalCalories: number
  totalDuration: number
  maxSpeed: number
  avgScore: number
}

const overviewStats = computed(() => ({
  totalSessions: sessions.value.length,
  totalDistance: (sessions.value.reduce((s, v) => s + (v.totalDistanceMeters || 0), 0) / 1000).toFixed(1),
  totalCalories: Math.round(sessions.value.reduce((s, v) => s + (v.caloriesBurned || 0), 0)),
}))

const daySections = computed<DaySection[]>(() => {
  const grouped = new Map<string, SessionDto[]>()
  for (const s of sessions.value) {
    const d = new Date(s.startTime)
    const key = `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`
    if (!grouped.has(key)) grouped.set(key, [])
    grouped.get(key)!.push(s)
  }

  const result: DaySection[] = []
  for (const [key, sess] of grouped) {
    const sorted = sess.sort((a, b) => b.startTime - a.startTime)
    const ts = sorted[0].startTime
    result.push({
      date: key,
      dateStr: formatDate(ts),
      weekday: formatWeekday(ts),
      sessions: sorted,
      totalDistance: sorted.reduce((sum, s) => sum + (s.totalDistanceMeters || 0), 0),
      totalCalories: sorted.reduce((sum, s) => sum + (s.caloriesBurned || 0), 0),
      totalDuration: Math.round(sorted.reduce((sum, s) => sum + ((s.endTime - s.startTime) / 60000), 0)),
      maxSpeed: Math.max(...sorted.map(s => s.maxSpeedKmh || 0)),
      avgScore: sorted.reduce((sum, s) => sum + computePerformanceScore(s), 0) / sorted.length,
    })
  }

  return result.sort((a, b) => b.sessions[0].startTime - a.sessions[0].startTime)
})

// --- Swipe to delete ---
const DELETE_BTN_W = 80
const swipeState = reactive<Record<string, { startX: number; startY: number; offset: number; swiping: boolean; direction: '' | 'h' | 'v' }>>({})

function getSwipeOffset(key: string): number {
  return swipeState[key]?.offset || 0
}

function onTouchStart(e: TouchEvent, key: string) {
  // Close any other open swipe
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

  // Lock direction on first significant movement
  if (swipeState[key].direction === '' && (Math.abs(dx) > 8 || Math.abs(dy) > 8)) {
    swipeState[key].direction = Math.abs(dx) > Math.abs(dy) ? 'h' : 'v'
  }

  // Vertical scroll — do nothing, let scroll-view handle it
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

function onCardTap(day: DaySection) {
  // If swiping, don't navigate
  if (swipeState[day.date]?.swiping) return
  // If open, close instead of navigate
  if (swipeState[day.date]?.offset < 0) {
    swipeState[day.date].offset = 0
    return
  }
  goDetail(day)
}

async function loadData() {
  if (!isLoggedIn()) return
  try {
    const res = await getSessions()
    sessions.value = res.sessions
  } catch (e) {
    console.error('Failed to load sessions', e)
  } finally {
    loaded.value = true
  }
}

function goDetail(day: DaySection) {
  if (day.sessions.length === 1) {
    uni.navigateTo({ url: `/pages/session-detail/index?id=${day.sessions[0].id}` })
  } else {
    const ids = day.sessions.map(s => s.id).join(',')
    uni.navigateTo({ url: `/pages/day-detail/index?ids=${ids}&date=${day.dateStr}` })
  }
}

function confirmDeleteDay(day: DaySection) {
  uni.showModal({
    title: '删除确认',
    content: `确定删除 ${day.dateStr} 的全部 ${day.sessions.length} 场训练吗？`,
    confirmColor: '#ef4444',
    success: async (res) => {
      if (!res.confirm) return
      try {
        uni.showLoading({ title: '删除中...' })
        await Promise.all(day.sessions.map(s => deleteSession(s.id)))
        sessions.value = sessions.value.filter(s => !day.sessions.some(ds => ds.id === s.id))
        delete swipeState[day.date]
        uni.hideLoading()
        uni.showToast({ title: '已删除', icon: 'success' })
      } catch (e) {
        uni.hideLoading()
        uni.showToast({ title: '删除失败', icon: 'none' })
      }
    },
  })
}

onShow(() => { loadData() })
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
}

.header-title {
  font-size: 34rpx;
  font-weight: 700;
  color: $textPrimary;
  display: block;
  text-align: center;
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

.summary-item {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.summary-value {
  font-size: 48rpx;
  font-weight: 700;
  color: $textPrimary;
  line-height: 1;
}

.summary-label {
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.8);
  margin-top: 8rpx;
}

// ============================================================
// Swipe Wrapper
// ============================================================
.swipe-wrapper {
  position: relative;
  margin-bottom: 16rpx;
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
// Match Cards
// ============================================================
.match-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 24rpx 28rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
  transition: border-radius 0.2s ease;
}

.match-card--swiped {
  border-radius: 32rpx 0 0 32rpx;
}

.match-top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 16rpx;
}

.match-info {
  flex: 1;
}

.match-name {
  font-size: 30rpx;
  font-weight: 500;
  color: $textPrimary;
  display: block;
  margin-bottom: 8rpx;
}

.match-meta {
  display: flex;
  align-items: center;
}

.match-meta-icon {
  font-size: 22rpx;
  margin-right: 4rpx;
}

.match-meta-text {
  font-size: 22rpx;
  color: $textMuted;
}

.match-chevron {
  font-size: 40rpx;
  color: $textMuted;
  font-weight: 300;
}

.match-divider {
  height: 1rpx;
  background: #2a2a2a;
  margin-bottom: 16rpx;
}

.match-stats {
  display: flex;
  align-items: center;
  gap: 24rpx;
}

.match-stat-item {
  flex: 1;
}

.match-stat-label {
  font-size: 22rpx;
  color: $textMuted;
  display: block;
}

.match-stat-value {
  font-size: 26rpx;
  font-weight: 500;
  color: $textPrimary;
}

// ============================================================
// Empty State
// ============================================================
.empty-state {
  text-align: center;
  padding: 120rpx 48rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.empty-icon-box {
  width: 120rpx;
  height: 120rpx;
  border-radius: 50%;
  background: $cardBg;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 24rpx;
  border: $border;
}

.empty-icon {
  font-size: 56rpx;
}

.empty-title {
  font-size: 28rpx;
  color: $textMuted;
  display: block;
}

.empty-sub {
  font-size: 24rpx;
  color: $textMuted;
  display: block;
  margin-top: 8rpx;
}
</style>
