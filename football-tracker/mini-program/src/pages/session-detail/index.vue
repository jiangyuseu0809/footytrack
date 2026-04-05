<template>
  <view class="page">
    <!-- Header -->
    <view class="header" :style="{ paddingTop: statusBarHeight + 'px' }">
      <view class="header-nav" :style="{ height: navBarHeight + 'px' }">
        <view class="nav-capsule" :style="{ height: capsuleHeight + 'px', borderRadius: capsuleHeight / 2 + 'px' }">
          <view class="capsule-btn" @tap="goBack">
            <text class="capsule-icon capsule-icon-back">＜</text>
          </view>
          <view class="capsule-divider" />
          <view class="capsule-btn" @tap="goHome">
            <image class="capsule-home-img" src="/static/icon-home-white.png" mode="aspectFit" />
          </view>
        </view>
        <text class="nav-title">{{ matchName }}</text>
        <view class="nav-right" />
      </view>
    </view>

    <scroll-view v-if="session" scroll-y class="scroll-area">
      <!-- Core Stats -->
      <view class="section">
        <view class="core-panel">
          <text class="core-panel-title">核心数据</text>
          <view class="core-grid">
            <view class="core-item" :class="'core-item--' + getSessionLevel('calories', Math.round(session.caloriesBurned || 0))">
              <text class="core-item-value">{{ Math.round(session.caloriesBurned || 0) }}</text>
              <text class="core-item-label">热量(kcal)</text>
            </view>
            <view class="core-item" :class="'core-item--' + getSessionLevel('distance', distanceKm)">
              <text class="core-item-value">{{ distanceKm }}</text>
              <text class="core-item-label">距离(km)</text>
            </view>
            <view class="core-item" :class="'core-item--' + getSessionLevel('sprints', session.sprintCount || 0)">
              <text class="core-item-value">{{ session.sprintCount || 0 }}</text>
              <text class="core-item-label">冲刺次数</text>
            </view>
            <view class="core-item" :class="'core-item--' + getSessionLevel('duration', durationMin)">
              <text class="core-item-value">{{ durationMin }}</text>
              <text class="core-item-label">时长(分钟)</text>
            </view>
            <view class="core-item" :class="'core-item--' + getSessionLevel('maxHeartRate', session.maxHeartRate || 0)">
              <text class="core-item-value">{{ session.maxHeartRate || '-' }}</text>
              <text class="core-item-label">最高心率</text>
            </view>
            <view class="core-item" :class="'core-item--' + getSessionLevel('avgHeartRate', session.avgHeartRate || 0)">
              <text class="core-item-value">{{ session.avgHeartRate || '-' }}</text>
              <text class="core-item-label">平均心率</text>
            </view>
            <view class="core-item" :class="'core-item--' + getSessionLevel('maxSpeed', session.maxSpeedKmh || 0)">
              <text class="core-item-value">{{ (session.maxSpeedKmh || 0).toFixed(1) }}</text>
              <text class="core-item-label">最高时速</text>
            </view>
            <view class="core-item" :class="'core-item--' + getSessionLevel('avgSpeed', session.avgSpeedKmh || 0)">
              <text class="core-item-value">{{ (session.avgSpeedKmh || 0).toFixed(1) }}</text>
              <text class="core-item-label">平均时速</text>
            </view>
            <view class="core-item" :class="'core-item--' + getSessionLevel('score', score)">
              <text class="core-item-value">{{ score.toFixed(1) }}</text>
              <text class="core-item-label">综合评分</text>
            </view>
          </view>
          <view class="core-legend">
            <view class="core-legend-item">
              <view class="core-legend-dot core-legend-dot--good" />
              <text class="core-legend-text">出色</text>
            </view>
            <view class="core-legend-item">
              <view class="core-legend-dot core-legend-dot--normal" />
              <text class="core-legend-text">一般</text>
            </view>
            <view class="core-legend-item">
              <view class="core-legend-dot core-legend-dot--low" />
              <text class="core-legend-text">待提升</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Heart Rate Smooth Curve -->
      <view v-if="session.avgHeartRate" class="section">
        <view class="chart-card">
          <text class="chart-card-title">心率变化曲线</text>
          <view class="curve-chart-wrap">
            <image v-if="hrCurveImage" :src="hrCurveImage" class="curve-chart-img" mode="aspectFit" />
            <view v-else class="curve-placeholder">
              <text class="curve-placeholder-text">加载中...</text>
            </view>
          </view>
          <view class="curve-info">
            <text class="curve-info-text">平均 {{ session.avgHeartRate }} bpm · 最高 {{ session.maxHeartRate }} bpm</text>
          </view>
        </view>
      </view>

      <!-- Speed Smooth Curve -->
      <view v-if="session.avgSpeedKmh" class="section">
        <view class="chart-card">
          <text class="chart-card-title">速度变化曲线</text>
          <view class="curve-chart-wrap">
            <image v-if="speedCurveImage" :src="speedCurveImage" class="curve-chart-img" mode="aspectFit" />
            <view v-else class="curve-placeholder">
              <text class="curve-placeholder-text">加载中...</text>
            </view>
          </view>
          <view class="curve-info">
            <text class="curve-info-text">平均 {{ (session.avgSpeedKmh || 0).toFixed(1) }} km/h · 最高 {{ (session.maxSpeedKmh || 0).toFixed(1) }} km/h</text>
          </view>
        </view>
      </view>

      <!-- Ability Spider Chart -->
      <view class="section">
        <view class="chart-card">
          <text class="chart-card-title">能力分析图</text>
          <view class="radar-canvas-wrap">
            <image v-if="radarImage" :src="radarImage" class="radar-image" mode="aspectFit" />
            <view v-else class="radar-placeholder">
              <text class="radar-placeholder-text">加载中...</text>
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
            <image v-if="heatmapImage" :src="heatmapImage" class="heatmap-image" mode="aspectFill" />
            <view v-else class="heat-point heat-1" />
            <view v-if="!heatmapImage" class="heat-point heat-2" />
            <view v-if="!heatmapImage" class="heat-point heat-3" />
          </view>
          <view class="heatmap-legend">
            <text class="legend-text">低活跃度</text>
            <view class="legend-bar" />
            <text class="legend-text">高活跃度</text>
          </view>
        </view>
      </view>

      <!-- Slack Index -->
      <view v-if="session.slackIndex != null" class="section section--last">
        <view class="chart-card">
          <text class="chart-card-title">摸鱼指数</text>
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
    </scroll-view>

    <!-- Offscreen canvases -->
    <canvas canvas-id="hrCurveCanvas" id="hrCurveCanvas" class="offscreen-canvas offscreen-canvas--curve" />
    <canvas canvas-id="speedCurveCanvas" id="speedCurveCanvas" class="offscreen-canvas offscreen-canvas--curve" />
    <canvas canvas-id="sessionRadarCanvas" id="sessionRadarCanvas" class="offscreen-canvas" />
    <canvas canvas-id="sessionHeatmap" id="sessionHeatmap" class="offscreen-canvas offscreen-canvas--heatmap" />
  </view>
