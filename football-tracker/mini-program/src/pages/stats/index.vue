<template>
  <view class="page">
    <view class="nav-bar">
      <text class="nav-title">统计</text>
    </view>

    <scroll-view scroll-y class="scroll-area">
      <!-- Empty State -->
      <view v-if="sessions.length === 0" class="empty-state">
        <view class="empty-icon-box">
          <text class="empty-icon">📊</text>
        </view>
        <text class="empty-title">暂无训练记录</text>
        <text class="empty-sub">在手表上完成训练后数据将显示在这里</text>
      </view>

      <template v-if="sessions.length > 0">
        <!-- Overview Section -->
        <view class="section">
          <view class="section-header">
            <view class="section-icon-box">
              <text class="section-icon">📈</text>
            </view>
            <text class="section-title">数据概览</text>
          </view>
          <view class="overview-card">
            <view class="overview-grid">
              <view class="overview-tile">
                <view class="tile-icon-box blue-gradient">
                  <text class="tile-icon">🏟️</text>
                </view>
                <text class="tile-label">总场次</text>
                <view class="tile-value-row">
                  <text class="tile-value">{{ overviewStats.totalSessions }}</text>
                  <text class="tile-unit">场</text>
                </view>
              </view>
              <view class="overview-tile">
                <view class="tile-icon-box green-gradient">
                  <text class="tile-icon">🏃</text>
                </view>
                <text class="tile-label">总距离</text>
                <view class="tile-value-row">
                  <text class="tile-value">{{ overviewStats.totalDistance }}</text>
                </view>
              </view>
              <view class="overview-tile">
                <view class="tile-icon-box orange-gradient">
                  <text class="tile-icon">🔥</text>
                </view>
                <text class="tile-label">总卡路里</text>
                <view class="tile-value-row">
                  <text class="tile-value">{{ overviewStats.totalCalories }}</text>
                  <text class="tile-unit">kcal</text>
                </view>
              </view>
              <view class="overview-tile">
                <view class="tile-icon-box teal-gradient">
                  <text class="tile-icon">⏱️</text>
                </view>
                <text class="tile-label">平均速度</text>
                <view class="tile-value-row">
                  <text class="tile-value">{{ overviewStats.avgSpeed }}</text>
                  <text class="tile-unit">km/h</text>
                </view>
              </view>
              <view class="overview-tile">
                <view class="tile-icon-box red-gradient">
                  <text class="tile-icon">⚡</text>
                </view>
                <text class="tile-label">最高速度</text>
                <view class="tile-value-row">
                  <text class="tile-value">{{ overviewStats.maxSpeed }}</text>
                  <text class="tile-unit">km/h</text>
                </view>
              </view>
              <view class="overview-tile">
                <view class="tile-icon-box purple-gradient">
                  <text class="tile-icon">💨</text>
                </view>
                <text class="tile-label">总冲刺</text>
                <view class="tile-value-row">
                  <text class="tile-value">{{ overviewStats.totalSprints }}</text>
                  <text class="tile-unit">次</text>
                </view>
              </view>
            </view>
          </view>
        </view>

        <!-- History Section -->
        <view class="section">
          <view class="section-header">
            <view class="section-icon-box">
              <text class="section-icon">📋</text>
            </view>
            <text class="section-title">比赛记录</text>
          </view>

          <view v-for="day in daySections" :key="day.date" class="day-card" @tap="goDetail(day)">
            <view class="day-header">
              <view class="day-date-row">
                <text class="day-date">{{ day.dateStr }}</text>
                <text class="day-weekday">{{ day.weekday }}</text>
              </view>
              <view class="day-badge">
                <text class="badge-text">{{ day.sessions.length }}场</text>
              </view>
            </view>
            <view class="day-divider" />
            <view class="day-stats">
              <view class="day-stat">
                <text class="stat-value distance">{{ formatDistance(day.totalDistance) }}</text>
                <text class="stat-label">距离</text>
              </view>
              <view class="stat-divider" />
              <view class="day-stat">
                <text class="stat-value calories">{{ Math.round(day.totalCalories) }}</text>
                <text class="stat-label">卡路里</text>
              </view>
              <view class="stat-divider" />
              <view class="day-stat">
                <text class="stat-value speed">{{ day.maxSpeed.toFixed(1) }}</text>
                <text class="stat-label">最高速度</text>
              </view>
              <view class="stat-divider" />
              <view class="day-stat">
                <text class="stat-value score">{{ day.avgScore.toFixed(1) }}</text>
                <text class="stat-label">评分</text>
              </view>
            </view>
          </view>
        </view>
      </template>
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
  maxSpeed: number
  avgScore: number
}

