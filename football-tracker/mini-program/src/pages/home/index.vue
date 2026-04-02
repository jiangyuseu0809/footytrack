<template>
  <view class="page">
    <view class="nav-bar">
      <text class="nav-title">野球记</text>
    </view>

    <!-- Quick Actions -->
    <view class="section">
      <view class="action-row">
        <view class="action-card" @tap="goCreateMatch">
          <text class="action-icon">⚽</text>
          <text class="action-text">新建比赛</text>
        </view>
        <view class="action-card" @tap="goTeam">
          <text class="action-icon">👥</text>
          <text class="action-text">我的球队</text>
        </view>
      </view>
    </view>

    <!-- Upcoming Match -->
    <view v-if="nextMatch" class="section">
      <text class="section-title">即将开始</text>
      <view class="match-card" @tap="goMatchDetail(nextMatch.id)">
        <view class="match-header">
          <text class="match-title">{{ nextMatch.title }}</text>
          <text class="match-status">{{ nextMatch.status === 'upcoming' ? '报名中' : '已结束' }}</text>
        </view>
        <view class="match-info">
          <text class="match-meta">📍 {{ nextMatch.location }}</text>
          <text class="match-meta">🕐 {{ formatDateTime(nextMatch.matchDate) }}</text>
          <text class="match-meta">👤 {{ nextMatch.registrationCount }}人已报名</text>
        </view>
      </view>
    </view>

    <!-- Monthly Stats -->
    <view class="section">
      <text class="section-title">本月概览</text>
      <view class="stats-grid">
        <view class="stat-card stat-distance">
          <text class="stat-value">{{ monthlyStats.distance }}</text>
          <text class="stat-label">总距离</text>
        </view>
        <view class="stat-card stat-calories">
          <text class="stat-value">{{ monthlyStats.calories }}</text>
          <text class="stat-label">卡路里</text>
        </view>
        <view class="stat-card stat-sessions">
          <text class="stat-value">{{ monthlyStats.sessions }}</text>
          <text class="stat-label">场次</text>
        </view>
        <view class="stat-card stat-sprints">
          <text class="stat-value">{{ monthlyStats.sprints }}</text>
          <text class="stat-label">冲刺</text>
        </view>
      </view>
    </view>

    <!-- Recent Sessions -->
    <view class="section">
      <text class="section-title">最近记录</text>
      <view v-if="recentSessions.length === 0" class="empty-state">
        <text class="empty-text">暂无训练数据</text>
        <text class="empty-sub">在手表上开始追踪后数据将显示在这里</text>
      </view>
      <view v-for="session in recentSessions" :key="session.id" class="session-card" @tap="goSessionDetail(session.id)">
        <view class="session-left">
          <text class="session-date">{{ formatRelativeDate(session.startTime) }}</text>
          <text class="session-time">{{ formatDuration(session.endTime - session.startTime) }}</text>
        </view>
        <view class="session-stats">
          <text class="session-stat">🏃 {{ formatDistance(session.totalDistanceMeters) }}</text>
          <text class="session-stat">🔥 {{ Math.round(session.caloriesBurned || 0) }} kcal</text>
          <text class="session-stat">⚡ {{ (session.maxSpeedKmh || 0).toFixed(1) }} km/h</text>
        </view>
        <text class="chevron">›</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { getSessions, getMatches, isLoggedIn, type SessionDto, type Match } from '../../utils/api'
import { formatDuration, formatDistance, formatDateTime, formatRelativeDate } from '../../utils/format'

const sessions = ref<SessionDto[]>([])
const matches = ref<Match[]>([])

const recentSessions = computed(() => {
  return [...sessions.value]
    .sort((a, b) => b.startTime - a.startTime)
    .slice(0, 10)
})

const nextMatch = computed(() => {
  const now = Date.now()
  return matches.value.find(m => m.matchDate > now - 3600000 && m.status === 'upcoming') || null
})

const monthlyStats = computed(() => {
  const now = new Date()
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).getTime()
  const monthly = sessions.value.filter(s => s.startTime >= monthStart)
  return {
    distance: formatDistance(monthly.reduce((sum, s) => sum + (s.totalDistanceMeters || 0), 0)),
    calories: Math.round(monthly.reduce((sum, s) => sum + (s.caloriesBurned || 0), 0)),
    sessions: monthly.length,
    sprints: monthly.reduce((sum, s) => sum + (s.sprintCount || 0), 0),
  }
})

