<template>
  <view class="page">
    <!-- Nav Bar -->
    <view class="nav-bar">
      <text class="nav-title">野球记</text>
    </view>

    <scroll-view scroll-y class="scroll-content">
      <!-- Two Action Cards -->
      <view class="section">
        <view class="action-row">
          <!-- 本周比赛 card: blue-indigo gradient -->
          <view class="action-card action-card--match" @tap="goMatchDetail(nextMatch?.id || '')">
            <view class="action-icon-box action-icon-box--blue">
              <text class="action-icon-emoji">⚽</text>
            </view>
            <view class="action-card-body">
              <text class="action-card-title">本周比赛</text>
              <text class="action-card-sub" v-if="weeklyMatchCount > 0">{{ weeklyMatchCount }} 场比赛</text>
              <text class="action-card-sub" v-else>暂无比赛</text>
            </view>
          </view>

          <!-- 发起比赛 card: dark card with neon green accent -->
          <view class="action-card action-card--create" @tap="goCreateMatch">
            <view class="action-icon-box action-icon-box--green">
              <text class="action-icon-emoji">➕</text>
            </view>
            <view class="action-card-body">
              <text class="action-card-title">发起比赛</text>
              <text class="action-card-sub">创建新比赛</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Upcoming Match Card -->
      <view v-if="nextMatch" class="section">
        <view class="upcoming-card" @tap="goMatchDetail(nextMatch.id)">
          <view class="upcoming-top">
            <view class="upcoming-title-row">
              <text class="upcoming-title">{{ nextMatch.title }}</text>
              <view class="status-badge" :class="statusBadgeClass(nextMatch.status)">
                <text class="status-badge-text">{{ statusLabel(nextMatch.status) }}</text>
              </view>
            </view>
          </view>
          <view class="upcoming-divider"></view>
          <view class="upcoming-details">
            <view class="upcoming-detail-row">
              <text class="upcoming-detail-icon">📍</text>
              <text class="upcoming-detail-text">{{ nextMatch.location }}</text>
            </view>
            <view class="upcoming-detail-row">
              <text class="upcoming-detail-icon">📅</text>
              <text class="upcoming-detail-text">{{ formatDateTime(nextMatch.matchDate) }}</text>
            </view>
            <view class="upcoming-detail-row">
              <text class="upcoming-detail-icon">👤</text>
              <text class="upcoming-detail-text">{{ nextMatch.registrationCount }} 人已报名</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Stats Section: 关键数据 -->
      <view class="section">
        <view class="section-header">
          <view class="section-header-icon">
            <text class="section-header-icon-text">📊</text>
          </view>
          <text class="section-header-title">关键数据</text>
        </view>
        <view class="stats-card">
          <view class="stats-grid">
            <!-- 距离 -->
            <view class="stat-item">
              <view class="stat-icon-box stat-icon-box--green">
                <text class="stat-icon-emoji">🏃</text>
              </view>
              <text class="stat-label">距离</text>
              <text class="stat-value stat-value--green">{{ monthlyStats.distance }}</text>
            </view>
            <!-- 卡路里 -->
            <view class="stat-item">
              <view class="stat-icon-box stat-icon-box--orange">
                <text class="stat-icon-emoji">🔥</text>
              </view>
              <text class="stat-label">卡路里</text>
              <text class="stat-value stat-value--orange">{{ monthlyStats.calories }}</text>
            </view>
            <!-- 场次 -->
            <view class="stat-item">
              <view class="stat-icon-box stat-icon-box--blue">
                <text class="stat-icon-emoji">⚽</text>
              </view>
              <text class="stat-label">场次</text>
              <text class="stat-value stat-value--blue">{{ monthlyStats.sessions }}</text>
            </view>
            <!-- 冲刺 -->
            <view class="stat-item">
              <view class="stat-icon-box stat-icon-box--red">
                <text class="stat-icon-emoji">⚡</text>
              </view>
              <text class="stat-label">冲刺</text>
              <text class="stat-value stat-value--red">{{ monthlyStats.sprints }}</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Recent Sessions: 最近记录 -->
      <view class="section section--last">
        <view class="section-header">
          <view class="section-header-icon">
            <text class="section-header-icon-text">📋</text>
          </view>
          <text class="section-header-title">最近记录</text>
        </view>

        <view v-if="recentSessions.length === 0" class="empty-state">
          <text class="empty-icon">📭</text>
          <text class="empty-text">暂无训练数据</text>
          <text class="empty-sub">在手表上开始追踪后数据将显示在这里</text>
        </view>

        <view
          v-for="session in recentSessions"
          :key="session.id"
          class="session-card"
          @tap="goSessionDetail(session.id)"
        >
          <view class="session-top">
            <view class="session-date-badge">
              <text class="session-date-text">{{ formatRelativeDate(session.startTime) }}</text>
            </view>
            <text class="session-duration">{{ formatDuration(session.endTime - session.startTime) }}</text>
          </view>
          <view class="session-divider"></view>
          <view class="session-stats-row">
            <view class="session-stat-item">
              <text class="session-stat-label">距离</text>
              <text class="session-stat-value session-stat-value--green">{{ formatDistance(session.totalDistanceMeters) }}</text>
            </view>
            <view class="session-stat-divider"></view>
            <view class="session-stat-item">
              <text class="session-stat-label">卡路里</text>
              <text class="session-stat-value session-stat-value--orange">{{ Math.round(session.caloriesBurned || 0) }}</text>
            </view>
            <view class="session-stat-divider"></view>
            <view class="session-stat-item">
              <text class="session-stat-label">最高速度</text>
              <text class="session-stat-value session-stat-value--blue">{{ (session.maxSpeedKmh || 0).toFixed(1) }} km/h</text>
            </view>
          </view>
        </view>
      </view>
    </scroll-view>
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