</template>

<script setup lang="ts">
import { ref, computed, nextTick } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { getSessions, type SessionDto } from '../../utils/api'
import { formatDistance, formatDateTime, formatDuration, computePerformanceScore } from '../../utils/format'
import { computeAbilityData, parseTrackPoints, drawRadarChart, drawHeatmapChart, drawSmoothCurveChart, type CurvePoint } from '../../utils/charts'

const session = ref<SessionDto | null>(null)
const hrCurveImage = ref('')
const speedCurveImage = ref('')
const radarImage = ref('')
const heatmapImage = ref('')

const menuBtn = uni.getMenuButtonBoundingClientRect()
const sysInfo = uni.getSystemInfoSync()
const statusBarHeight = sysInfo.statusBarHeight || 44
const capsuleHeight = menuBtn.height
const navBarHeight = (menuBtn.top - statusBarHeight) * 2 + menuBtn.height

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

function getSessionLevel(metric: string, value: number | string): string {
  const v = typeof value === 'string' ? parseFloat(value) : value
  if (!v) return 'low'
  const thresholds: Record<string, [number, number]> = {
    calories:     [300, 100],
    distance:     [3, 1],
    sprints:      [8, 3],
    duration:     [45, 15],
    maxHeartRate: [170, 140],
    avgHeartRate: [140, 110],
    maxSpeed:     [20, 12],
    avgSpeed:     [8, 4],
    score:        [8, 6.5],
  }
  const [good, normal] = thresholds[metric] || [1, 0]
  if (v >= good) return 'good'
  if (v >= normal) return 'normal'
  return 'low'
}