async function loadData() {
  if (!isLoggedIn()) {
    uni.reLaunch({ url: '/pages/login/index' })
    return
  }
  try {
    const [sessRes, matchRes] = await Promise.all([getSessions(), getMatches()])
    sessions.value = sessRes.sessions
    matches.value = matchRes.matches
  } catch (e) {
    console.error('Failed to load home data', e)
  }
}

function goCreateMatch() {
  uni.navigateTo({ url: '/pages/create-match/index' })
}
function goTeam() {
  uni.switchTab({ url: '/pages/team/index' })
}
function goMatchDetail(id: string) {
  uni.navigateTo({ url: `/pages/match-detail/index?id=${id}` })
}
function goSessionDetail(id: string) {
  uni.navigateTo({ url: `/pages/session-detail/index?id=${id}` })
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
  .nav-title {
    font-size: 42rpx;
    font-weight: 700;
    color: #fff;
  }
}
.section {
  padding: 0 28rpx 28rpx;
  .section-title {
    font-size: 30rpx;
    font-weight: 600;
    color: #8B949E;
    margin-bottom: 16rpx;
    display: block;
  }
}
.action-row {
  display: flex;
  gap: 20rpx;
  .action-card {
    flex: 1;
    background: #1C2333;
    border-radius: 28rpx;
    padding: 28rpx;
    display: flex;
    align-items: center;
    gap: 16rpx;
    border: 1rpx solid rgba(255,255,255,0.08);
    .action-icon { font-size: 36rpx; }
    .action-text { font-size: 28rpx; color: #fff; font-weight: 500; }
  }
}
.match-card {
  background: linear-gradient(135deg, #3B82F6, #4F46E5);
  border-radius: 28rpx;
  padding: 28rpx;
  .match-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16rpx;
    .match-title { font-size: 30rpx; font-weight: 600; color: #fff; }
    .match-status {
      font-size: 22rpx;
      background: rgba(255,255,255,0.2);
      color: #fff;
      padding: 4rpx 16rpx;
      border-radius: 20rpx;
    }
  }
  .match-info {
    .match-meta {
      font-size: 24rpx;
      color: rgba(255,255,255,0.85);
      display: block;
      margin-bottom: 6rpx;
    }
  }
}
.stats-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16rpx;
  .stat-card {
    background: #1C2333;
    border-radius: 28rpx;
    padding: 24rpx;
    border: 1rpx solid rgba(255,255,255,0.08);
    .stat-value { font-size: 36rpx; font-weight: 700; color: #fff; display: block; }
    .stat-label { font-size: 22rpx; color: #8B949E; display: block; margin-top: 4rpx; }
  }
  .stat-distance .stat-value { color: #00E676; }
  .stat-calories .stat-value { color: #FFA502; }
  .stat-sessions .stat-value { color: #3B82F6; }
  .stat-sprints .stat-value { color: #FF4757; }
}
.empty-state {
  text-align: center;
  padding: 60rpx 0;
  .empty-text { font-size: 28rpx; color: #8B949E; display: block; }
  .empty-sub { font-size: 24rpx; color: #545d68; display: block; margin-top: 8rpx; }
}
.session-card {
  background: #1C2333;
  border-radius: 28rpx;
  padding: 24rpx 28rpx;
  margin-bottom: 16rpx;
  display: flex;
  align-items: center;
  border: 1rpx solid rgba(255,255,255,0.08);
  .session-left {
    margin-right: 24rpx;
    .session-date { font-size: 28rpx; font-weight: 600; color: #fff; display: block; }
    .session-time { font-size: 22rpx; color: #8B949E; display: block; }
  }
  .session-stats {
    flex: 1;
    display: flex;
    flex-wrap: wrap;
    gap: 8rpx 16rpx;
    .session-stat { font-size: 22rpx; color: #8B949E; }
  }
  .chevron { font-size: 36rpx; color: #30363D; }
}
</style>
