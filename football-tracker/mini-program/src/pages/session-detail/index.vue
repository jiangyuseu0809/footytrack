<template>
  <view class="page">
    <!-- Nav Bar -->
    <view class="nav-bar">
      <text class="back" @tap="goBack">‹</text>
      <text class="nav-title">训练详情</text>
    </view>

    <view v-if="session" class="content">
      <!-- Overview Hero Card -->
      <view class="overview-card">
        <view class="overview-row">
          <view class="overview-icon-box overview-icon-venue">
            <text class="overview-icon-text">📍</text>
          </view>
          <view class="overview-text-col">
            <text class="overview-label">训练时间</text>
            <text class="overview-value">{{ formatDateTime(session.startTime) }}</text>
          </view>
        </view>
        <view class="overview-row">
          <view class="overview-icon-box overview-icon-clock">
            <text class="overview-icon-text">⏱</text>
          </view>
          <view class="overview-text-col">
            <text class="overview-label">持续时间</text>
            <text class="overview-value">{{ durationStr }}</text>
          </view>
        </view>
      </view>

      <!-- Stats Grid -->
      <view class="stats-grid">
        <view class="stat-item">
          <view class="stat-icon-box stat-icon-distance">
            <text class="stat-icon-text">🏃</text>
          </view>
          <text class="stat-label">距离</text>
          <text class="stat-value stat-value-distance">{{ formatDistance(session.totalDistanceMeters) }}</text>
          <text class="stat-unit">km</text>
        </view>
        <view class="stat-item">
          <view class="stat-icon-box stat-icon-calories">
            <text class="stat-icon-text">🔥</text>
          </view>
          <text class="stat-label">卡路里</text>
          <text class="stat-value stat-value-calories">{{ Math.round(session.caloriesBurned || 0) }}</text>
          <text class="stat-unit">kcal</text>
        </view>
        <view class="stat-item">
          <view class="stat-icon-box stat-icon-maxspeed">
            <text class="stat-icon-text">⚡</text>
          </view>
          <text class="stat-label">最高速度</text>
          <text class="stat-value stat-value-maxspeed">{{ (session.maxSpeedKmh || 0).toFixed(1) }}</text>
          <text class="stat-unit">km/h</text>
        </view>
        <view class="stat-item">
          <view class="stat-icon-box stat-icon-sprint">
            <text class="stat-icon-text">💨</text>
          </view>
          <text class="stat-label">冲刺</text>
          <text class="stat-value stat-value-sprint">{{ session.sprintCount || 0 }}</text>
          <text class="stat-unit">次</text>
        </view>
        <view class="stat-item">
          <view class="stat-icon-box stat-icon-avgspeed">
            <text class="stat-icon-text">🏎</text>
          </view>
          <text class="stat-label">平均速度</text>
          <text class="stat-value stat-value-avgspeed">{{ (session.avgSpeedKmh || 0).toFixed(1) }}</text>
          <text class="stat-unit">km/h</text>
        </view>
        <view class="stat-item">
          <view class="stat-icon-box stat-icon-highintensity">
            <text class="stat-icon-text">🎯</text>
          </view>
          <text class="stat-label">高强度距离</text>
          <text class="stat-value stat-value-highintensity">{{ ((session.highIntensityDistanceMeters || 0) / 1000).toFixed(1) }}</text>
          <text class="stat-unit">km</text>
        </view>
      </view>

      <!-- Heart Rate Card -->
      <view class="section-card">
        <view class="section-header">
          <view class="section-icon-box section-icon-hr">
            <text class="section-icon-text">❤️</text>
          </view>
          <text class="section-title">心率数据</text>
        </view>
        <view class="hr-columns">
          <view class="hr-col">
            <text class="hr-col-label">平均心率</text>
            <view class="hr-value-row">
              <text class="hr-value">{{ session.avgHeartRate || '-' }}</text>
              <text class="hr-unit">bpm</text>
            </view>
          </view>
          <view class="hr-divider" />
          <view class="hr-col">
            <text class="hr-col-label">最高心率</text>
            <view class="hr-value-row">
              <text class="hr-value hr-value-max">{{ session.maxHeartRate || '-' }}</text>
              <text class="hr-unit">bpm</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Slack Index Card -->
      <view class="section-card">
        <view class="section-header">
          <view class="section-icon-box section-icon-slack">
            <text class="section-icon-text">🐟</text>
          </view>
          <text class="section-title">摸鱼指数</text>
        </view>
        <view class="slack-content">
          <view class="slack-bar-track">
            <view class="slack-bar-fill" :style="{ width: (session.slackIndex || 0) + '%' }" />
          </view>
          <view class="slack-info-row">
            <text class="slack-percentage">{{ session.slackIndex || 0 }}%</text>
            <text class="slack-label">{{ session.slackLabel || '-' }}</text>
          </view>
        </view>
      </view>

      <!-- Performance Score Card -->
      <view class="section-card">
        <view class="section-header">
          <view class="section-icon-box section-icon-perf">
            <text class="section-icon-text">📊</text>
          </view>
          <text class="section-title">综合评分</text>
        </view>
        <view class="score-content">
          <text class="score-value">{{ score.toFixed(1) }}</text>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { getSessions, type SessionDto } from '../../utils/api'