function generateHRCurvePoints(s: SessionDto): CurvePoint[] {
  const avg = s.avgHeartRate || 120
  const max = s.maxHeartRate || 150
  const dur = Math.round((s.endTime - s.startTime) / 60000)
  const step = Math.max(Math.round(dur / 6), 5)
  return [
    { label: '开始', value: Math.round(avg * 0.6) },
    { label: `${step}'`, value: Math.round(avg * 0.85) },
    { label: `${step * 2}'`, value: avg },
    { label: `${step * 3}'`, value: Math.round((avg + max) / 2) },
    { label: `${step * 4}'`, value: Math.round(avg * 1.05) },
    { label: `${step * 5}'`, value: max },
    { label: '结束', value: Math.round(avg * 0.65) },
  ]
}

function generateSpeedCurvePoints(s: SessionDto): CurvePoint[] {
  const avg = s.avgSpeedKmh || 6
  const max = s.maxSpeedKmh || 12
  const dur = Math.round((s.endTime - s.startTime) / 60000)
  const step = Math.max(Math.round(dur / 6), 5)
  return [
    { label: '开始', value: Math.round(avg * 0.4 * 10) / 10 },
    { label: `${step}'`, value: Math.round(avg * 0.8 * 10) / 10 },
    { label: `${step * 2}'`, value: Math.round(avg * 1.1 * 10) / 10 },
    { label: `${step * 3}'`, value: Math.round(max * 0.85 * 10) / 10 },
    { label: `${step * 4}'`, value: max },
    { label: `${step * 5}'`, value: Math.round(avg * 0.9 * 10) / 10 },
    { label: '结束', value: Math.round(avg * 0.3 * 10) / 10 },
  ]
}

function drawCharts() {
  const s = session.value
  if (!s) return

  nextTick(() => {
    // Heart rate curve
    if (s.avgHeartRate) {
      const hrPoints = generateHRCurvePoints(s)
      setTimeout(() => {
        drawSmoothCurveChart('hrCurveCanvas', hrPoints, {
          color: '#ef4444',
          gradientFrom: 'rgba(239,68,68,0.3)',
          gradientTo: 'rgba(239,68,68,0.02)',
        }, (path) => { hrCurveImage.value = path })
      }, 200)
    }

    // Speed curve
    if (s.avgSpeedKmh) {
      const speedPoints = generateSpeedCurvePoints(s)
      setTimeout(() => {
        drawSmoothCurveChart('speedCurveCanvas', speedPoints, {
          color: '#3b82f6',
          gradientFrom: 'rgba(59,130,246,0.3)',
          gradientTo: 'rgba(59,130,246,0.02)',
        }, (path) => { speedCurveImage.value = path })
      }, 350)
    }

    // Radar chart
    const ability = computeAbilityData([s])
    setTimeout(() => {
      drawRadarChart('sessionRadarCanvas', ability, (path) => { radarImage.value = path })
    }, 500)

    // Heatmap
    const pts = parseTrackPoints([s])
    if (pts.length > 0) {
      setTimeout(() => {
        drawHeatmapChart('sessionHeatmap', pts, (path) => { heatmapImage.value = path })
      }, 650)
    }
  })
}

function goBack() { uni.navigateBack() }
function goHome() { uni.switchTab({ url: '/pages/home/index' }) }

