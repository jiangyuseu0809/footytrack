<template>
  <view class="page">
    <!-- Header -->
    <view class="header">
      <view class="header-nav">
        <view class="back-row" @tap="goBack">
          <text class="back-arrow">‹</text>
          <text class="back-text">返回</text>
        </view>
        <text class="nav-title">{{ matchName }}</text>
        <view class="nav-right" />
      </view>
      <text class="header-sub">{{ dateStr }} · {{ locationStr }}</text>
    </view>

    <scroll-view v-if="session" scroll-y class="scroll-area">
      <!-- Core Stats -->
      <view class="section">
        <view class="stats-card">
          <text class="card-title">核心数据</text>
          <view class="stats-row">
            <view class="stat-cell">
              <view class="stat-icon-box orange-red">
                <text class="stat-icon">🔥</text>
              </view>
              <text class="stat-sub-label">热量</text>
              <text class="stat-big-value">{{ Math.round(session.caloriesBurned || 0) }}</text>
              <text class="stat-tiny-unit">kcal</text>
            </view>
            <view class="stat-cell">
              <view class="stat-icon-box blue">
                <text class="stat-icon">📍</text>
              </view>
              <text class="stat-sub-label">距离</text>
              <text class="stat-big-value">{{ distanceKm }}</text>
              <text class="stat-tiny-unit">km</text>
            </view>
            <view class="stat-cell">
              <view class="stat-icon-box yellow-orange">
                <text class="stat-icon">⚡</text>
              </view>
              <text class="stat-sub-label">冲刺</text>
              <text class="stat-big-value">{{ session.sprintCount || 0 }}</text>
              <text class="stat-tiny-unit">次</text>
            </view>
          </view>
          <view class="stats-row">
            <view class="stat-cell">
              <view class="stat-icon-box purple">
                <text class="stat-icon">⏱️</text>
              </view>
              <text class="stat-sub-label">时长</text>
              <text class="stat-big-value">{{ durationMin }}</text>
              <text class="stat-tiny-unit">分钟</text>
            </view>
            <view class="stat-cell">
              <view class="stat-icon-box pink-red">
                <text class="stat-icon">❤️</text>
              </view>
              <text class="stat-sub-label">最高心率</text>
              <text class="stat-big-value">{{ session.maxHeartRate || '-' }}</text>
              <text class="stat-tiny-unit">bpm</text>
            </view>
            <view class="stat-cell">
              <view class="stat-icon-box green-teal">
                <text class="stat-icon">❤️</text>
              </view>
              <text class="stat-sub-label">平均心率</text>
              <text class="stat-big-value">{{ session.avgHeartRate || '-' }}</text>
              <text class="stat-tiny-unit">bpm</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Heart Rate Placeholder -->
      <view v-if="session.avgHeartRate" class="section">
        <view class="chart-card">
          <view class="chart-header">
            <text class="chart-header-icon">📈</text>
            <text class="chart-header-title">心率变化曲线</text>
          </view>
          <view class="hr-chart-placeholder">
            <view class="hr-bar-row">
              <view v-for="(bar, i) in heartRateBars" :key="i" class="hr-bar-col">
                <view class="hr-bar" :style="{ height: bar.height + '%' }" />
                <text class="hr-bar-label">{{ bar.label }}</text>
              </view>
            </view>
            <view class="hr-chart-info">
              <text class="hr-chart-info-text">平均 {{ session.avgHeartRate }} bpm · 最高 {{ session.maxHeartRate }} bpm</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Ability Analysis -->
      <view class="section">
        <view class="chart-card">
          <view class="chart-header">
            <text class="chart-header-icon">🎯</text>
            <text class="chart-header-title">能力分析图</text>
          </view>
          <view class="radar-placeholder">
            <view class="radar-grid">
              <view v-for="item in abilityData" :key="item.ability" class="radar-item">
                <text class="radar-label">{{ item.ability }}</text>
                <view class="radar-bar-track">
                  <view class="radar-bar-fill" :style="{ width: item.value + '%' }" />
                </view>
                <text class="radar-bar-value">{{ item.value }}</text>
              </view>
            </view>
          </view>
        </view>
      </view>

      <!-- Heat Map -->
      <view class="section">
        <view class="chart-card">
          <text class="chart-card-title">跑动覆盖热力图</text>
          <view class="heatmap-box">
            <view class="field-outline">
              <view class="field-center-line" />
              <view class="field-center-circle" />
            </view>
            <view class="heat-point heat-1" />
            <view class="heat-point heat-2" />
            <view class="heat-point heat-3" />
          </view>
          <view class="heatmap-legend">
            <text class="legend-text">低活跃度</text>
            <view class="legend-bar" />
            <text class="legend-text">高活跃度</text>
          </view>
        </view>
      </view>

      <!-- Slack Index -->
      <view v-if="session.slackIndex != null" class="section">
        <view class="chart-card">
          <view class="chart-header">
            <text class="chart-header-icon">🐟</text>
            <text class="chart-header-title">摸鱼指数</text>
          </view>
          <view class="slack-content">
            <view class="slack-bar-track">
              <view class="slack-bar-fill" :style="{ width: (session.slackIndex || 0) + '%' }" />
            </view>
            <view class="slack-info-row">
              <text class="slack-percentage">{{ session.slackIndex || 0 }}%</text>
              <text class="slack-label-text">{{ session.slackLabel || '-' }}</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Performance Score -->
      <view class="section section--last">
        <view class="chart-card">
          <view class="chart-header">
            <text class="chart-header-icon">📊</text>
            <text class="chart-header-title">综合评分</text>
          </view>
          <view class="score-content">
            <text class="score-value">{{ score.toFixed(1) }}</text>
          </view>
        </view>
      </view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { getSessions, type SessionDto } from '../../utils/api'
