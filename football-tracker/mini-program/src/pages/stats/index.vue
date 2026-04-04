<template>
  <view class="page">
    <!-- Header -->
    <view class="header">
      <text class="header-title">比赛历史</text>
    </view>

    <scroll-view scroll-y class="scroll-area">
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
          class="match-card"
          @tap="goDetail(day)"
        >
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

      <!-- Empty State -->
      <view v-if="sessions.length === 0" class="empty-state">
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
import { ref, computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { getSessions, isLoggedIn, type SessionDto } from '../../utils/api'
import { formatDistance, formatDate, formatWeekday, computePerformanceScore } from '../../utils/format'

const sessions = ref<SessionDto[]>([])

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

async function loadData() {
  if (!isLoggedIn()) return
  try {
    const res = await getSessions()
    sessions.value = res.sessions
  } catch (e) {
    console.error('Failed to load sessions', e)
  }
}

function goDetail(day: DaySection) {
  if (day.sessions.length === 1) {
    uni.navigateTo({ url: `/pages/session-detail/index?id=${day.sessions[0].id}` })
  }
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
// Match Cards
// ============================================================
.match-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 24rpx 28rpx;
  margin-bottom: 16rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
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