onLoad(async (options) => {
  const id = options?.id
  if (!id) return
  try {
    const res = await getSessions()
    session.value = res.sessions.find(s => s.id === id) || null
    drawCharts()
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
  background: $cardBg;
  padding-left: 16rpx;
  padding-right: 16rpx;
  padding-bottom: 16rpx;
  border-bottom: $border;
}

.header-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.nav-capsule {
  display: flex;
  align-items: center;
  background: rgba(255, 255, 255, 0.08);
  border: 1rpx solid rgba(255, 255, 255, 0.15);
  overflow: hidden;
}

.capsule-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 68rpx;
  height: 100%;
}

.capsule-icon {
  color: $textPrimary;
  line-height: 1;
}

.capsule-icon-back {
  font-size: 30rpx;
  font-weight: 300;
}

.capsule-home-img {
  width: 32rpx;
  height: 32rpx;
}

.capsule-divider {
  width: 1rpx;
  height: 50%;
  background: rgba(255, 255, 255, 0.2);
}

.nav-title {
  font-size: 34rpx;
  font-weight: 600;
  color: $textPrimary;
  text-align: center;
  flex: 1;
}

.nav-right {
  width: 136rpx;
  flex-shrink: 0;
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
// Core Stats Panel
// ============================================================
.core-panel {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 28rpx 24rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.core-panel-title {
  font-size: 30rpx;
  font-weight: 600;
  color: $textPrimary;
  display: block;
  margin-bottom: 24rpx;
  padding-left: 4rpx;
}

.core-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 16rpx;
}

.core-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 16rpx 8rpx;
  border-radius: 16rpx;
  background: rgba(255, 255, 255, 0.04);
}

.core-item--good {
  background: rgba(7, 193, 96, 0.15);
}

.core-item--normal {
  background: rgba(250, 204, 21, 0.12);
}

.core-item--low {
  background: rgba(239, 68, 68, 0.12);
}

.core-item-value {
  font-size: 38rpx;
  font-weight: 700;
  color: $textPrimary;
  line-height: 1.1;
}

.core-item-label {
  font-size: 22rpx;
  color: $textMuted;
  margin-top: 6rpx;
}

.core-legend {
  display: flex;
  justify-content: center;
  gap: 32rpx;
  margin-top: 20rpx;
  padding-top: 16rpx;
  border-top: 1rpx solid #2a2a2a;
}

.core-legend-item {
  display: flex;
  align-items: center;
  gap: 8rpx;
}

.core-legend-dot {
  width: 16rpx;
  height: 16rpx;
  border-radius: 4rpx;
}

.core-legend-dot--good {
  background: rgba(7, 193, 96, 0.5);
}

.core-legend-dot--normal {
  background: rgba(250, 204, 21, 0.4);
}

.core-legend-dot--low {
  background: rgba(239, 68, 68, 0.4);
}

.core-legend-text {
  font-size: 22rpx;
  color: $textMuted;
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
// Smooth Curve Chart
// ============================================================
.curve-chart-wrap {
  border-radius: 16rpx;
  overflow: hidden;
  background: rgba(255, 255, 255, 0.02);
}

.curve-chart-img {
  width: 100%;
  height: 300rpx;
}

.curve-placeholder {
  width: 100%;
  height: 300rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.curve-placeholder-text {
  font-size: 24rpx;
  color: $textMuted;
}

.curve-info {
  margin-top: 16rpx;
  text-align: center;
}

.curve-info-text {
  font-size: 24rpx;
  color: $textSecondary;
}

// ============================================================
// Radar (Spider) Chart
// ============================================================
.radar-canvas-wrap {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 360rpx;
}

.radar-image {
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

.heatmap-image {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: 0;
}

.field-outline {
  position: absolute;
  top: 24rpx;
  left: 24rpx;
  right: 24rpx;
  bottom: 24rpx;
  border: 2rpx solid rgba(255, 255, 255, 0.15);
  z-index: 1;
}

.field-center-line {
  position: absolute;
  left: 50%;
  top: 0;
  bottom: 0;
  width: 1rpx;
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
// Offscreen Canvas
// ============================================================
.offscreen-canvas {
  position: fixed;
  left: -9999px;
  top: -9999px;
  width: 280px;
  height: 280px;
}

.offscreen-canvas--curve {
  width: 350px;
  height: 200px;
}

.offscreen-canvas--heatmap {
  width: 350px;
  height: 263px;
}
</style>
