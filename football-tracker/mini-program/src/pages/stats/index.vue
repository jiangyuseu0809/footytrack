<template>
  <view class="page">
    <view class="nav-bar">
      <text class="nav-title">统计</text>
    </view>

    <view v-if="daySections.length === 0" class="empty-state">
      <text class="empty-text">暂无训练记录</text>
    </view>

    <view v-for="day in daySections" :key="day.date" class="day-card" @tap="goDetail(day)">
      <view class="day-header">
        <view>
          <text class="day-date">{{ day.dateStr }}</text>
          <text class="day-weekday">{{ day.weekday }}</text>
        </view>
        <view class="day-badge">
          <text class="badge-text">{{ day.sessions.length }}场</text>
        </view>
      </view>
      <view class="day-stats">
        <view class="day-stat">
          <text class="stat-value distance">{{ formatDistance(day.totalDistance) }}</text>
          <text class="stat-label">距离</text>
        </view>
        <view class="day-stat">
          <text class="stat-value calories">{{ Math.round(day.totalCalories) }}</text>
          <text class="stat-label">卡路里</text>
        </view>
        <view class="day-stat">
          <text class="stat-value speed">{{ day.maxSpeed.toFixed(1) }}</text>
          <text class="stat-label">最高速度</text>
        </view>
        <view class="day-stat">
          <text class="stat-value score">{{ day.avgScore.toFixed(1) }}</text>
          <text class="stat-label">评分</text>
        </view>
      </view>
    </view>
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
  maxSpeed: number
  avgScore: number
}

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
      maxSpeed: Math.max(...sorted.map(s => s.maxSpeedKmh || 0)),
      avgScore: sorted.reduce((sum, s) => sum + computePerformanceScore(s), 0) / sorted.length,
    })
  }

  return result.sort((a, b) => b.sessions[0].startTime - a.sessions[0].startTime)
})

async function loadData() {
  if (!isLoggedIn()) { uni.reLaunch({ url: '/pages/login/index' }); return }
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
  // TODO: day summary view for multiple sessions
}

onShow(() => { loadData() })
</script>

<style lang="scss" scoped>
.page {
  min-height: 100vh;
  background: #0D1117;
  padding-bottom: 120rpx;
}
.nav-bar {
  padding: 100rpx 28rpx 28rpx;
  .nav-title { font-size: 42rpx; font-weight: 700; color: #fff; }
}
.empty-state {
  text-align: center;
  padding: 120rpx 0;
  .empty-text { font-size: 28rpx; color: #8B949E; }
}
.day-card {
  margin: 0 28rpx 20rpx;
  background: #1C2333;
  border-radius: 28rpx;
  padding: 24rpx 28rpx;
  border: 1rpx solid rgba(255,255,255,0.08);
  .day-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16rpx;
    .day-date { font-size: 30rpx; font-weight: 600; color: #fff; }
    .day-weekday { font-size: 24rpx; color: #8B949E; margin-left: 12rpx; }
    .day-badge {
      background: #3B82F6;
      padding: 4rpx 16rpx;
      border-radius: 20rpx;
      .badge-text { font-size: 22rpx; color: #fff; }
    }
  }
  .day-stats {
    display: flex;
    justify-content: space-between;
    .day-stat {
      text-align: center;
      .stat-value { font-size: 30rpx; font-weight: 700; display: block; }
      .stat-label { font-size: 20rpx; color: #8B949E; display: block; margin-top: 4rpx; }
      .distance { color: #00E676; }
      .calories { color: #FFA502; }
      .speed { color: #3B82F6; }
      .score { color: #00BFA5; }
    }
  }
}
</style>