import { formatDistance, formatDateTime, formatDuration, computePerformanceScore } from '../../utils/format'

const session = ref<SessionDto | null>(null)

const matchName = computed(() => '训练详情')
const dateStr = computed(() => session.value ? formatDateTime(session.value.startTime) : '')
const locationStr = computed(() => '运动场')

const distanceKm = computed(() => {
  if (!session.value) return '0'
  return ((session.value.totalDistanceMeters || 0) / 1000).toFixed(1)
})

const durationMin = computed(() => {
  if (!session.value) return 0
  return Math.round((session.value.endTime - session.value.startTime) / 60000)
})

const score = computed(() => session.value ? computePerformanceScore(session.value) : 0)

const heartRateBars = computed(() => {
  if (!session.value || !session.value.avgHeartRate) return []
  const avg = session.value.avgHeartRate || 120
  const max = session.value.maxHeartRate || 150
  // Generate simulated bar chart data based on avg/max
  const points = [
    { label: '开始', value: Math.round(avg * 0.6) },
    { label: '15\'', value: Math.round(avg * 0.85) },
    { label: '30\'', value: avg },
    { label: '45\'', value: Math.round((avg + max) / 2) },
    { label: '60\'', value: Math.round(avg * 1.05) },
    { label: '75\'', value: max },
    { label: '结束', value: Math.round(avg * 0.65) },
  ]
  const maxVal = Math.max(...points.map(p => p.value))
  return points.map(p => ({ label: p.label, height: Math.round((p.value / maxVal) * 100) }))
})

