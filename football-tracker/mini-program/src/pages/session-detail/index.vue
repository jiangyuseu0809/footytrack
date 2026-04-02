<template>
  <view class="page">
    <view class="nav-bar">
      <text class="back" @tap="goBack">‹</text>
      <text class="nav-title">训练详情</text>
    </view>

    <view v-if="session" class="content">
      <!-- Overview -->
      <view class="overview-card">
        <text class="overview-date">{{ formatDateTime(session.startTime) }}</text>
        <text class="overview-duration">{{ durationStr }}</text>
      </view>

      <!-- Key Metrics -->
      <view class="metrics-grid">
        <view class="metric-card">
          <text class="metric-icon">🏃</text>
          <text class="metric-value distance">{{ formatDistance(session.totalDistanceMeters) }}</text>
          <text class="metric-label">距离</text>
        </view>
        <view class="metric-card">
          <text class="metric-icon">🔥</text>
          <text class="metric-value calories">{{ Math.round(session.caloriesBurned || 0) }}</text>
          <text class="metric-label">卡路里</text>
        </view>
        <view class="metric-card">
          <text class="metric-icon">⚡</text>
          <text class="metric-value speed">{{ (session.maxSpeedKmh || 0).toFixed(1) }}</text>
          <text class="metric-label">最高速度</text>
        </view>
        <view class="metric-card">
          <text class="metric-icon">💨</text>
          <text class="metric-value sprints">{{ session.sprintCount || 0 }}</text>
          <text class="metric-label">冲刺次数</text>
        </view>
      </view>

      <!-- Heart Rate -->
      <view class="detail-card">
        <text class="card-title">❤️ 心率数据</text>
        <view class="hr-row">
          <view class="hr-stat">
            <text class="hr-value">{{ session.avgHeartRate || '-' }}</text>
            <text class="hr-label">平均 bpm</text>
          </view>
          <view class="hr-stat">
            <text class="hr-value max">{{ session.maxHeartRate || '-' }}</text>
            <text class="hr-label">最高 bpm</text>
          </view>
        </view>
      </view>

      <!-- Slack Index -->
      <view class="detail-card">
        <text class="card-title">🐟 摸鱼指数</text>
        <view class="slack-row">
          <view class="slack-bar-bg">
            <view class="slack-bar" :style="{ width: (session.slackIndex || 0) + '%' }" />
          </view>
          <text class="slack-value">{{ session.slackIndex || 0 }}%</text>
        </view>
        <text class="slack-label">{{ session.slackLabel || '-' }}</text>
      </view>

      <!-- Performance -->
      <view class="detail-card">
        <text class="card-title">📊 综合评分</text>
        <text class="score-value">{{ score.toFixed(1) }}</text>
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
.page { min-height: 100vh; background: #0D1117; }
.nav-bar {
  padding: 100rpx 28rpx 28rpx;
  display: flex; align-items: center;
  .back { font-size: 52rpx; color: #00E676; margin-right: 12rpx; font-weight: 300; }
  .nav-title { font-size: 36rpx; font-weight: 600; color: #fff; }
}
.content { padding: 0 28rpx 60rpx; }
.overview-card {
  background: linear-gradient(135deg, #00E676, #00BFA5);
  border-radius: 28rpx; padding: 32rpx; margin-bottom: 20rpx;
  .overview-date { font-size: 26rpx; color: rgba(0,0,0,0.6); display: block; }
  .overview-duration { font-size: 56rpx; font-weight: 700; color: #0D1117; display: block; }
}
.metrics-grid {
  display: grid; grid-template-columns: 1fr 1fr; gap: 16rpx; margin-bottom: 20rpx;
  .metric-card {
    background: #1C2333; border-radius: 28rpx; padding: 24rpx;
    text-align: center; border: 1rpx solid rgba(255,255,255,0.08);
    .metric-icon { font-size: 32rpx; display: block; }
    .metric-value { font-size: 36rpx; font-weight: 700; display: block; margin: 8rpx 0 4rpx; }
    .metric-label { font-size: 22rpx; color: #8B949E; display: block; }
    .distance { color: #00E676; }
    .calories { color: #FFA502; }
    .speed { color: #3B82F6; }
    .sprints { color: #FF4757; }
  }
}
.detail-card {
  background: #1C2333; border-radius: 28rpx; padding: 24rpx 28rpx;
  margin-bottom: 16rpx; border: 1rpx solid rgba(255,255,255,0.08);
  .card-title { font-size: 26rpx; color: #8B949E; display: block; margin-bottom: 16rpx; }
}
.hr-row {
  display: flex; gap: 40rpx;
  .hr-stat {
    .hr-value { font-size: 40rpx; font-weight: 700; color: #FF4757; display: block; }
    .hr-value.max { color: #FF6B81; }
    .hr-label { font-size: 22rpx; color: #8B949E; display: block; }
  }
}
.slack-row {
  display: flex; align-items: center; gap: 16rpx; margin-bottom: 8rpx;
  .slack-bar-bg {
    flex: 1; height: 16rpx; background: #242D3D; border-radius: 8rpx;
    .slack-bar { height: 100%; background: #FFA502; border-radius: 8rpx; }
  }
  .slack-value { font-size: 28rpx; font-weight: 600; color: #FFA502; }
}
.slack-label { font-size: 24rpx; color: #8B949E; }
.score-value { font-size: 64rpx; font-weight: 700; color: #00BFA5; display: block; text-align: center; }
</style>