const overviewStats = computed(() => ({
  totalSessions: sessions.value.length,
  totalDistance: formatDistance(sessions.value.reduce((s, v) => s + (v.totalDistanceMeters || 0), 0)),
  totalCalories: Math.round(sessions.value.reduce((s, v) => s + (v.caloriesBurned || 0), 0)),
  avgSpeed: sessions.value.length ? (sessions.value.reduce((s, v) => s + (v.avgSpeedKmh || 0), 0) / sessions.value.length).toFixed(1) : '0',
  maxSpeed: sessions.value.length ? Math.max(...sessions.value.map(s => s.maxSpeedKmh || 0)).toFixed(1) : '0',
  totalSprints: sessions.value.reduce((s, v) => s + (v.sprintCount || 0), 0),
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
$pageBg: #0D1117;
$cardBg: #1C2333;
$cardBgLight: #242D3D;
$divider: #30363D;
$neonGreen: #00E676;
$textPrimary: #FFFFFF;
$textSecondary: #8B949E;

.page {
  min-height: 100vh;
  background: $pageBg;
}
.nav-bar {
  padding: 100rpx 32rpx 28rpx;
  .nav-title { font-size: 40rpx; font-weight: 700; color: $textPrimary; }
}
.scroll-area {
  height: calc(100vh - 170rpx);
  padding-bottom: 120rpx;
}

/* Empty State */
.empty-state {
  text-align: center;
  padding: 120rpx 48rpx;
  .empty-icon-box {
    width: 120rpx; height: 120rpx; border-radius: 32rpx;
    background: rgba(0, 230, 118, 0.1);
    display: flex; align-items: center; justify-content: center;
    margin: 0 auto 24rpx;
    .empty-icon { font-size: 56rpx; }
  }
  .empty-title { font-size: 32rpx; font-weight: 600; color: $textPrimary; display: block; margin-bottom: 8rpx; }
  .empty-sub { font-size: 26rpx; color: $textSecondary; display: block; }
}

/* Section */
.section {
  padding: 0 32rpx 32rpx;
}
.section-header {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-bottom: 20rpx;
  .section-icon-box {
    width: 52rpx; height: 52rpx; border-radius: 16rpx;
    background: rgba(0, 230, 118, 0.16);
    display: flex; align-items: center; justify-content: center;
    .section-icon { font-size: 26rpx; }
  }
  .section-title { font-size: 30rpx; font-weight: 600; color: $textPrimary; }
}

/* Overview Card */
.overview-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 24rpx;
  border: 1rpx solid rgba(255, 255, 255, 0.08);
}
.overview-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 20rpx;
}
.overview-tile {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 6rpx;
  .tile-label { font-size: 20rpx; color: $textSecondary; }
  .tile-value-row {
    display: flex;
    align-items: baseline;
    gap: 4rpx;
    .tile-value { font-size: 32rpx; font-weight: 700; color: $textPrimary; }
    .tile-unit { font-size: 18rpx; color: $textSecondary; }
  }
}
.tile-icon-box {
  width: 64rpx; height: 64rpx; border-radius: 16rpx;
  display: flex; align-items: center; justify-content: center;
  margin-bottom: 4rpx;
  .tile-icon { font-size: 28rpx; }
}
.blue-gradient { background: linear-gradient(135deg, #3B82F6, #60A5FA); }
.green-gradient { background: linear-gradient(135deg, #00E676, #69F0AE); }
.orange-gradient { background: linear-gradient(135deg, #FFA502, #FF6348); }
.teal-gradient { background: linear-gradient(135deg, #2ED573, #7BED9F); }
.red-gradient { background: linear-gradient(135deg, #FF4757, #FF6B81); }
.purple-gradient { background: linear-gradient(135deg, #A855F7, #8B5CF6); }

/* Day Cards */
.day-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 24rpx 28rpx;
  margin-bottom: 20rpx;
  border: 1rpx solid rgba(255, 255, 255, 0.08);
}
.day-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  .day-date-row {
    display: flex;
    align-items: baseline;
    gap: 12rpx;
    .day-date { font-size: 30rpx; font-weight: 600; color: $textPrimary; }
    .day-weekday { font-size: 24rpx; color: $textSecondary; }
  }
  .day-badge {
    background: rgba(0, 230, 118, 0.16);
    padding: 6rpx 16rpx;
    border-radius: 20rpx;
    .badge-text { font-size: 22rpx; color: $neonGreen; font-weight: 600; }
  }
}
.day-divider {
  height: 1rpx;
  background: rgba(48, 54, 61, 0.6);
  margin: 16rpx 0;
}
.day-stats {
  display: flex;
  align-items: center;
}
.day-stat {
  flex: 1;
  text-align: center;
  .stat-value { font-size: 30rpx; font-weight: 700; display: block; }
  .stat-label { font-size: 20rpx; color: $textSecondary; display: block; margin-top: 4rpx; }
  .distance { color: #00E676; }
  .calories { color: #FFA502; }
  .speed { color: #3B82F6; }
  .score { color: #00BFA5; }
}
.stat-divider {
  width: 1rpx;
  height: 48rpx;
  background: rgba(48, 54, 61, 0.6);
}
</style>