const abilityData = computed(() => {
  if (!session.value) {
    return [
      { ability: '速度', value: 0 },
      { ability: '耐力', value: 0 },
      { ability: '爆发力', value: 0 },
      { ability: '灵活性', value: 0 },
      { ability: '体能', value: 0 },
      { ability: '持久力', value: 0 },
    ]
  }
  const s = session.value
  const maxSpeed = s.maxSpeedKmh || 0
  const avgSpeed = s.avgSpeedKmh || 0
  const dist = (s.totalDistanceMeters || 0) / 1000
  const sprints = s.sprintCount || 0
  return [
    { ability: '速度', value: Math.min(100, Math.round(maxSpeed * 4)) },
    { ability: '耐力', value: Math.min(100, Math.round(dist * 15)) },
    { ability: '爆发力', value: Math.min(100, Math.round(sprints * 5)) },
    { ability: '灵活性', value: Math.min(100, Math.round(avgSpeed * 8)) },
    { ability: '体能', value: Math.min(100, Math.round((dist + avgSpeed) * 6)) },
    { ability: '持久力', value: Math.min(100, Math.round(dist * 12)) },
  ]
})

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
  height: calc(100vh - 280rpx);
}

// ============================================================
// Header
// ============================================================
.header {
  background: linear-gradient(135deg, $green, $greenDark);
  padding: 100rpx 32rpx 36rpx;
  box-shadow: 0 8rpx 32rpx rgba(7, 193, 96, 0.2);
}

.header-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12rpx;
}

.back-row {
  display: flex;
  align-items: center;
  min-width: 120rpx;
}

.back-arrow {
  font-size: 48rpx;
  color: $textPrimary;
  margin-right: 4rpx;
  font-weight: 300;
  line-height: 1;
}

.back-text {
  font-size: 28rpx;
  color: $textPrimary;
}

.nav-title {
  font-size: 36rpx;
  font-weight: 700;
  color: $textPrimary;
  text-align: center;
  flex: 1;
}

.nav-right {
  min-width: 120rpx;
}

.header-sub {
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.9);
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
  padding-bottom: 120rpx;
}

// ============================================================
// Core Stats Card
// ============================================================
.stats-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 28rpx 24rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.card-title {
  font-size: 30rpx;
  font-weight: 500;
  color: $textPrimary;
  display: block;
  margin-bottom: 24rpx;
}

.stats-row {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 16rpx;
  margin-bottom: 16rpx;

  &:last-child {
    margin-bottom: 0;
  }
}

.stat-cell {
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.stat-icon-box {
  width: 80rpx;
  height: 80rpx;
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 8rpx;
  box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.2);
}