const weeklyMatchCount = computed(() => {
  const now = new Date()
  const weekStart = new Date(now)
  weekStart.setDate(now.getDate() - now.getDay())
  weekStart.setHours(0, 0, 0, 0)
  const weekEnd = new Date(weekStart)
  weekEnd.setDate(weekStart.getDate() + 7)
  return matches.value.filter(m => m.matchDate >= weekStart.getTime() && m.matchDate < weekEnd.getTime()).length
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

function statusLabel(status: string): string {
  if (status === 'upcoming') return '报名中'
  if (status === 'live') return '进行中'
  return '已结束'
}

function statusBadgeClass(status: string): string {
  if (status === 'upcoming') return 'status-badge--upcoming'
  if (status === 'live') return 'status-badge--live'
  return 'status-badge--ended'
}

async function loadData() {
  if (!isLoggedIn()) return
  try {
    const [sessRes, matchRes] = await Promise.all([getSessions(), getMatches()])
    sessions.value = sessRes.sessions
    matches.value = matchRes.matches
  } catch (e) {
    console.error('Failed to load home data', e)
  }
}

function requireLogin() {
  if (!isLoggedIn()) {
    uni.navigateTo({ url: '/pages/login/index' })
    return true
  }
  return false
}

function goCreateMatch() {
  if (requireLogin()) return
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
// ============================================================
// Design tokens (matching iOS exactly)
// ============================================================
$pageBg: #0D1117;
$cardBg: #1C2333;
$cardElevated: #242D3D;
$border: 1rpx solid rgba(255, 255, 255, 0.08);
$divider: #30363D;
$neonGreen: #00E676;
$teal: #00BFA5;
$textPrimary: #FFFFFF;
$textSecondary: #8B949E;

// ============================================================
// Page
// ============================================================
.page {
  min-height: 100vh;
  background: $pageBg;
  display: flex;
  flex-direction: column;
}

.scroll-content {
  flex: 1;
  height: calc(100vh - 180rpx);
}

// ============================================================
// Nav Bar
// ============================================================
.nav-bar {
  padding: 100rpx 32rpx 24rpx;
  background: $pageBg;

  .nav-title {
    font-size: 48rpx;
    font-weight: 700;
    color: $textPrimary;
  }
}

// ============================================================
// Sections
// ============================================================
.section {
  padding: 0 32rpx 32rpx;
}

.section--last {
  padding-bottom: 160rpx;
}

// Section header (icon box + title)
.section-header {
  display: flex;
  align-items: center;
  margin-bottom: 20rpx;

  .section-header-icon {
    width: 52rpx;
    height: 52rpx;
    border-radius: 16rpx;
    background: rgba(0, 230, 118, 0.16);
    display: flex;
    align-items: center;
    justify-content: center;
    margin-right: 16rpx;

    .section-header-icon-text {
      font-size: 28rpx;
      line-height: 1;
    }
  }

  .section-header-title {
    font-size: 30rpx;
    font-weight: 600;
    color: $textPrimary;
  }
}

// ============================================================
// Action Cards (two side by side)
// ============================================================
.action-row {
  display: flex;
  gap: 20rpx;
}

.action-card {
  flex: 1;
  height: 200rpx;
  border-radius: 32rpx;
  padding: 24rpx;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  overflow: hidden;
  position: relative;
}

.action-card--match {
  background: linear-gradient(135deg, #3B82F6, #4F46E5);
}

.action-card--create {
  background: $cardBg;
  border: $border;
  box-shadow: inset 0 0 0 1rpx rgba(0, 230, 118, 0.12);
}

.action-icon-box {
  width: 64rpx;
  height: 64rpx;
  border-radius: 16rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.action-icon-box--blue {
  background: rgba(255, 255, 255, 0.2);
}

.action-icon-box--green {
  background: rgba(0, 230, 118, 0.16);
}

.action-icon-emoji {
  font-size: 32rpx;
  line-height: 1;
}

.action-card-body {
  display: flex;
  flex-direction: column;
}

.action-card-title {
  font-size: 30rpx;
  font-weight: 600;
  color: $textPrimary;
}

.action-card-sub {
  font-size: 22rpx;
  color: rgba(255, 255, 255, 0.7);
  margin-top: 4rpx;
}

.action-card--create {
  .action-card-sub {
    color: $textSecondary;
  }
}

// ============================================================
// Upcoming Match Card
// ============================================================
.upcoming-card {
  background: linear-gradient(135deg, #16803B, #166534);
  border-radius: 36rpx;
  padding: 28rpx 32rpx;
}

.upcoming-top {
  margin-bottom: 20rpx;
}

.upcoming-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.upcoming-title {
  font-size: 32rpx;
  font-weight: 700;
  color: $textPrimary;
  flex: 1;
  margin-right: 16rpx;
}

// Status badge
.status-badge {
  padding: 6rpx 20rpx;
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.status-badge--upcoming {
  background: #FACC15;

  .status-badge-text {
    color: #000000;
  }
}

.status-badge--live {
  background: $neonGreen;

  .status-badge-text {
    color: #000000;
  }
}

.status-badge--ended {
  background: rgba(255, 255, 255, 0.2);

  .status-badge-text {
    color: $textSecondary;
  }
}

.status-badge-text {
  font-size: 22rpx;
  font-weight: 600;
}

.upcoming-divider {
  height: 1rpx;
  background: rgba(255, 255, 255, 0.15);
  margin-bottom: 20rpx;
}

.upcoming-details {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.upcoming-detail-row {
  display: flex;
  align-items: center;
  gap: 12rpx;

  .upcoming-detail-icon {
    font-size: 24rpx;
    line-height: 1;
  }

  .upcoming-detail-text {
    font-size: 26rpx;
    color: rgba(255, 255, 255, 0.85);
  }
}

// ============================================================
// Stats Card (2x2 grid inside single card)
// ============================================================
.stats-card {
  background: $cardBg;
  border-radius: 32rpx;
  border: $border;
  padding: 28rpx 24rpx;
}

.stats-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 28rpx 24rpx;
}

.stat-item {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
}

.stat-icon-box {
  width: 64rpx;
  height: 64rpx;
  border-radius: 16rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 12rpx;
}

.stat-icon-box--green {
  background: linear-gradient(135deg, rgba(0, 230, 118, 0.25), rgba(0, 191, 165, 0.25));
}

.stat-icon-box--orange {
  background: linear-gradient(135deg, rgba(255, 165, 2, 0.25), rgba(255, 107, 0, 0.25));
}

.stat-icon-box--blue {
  background: linear-gradient(135deg, rgba(59, 130, 246, 0.25), rgba(79, 70, 229, 0.25));
}

.stat-icon-box--red {
  background: linear-gradient(135deg, rgba(255, 71, 87, 0.25), rgba(234, 32, 39, 0.25));
}

.stat-icon-emoji {
  font-size: 30rpx;
  line-height: 1;
}

.stat-label {
  font-size: 24rpx;
  color: $textSecondary;
  margin-bottom: 4rpx;
}

.stat-value {
  font-size: 36rpx;
  font-weight: 700;
}

.stat-value--green {
  color: $neonGreen;
}

.stat-value--orange {
  color: #FFA502;
}

.stat-value--blue {
  color: #3B82F6;
}

.stat-value--red {
  color: #FF4757;
}

// ============================================================
// Empty State
// ============================================================
.empty-state {
  text-align: center;
  padding: 60rpx 0;
  display: flex;
  flex-direction: column;
  align-items: center;

  .empty-icon {
    font-size: 64rpx;
    margin-bottom: 16rpx;
  }

  .empty-text {
    font-size: 28rpx;
    color: $textSecondary;
    display: block;
  }

  .empty-sub {
    font-size: 24rpx;
    color: #545D68;
    display: block;
    margin-top: 8rpx;
  }
}

// ============================================================
// Session Cards
// ============================================================
.session-card {
  background: $cardBg;
  border-radius: 28rpx;
  border: $border;
  padding: 24rpx 28rpx;
  margin-bottom: 16rpx;
}

.session-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16rpx;
}

.session-date-badge {
  .session-date-text {
    font-size: 28rpx;
    font-weight: 600;
    color: $textPrimary;
  }
}

.session-duration {
  font-size: 24rpx;
  color: $textSecondary;
}

.session-divider {
  height: 1rpx;
  background: $divider;
  margin-bottom: 16rpx;
}

.session-stats-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.session-stat-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.session-stat-label {
  font-size: 20rpx;
  color: $textSecondary;
  margin-bottom: 4rpx;
}

.session-stat-value {
  font-size: 26rpx;
  font-weight: 600;
}

.session-stat-value--green {
  color: $neonGreen;
}

.session-stat-value--orange {
  color: #FFA502;
}

.session-stat-value--blue {
  color: #3B82F6;
}

.session-stat-divider {
  width: 1rpx;
  height: 48rpx;
  background: $divider;
}
</style>