import { formatDistance, formatDateTime, formatDuration, computePerformanceScore } from '../../utils/format'

const session = ref<SessionDto | null>(null)
const durationStr = computed(() => {
  if (!session.value) return '-'
  return formatDuration(session.value.endTime - session.value.startTime)
})
const score = computed(() => session.value ? computePerformanceScore(session.value) : 0)
function goBack() { uni.navigateBack() }
onLoad(async (options) => {
  const id = options?.id
  if (!id) return
  try {
    const res = await getSessions()
    session.value = res.sessions.find(s => s.id === id) || null
  } catch (e) { console.error(e) }
})
</script>

<style lang="scss" scoped>
.page {
  min-height: 100vh;
  background: #0D1117;
}

.nav-bar {
  padding: 100rpx 32rpx 28rpx;
  display: flex;
  align-items: center;

  .back {
    font-size: 52rpx;
    color: #00E676;
    margin-right: 12rpx;
    font-weight: 300;
    line-height: 1;
  }

  .nav-title {
    font-size: 36rpx;
    font-weight: 600;
    color: #FFFFFF;
  }
}

.content {
  padding: 0 32rpx 60rpx;
}

/* ---- Overview Hero Card ---- */
.overview-card {
  background: linear-gradient(135deg, #00E676, #00BFA5);
  border-radius: 36rpx;
  padding: 32rpx;
  margin-bottom: 32rpx;
  display: flex;
  flex-direction: column;
  gap: 24rpx;
}

.overview-row {
  display: flex;
  align-items: center;
  gap: 20rpx;
}

.overview-icon-box {
  width: 64rpx;
  height: 64rpx;
  border-radius: 16rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.overview-icon-venue {
  background: rgba(0, 0, 0, 0.15);
}

.overview-icon-clock {
  background: rgba(0, 0, 0, 0.15);
}

.overview-icon-text {
  font-size: 28rpx;
}

.overview-text-col {
  display: flex;
  flex-direction: column;
}

.overview-label {
  font-size: 22rpx;
  color: rgba(0, 0, 0, 0.5);
}

.overview-value {
  font-size: 32rpx;
  font-weight: 700;
  color: #0D1117;
}

/* ---- Stats Grid (3 cols x 2 rows) ---- */
.stats-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 16rpx;
  margin-bottom: 32rpx;
}

.stat-item {
  background: #1C2333;
  border-radius: 28rpx;
  padding: 20rpx 16rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  border: 1rpx solid rgba(255, 255, 255, 0.08);
}

.stat-icon-box {
  width: 64rpx;
  height: 64rpx;
  border-radius: 16rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 8rpx;
}

.stat-icon-distance {
  background: linear-gradient(135deg, rgba(0, 230, 118, 0.2), rgba(105, 240, 174, 0.2));
}

.stat-icon-calories {
  background: linear-gradient(135deg, rgba(255, 165, 2, 0.2), rgba(255, 99, 72, 0.2));
}

.stat-icon-maxspeed {
  background: linear-gradient(135deg, rgba(46, 213, 115, 0.2), rgba(123, 237, 159, 0.2));
}

.stat-icon-sprint {
  background: linear-gradient(135deg, rgba(255, 71, 87, 0.2), rgba(255, 107, 129, 0.2));
}

.stat-icon-avgspeed {
  background: linear-gradient(135deg, rgba(59, 130, 246, 0.2), rgba(96, 165, 250, 0.2));
}

.stat-icon-highintensity {
  background: linear-gradient(135deg, rgba(168, 85, 247, 0.2), rgba(139, 92, 246, 0.2));
}

.stat-icon-text {
  font-size: 26rpx;
}

.stat-label {
  font-size: 20rpx;
  color: #8B949E;
  margin-bottom: 4rpx;
}

.stat-value {
  font-size: 32rpx;
  font-weight: 700;
}

.stat-value-distance { color: #00E676; }
.stat-value-calories { color: #FFA502; }
.stat-value-maxspeed { color: #2ED573; }
.stat-value-sprint { color: #FF4757; }
.stat-value-avgspeed { color: #3B82F6; }
.stat-value-highintensity { color: #A855F7; }

.stat-unit {
  font-size: 18rpx;
  color: #8B949E;
  margin-top: 2rpx;
}

/* ---- Section Cards ---- */
.section-card {
  background: #1C2333;
  border-radius: 32rpx;
  padding: 28rpx 32rpx;
  margin-bottom: 24rpx;
  border: 1rpx solid rgba(255, 255, 255, 0.08);
}

.section-header {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-bottom: 24rpx;
}

.section-icon-box {
  width: 52rpx;
  height: 52rpx;
  border-radius: 16rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.section-icon-hr {
  background: rgba(255, 71, 87, 0.16);
}

.section-icon-slack {
  background: rgba(255, 165, 2, 0.16);
}

.section-icon-perf {
  background: rgba(0, 230, 118, 0.16);
}

.section-icon-text {
  font-size: 24rpx;
}

.section-title {
  font-size: 30rpx;
  font-weight: 600;
  color: #FFFFFF;
}

/* ---- Heart Rate ---- */
.hr-columns {
  display: flex;
  align-items: center;
}

.hr-col {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.hr-divider {
  width: 1rpx;
  height: 80rpx;
  background: #30363D;
}

.hr-col-label {
  font-size: 22rpx;
  color: #8B949E;
  margin-bottom: 8rpx;
}

.hr-value-row {
  display: flex;
  align-items: baseline;
  gap: 6rpx;
}

.hr-value {
  font-size: 48rpx;
  font-weight: 700;
  color: #FF4757;
}

.hr-value-max {
  color: #FF6B81;
}

.hr-unit {
  font-size: 22rpx;
  color: #8B949E;
}

/* ---- Slack Index ---- */
.slack-content {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.slack-bar-track {
  width: 100%;
  height: 20rpx;
  background: #242D3D;
  border-radius: 10rpx;
  overflow: hidden;
}

.slack-bar-fill {
  height: 100%;
  background: #FFA502;
  border-radius: 10rpx;
  transition: width 0.3s;
}

.slack-info-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.slack-percentage {
  font-size: 36rpx;
  font-weight: 700;
  color: #FFA502;
}

.slack-label {
  font-size: 24rpx;
  color: #8B949E;
}

/* ---- Performance Score ---- */
.score-content {
  display: flex;
  justify-content: center;
  padding: 16rpx 0 8rpx;
}

.score-value {
  font-size: 80rpx;
  font-weight: 700;
  color: #00BFA5;
}
</style>