.orange-red { background: linear-gradient(135deg, #fb923c, #ef4444); }
.blue { background: linear-gradient(135deg, #60a5fa, #3b82f6); }
.yellow-orange { background: linear-gradient(135deg, #facc15, #f97316); }
.purple { background: linear-gradient(135deg, #a78bfa, #7c3aed); }
.pink-red { background: linear-gradient(135deg, #f472b6, #ef4444); }
.green-teal { background: linear-gradient(135deg, #4ade80, #14b8a6); }

.stat-icon {
  font-size: 36rpx;
}

.stat-sub-label {
  font-size: 22rpx;
  color: $textSecondary;
  margin-bottom: 4rpx;
}

.stat-big-value {
  font-size: 36rpx;
  font-weight: 700;
  color: $textPrimary;
  line-height: 1.1;
}

.stat-tiny-unit {
  font-size: 20rpx;
  color: $textMuted;
  margin-top: 2rpx;
}

// ============================================================
// Chart Card
// ============================================================
.chart-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 28rpx 32rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.chart-header {
  display: flex;
  align-items: center;
  margin-bottom: 24rpx;
}

.chart-header-icon {
  font-size: 32rpx;
  margin-right: 12rpx;
}

.chart-header-title {
  font-size: 30rpx;
  font-weight: 500;
  color: $textPrimary;
}

.chart-card-title {
  font-size: 30rpx;
  font-weight: 500;
  color: $textPrimary;
  display: block;
  margin-bottom: 24rpx;
}

// ============================================================
// Heart Rate Bar Chart Placeholder
// ============================================================
.hr-chart-placeholder {
  padding: 0;
}

.hr-bar-row {
  display: flex;
  align-items: flex-end;
  height: 280rpx;
  gap: 12rpx;
  padding: 0 8rpx;
}

.hr-bar-col {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  height: 100%;
  justify-content: flex-end;
}

.hr-bar {
  width: 100%;
  background: linear-gradient(180deg, $green, $greenDark);
  border-radius: 8rpx 8rpx 0 0;
  min-height: 8rpx;
}

.hr-bar-label {
  font-size: 20rpx;
  color: $textMuted;
  margin-top: 8rpx;
}

.hr-chart-info {
  margin-top: 16rpx;
  text-align: center;
}

.hr-chart-info-text {
  font-size: 24rpx;
  color: $textSecondary;
}

// ============================================================
// Radar as Bar Chart
// ============================================================
.radar-placeholder {
  padding: 0;
}

.radar-grid {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
}

.radar-item {
  display: flex;
  align-items: center;
  gap: 16rpx;
}

.radar-label {
  font-size: 24rpx;
  color: $textSecondary;
  width: 80rpx;
  flex-shrink: 0;
}

.radar-bar-track {
  flex: 1;
  height: 16rpx;
  background: #2a2a2a;
  border-radius: 8rpx;
  overflow: hidden;
}

.radar-bar-fill {
  height: 100%;
  background: linear-gradient(90deg, $green, $greenDark);
  border-radius: 8rpx;
  transition: width 0.5s;
}

.radar-bar-value {
  font-size: 24rpx;
  font-weight: 600;
  color: $textPrimary;
  width: 60rpx;
  text-align: right;
}

// ============================================================
// Heat Map
// ============================================================
.heatmap-box {
  aspect-ratio: 4/3;
  border-radius: 20rpx;
  position: relative;
  overflow: hidden;
  border: $border;
  background: linear-gradient(135deg, #0a2a0f, #2a2a0a, #2a0a0a);
}

.field-outline {
  position: absolute;
  top: 24rpx;
  left: 24rpx;
  right: 24rpx;
  bottom: 24rpx;
  border: 2rpx solid rgba(255, 255, 255, 0.15);
}

.field-center-line {
  position: absolute;
  top: 50%;
  left: 0;
  right: 0;
  height: 1rpx;
  background: rgba(255, 255, 255, 0.15);
}

.field-center-circle {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 100rpx;
  height: 100rpx;
  border: 2rpx solid rgba(255, 255, 255, 0.15);
  border-radius: 50%;
  transform: translate(-50%, -50%);
}

.heat-point {
  position: absolute;
  border-radius: 50%;
  filter: blur(20rpx);
}

.heat-1 {
  top: 30%;
  left: 22%;
  width: 120rpx;
  height: 120rpx;
  background: rgba(239, 68, 68, 0.5);
}

.heat-2 {
  top: 45%;
  left: 45%;
  width: 160rpx;
  height: 160rpx;
  background: rgba(249, 115, 22, 0.5);
}

.heat-3 {
  top: 60%;
  right: 22%;
  width: 120rpx;
  height: 120rpx;
  background: rgba(234, 179, 8, 0.5);
}

.heatmap-legend {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 16rpx;
  padding: 0 8rpx;
}

.legend-text {
  font-size: 22rpx;
  color: $textMuted;
}

.legend-bar {
  flex: 1;
  height: 12rpx;
  margin: 0 24rpx;
  background: linear-gradient(90deg, #16a34a, #eab308, #ef4444);
  border-radius: 6rpx;
}

// ============================================================
// Slack Index
// ============================================================
.slack-content {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.slack-bar-track {
  width: 100%;
  height: 16rpx;
  background: #2a2a2a;
  border-radius: 8rpx;
  overflow: hidden;
}

.slack-bar-fill {
  height: 100%;
  background: linear-gradient(90deg, #FFA502, #FF6348);
  border-radius: 8rpx;
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

.slack-label-text {
  font-size: 24rpx;
  color: $textSecondary;
}

// ============================================================
// Performance Score
// ============================================================
.score-content {
  display: flex;
  justify-content: center;
  padding: 16rpx 0 8rpx;
}

.score-value {
  font-size: 80rpx;
  font-weight: 700;
  color: $green;
}
</style>
