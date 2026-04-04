<template>
  <view class="page">
    <!-- Header -->
    <view class="header">
      <text class="header-title">FootyTrack</text>
      <view v-if="isWatchConnected" class="watch-badge connected">
        <text class="watch-badge-text">⌚ 已连接</text>
      </view>
      <view v-else class="watch-badge disconnected" @tap="goBindWatch">
        <text class="watch-badge-text">⌚ 连接手表</text>
      </view>
    </view>

    <scroll-view scroll-y class="scroll-content">
      <!-- Upcoming Matches -->
      <view v-if="visibleMatches.length" class="section">
        <view class="upcoming-list">
          <view
            v-for="m in visibleMatches"
            :key="m.id"
            class="upcoming-card"
            @tap="goMatchDetail(m.id)"
          >
            <view class="upcoming-card-top">
              <text class="upcoming-name">{{ m.title }}</text>
              <view class="match-status-tag" :class="'match-status--' + getMatchStatus(m.matchDate).type">
                <text class="match-status-tag-text">{{ getMatchStatus(m.matchDate).label }}</text>
              </view>
              <text class="upcoming-arrow">›</text>
            </view>
            <view class="upcoming-info-rows">
              <view class="upcoming-info-row">
                <text class="upcoming-info-icon">📍</text>
                <text class="upcoming-info-text">{{ m.location }}</text>
              </view>
              <view class="upcoming-info-row">
                <text class="upcoming-info-icon">📅</text>
                <text class="upcoming-info-text">{{ formatMatchTime(m.matchDate) }}</text>
              </view>
              <view class="upcoming-info-row">
                <text class="upcoming-info-icon">👥</text>
                <text class="upcoming-info-text">{{ m.registrationCount }}/{{ m.maxPlayers || m.groups * m.playersPerGroup }} 人已报名</text>
              </view>
            </view>
          </view>
        </view>
      </view>

      <!-- Time Range Toggle -->
      <view class="section">
        <view class="toggle-bar">
          <view
            class="toggle-item"
            :class="{ active: timeRange === 'week' }"
            @tap="timeRange = 'week'"
          >
            <text class="toggle-text" :class="{ active: timeRange === 'week' }">本周数据</text>
          </view>
          <view
            class="toggle-item"
            :class="{ active: timeRange === 'today' }"
            @tap="timeRange = 'today'"
          >
            <text class="toggle-text" :class="{ active: timeRange === 'today' }">今日数据</text>
          </view>
        </view>
      </view>

      <!-- Matches Count -->
      <view class="section">
        <view class="match-count-card">
          <view class="match-count-left">
            <text class="match-count-label">{{ timeRange === 'week' ? '本周' : '今日' }}踢球次数</text>
            <text class="match-count-value">{{ currentStats.matches }}</text>
          </view>
          <view class="match-count-icon">
            <text class="match-count-weekday">{{ todayWeekday }}</text>
            <text class="match-count-date">{{ todayDate }}</text>
          </view>
        </view>
      </view>

      <!-- Core Stats Grid -->
      <view class="section">
        <view class="stats-grid">
          <view class="stats-card">
            <view class="stats-icon-box orange-red">
              <text class="stats-icon">🔥</text>
            </view>
            <text class="stats-label">热量消耗</text>
            <text class="stats-value">{{ currentStats.calories }}</text>
            <text class="stats-unit">kcal</text>
          </view>
          <view class="stats-card">
            <view class="stats-icon-box blue">
              <text class="stats-icon">📍</text>
            </view>
            <text class="stats-label">跑动距离</text>
            <text class="stats-value">{{ currentStats.distance }}</text>
            <text class="stats-unit">km</text>
          </view>
          <view class="stats-card">
            <view class="stats-icon-box yellow-orange">
              <text class="stats-icon">⚡</text>
            </view>
            <text class="stats-label">冲刺次数</text>
            <text class="stats-value">{{ currentStats.sprints }}</text>
            <text class="stats-unit">次</text>
          </view>
          <view class="stats-card">
            <view class="stats-icon-box purple">
              <text class="stats-icon">⏱️</text>
            </view>
            <text class="stats-label">运动时间</text>
            <text class="stats-value">{{ currentStats.duration }}</text>
            <text class="stats-unit">分钟</text>
          </view>
          <view class="stats-card">
            <view class="stats-icon-box pink-red">
              <text class="stats-icon">❤️</text>
            </view>
            <text class="stats-label">最高心率</text>
            <text class="stats-value">{{ currentStats.maxHeartRate }}</text>
            <text class="stats-unit">bpm</text>
          </view>
          <view class="stats-card">
            <view class="stats-icon-box green-teal">
              <text class="stats-icon">❤️</text>
            </view>
            <text class="stats-label">平均心率</text>
            <text class="stats-value">{{ currentStats.avgHeartRate }}</text>
            <text class="stats-unit">bpm</text>
          </view>
        </view>
      </view>

      <!-- Ability Radar Placeholder -->
      <view class="section">
        <view class="chart-card">
          <view class="chart-header">
            <text class="chart-header-icon">🎯</text>
            <text class="chart-header-title">{{ timeRange === 'week' ? '本周能力分析' : '今日能力分析' }}</text>
          </view>
          <view class="radar-canvas-wrap">
            <image v-if="radarImage" :src="radarImage" class="radar-image" mode="aspectFit" />
          </view>
        </view>
      </view>

      <!-- Heat Map (today only) -->
      <view v-if="timeRange === 'today'" class="section">
        <view class="chart-card">
          <text class="chart-card-title">今日跑动热力图</text>
          <view class="heatmap-box">
            <view class="field-outline">
              <view class="field-center-line" />
              <view class="field-center-circle" />
            </view>
            <image v-if="heatmapImage" :src="heatmapImage" class="heatmap-image" mode="aspectFill" />
          </view>
          <view class="heatmap-legend">
            <text class="legend-text">低活跃度</text>
            <view class="legend-bar" />
            <text class="legend-text">高活跃度</text>
          </view>
        </view>
      </view>

      <!-- Share Button -->
      <view class="section section--last">
        <view class="share-btn" @tap="handleShare">
          <view class="share-btn-icon">
            <image src="/static/icons/share.svg" class="share-btn-svg" />
          </view>
          <text class="share-btn-text">分享{{ timeRange === 'week' ? '本周' : '今日' }}踢球数据</text>
        </view>
      </view>
    </scroll-view>

    <!-- Share Dialog (Bottom Sheet) -->
    <view v-if="showSharePopup" class="share-overlay" @tap="showSharePopup = false">
      <view class="share-sheet" @tap.stop>
        <!-- Sheet Header -->
        <view class="share-sheet-header">
          <text class="share-sheet-title">分享运动数据</text>
          <view class="share-sheet-close" @tap="showSharePopup = false">
            <text class="share-sheet-close-text">✕</text>
          </view>
        </view>

        <!-- Share Card Preview -->
        <scroll-view scroll-y class="share-card-scroll">
          <view class="share-card-preview">
            <image v-if="shareImage" :src="shareImage" class="share-card-image" mode="widthFix" />
          </view>
        </scroll-view>

        <!-- Share Actions -->
        <view class="share-actions">
          <view class="share-action-btn-primary" @tap="saveShareImage">
            <text class="share-action-btn-text">{{ shareSuccess ? '✓ 已保存到相册' : '保存到相册' }}</text>
          </view>
          <text class="share-action-hint">分享给好友，一起记录运动数据</text>
        </view>
      </view>
    </view>

    <!-- Hidden canvas for radar chart rendering -->
    <canvas canvas-id="radarCanvas" id="radarCanvas" class="offscreen-canvas" />
    <canvas canvas-id="heatmapCanvas" id="heatmapCanvas" class="offscreen-canvas offscreen-canvas--heatmap" />
    <canvas canvas-id="shareCanvas" id="shareCanvas" class="offscreen-canvas" :style="{ width: '375px', height: shareCanvasHeight + 'px' }" />
  </view>
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { getSessions, getMatches, isLoggedIn, type SessionDto, type Match } from '../../utils/api'
import { formatDateTime, formatWeekday } from '../../utils/format'

const timeRange = ref<'week' | 'today'>('week')
const sessions = ref<SessionDto[]>([])
const upcomingMatches = ref<Match[]>([])
const isWatchConnected = ref(false)
const radarImage = ref('')
const heatmapImage = ref('')
const showSharePopup = ref(false)
const shareImage = ref('')
const shareSuccess = ref(false)
const shareCanvasHeight = ref(960)

const weekSessions = computed(() => {
  const now = new Date()
  const weekStart = new Date(now)
  weekStart.setDate(now.getDate() - now.getDay())
  weekStart.setHours(0, 0, 0, 0)
  return sessions.value.filter(s => s.startTime >= weekStart.getTime())
})

const todaySessions = computed(() => {
  const now = new Date()
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  return sessions.value.filter(s => s.startTime >= todayStart)
})

const currentStats = computed(() => {
  const list = timeRange.value === 'week' ? weekSessions.value : todaySessions.value
  const totalDistance = list.reduce((sum, s) => sum + (s.totalDistanceMeters || 0), 0)
  const totalCalories = Math.round(list.reduce((sum, s) => sum + (s.caloriesBurned || 0), 0))
  const totalSprints = list.reduce((sum, s) => sum + (s.sprintCount || 0), 0)
  const totalDuration = Math.round(list.reduce((sum, s) => sum + ((s.endTime - s.startTime) / 60000), 0))
  const maxHR = list.length ? Math.max(...list.map(s => s.maxHeartRate || 0)) : 0
  const avgHR = list.length ? Math.round(list.reduce((sum, s) => sum + (s.avgHeartRate || 0), 0) / list.length) : 0
  return {
    matches: list.length,
    calories: totalCalories,
    distance: (totalDistance / 1000).toFixed(1),
    sprints: totalSprints,
    duration: totalDuration,
    maxHeartRate: maxHR,
    avgHeartRate: avgHR,
  }
})

// Today date display
const todayDate = computed(() => new Date().getDate())
const todayWeekday = computed(() => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][new Date().getMonth()])

const abilityData = computed(() => {
  const list = timeRange.value === 'week' ? weekSessions.value : todaySessions.value
  if (list.length === 0) {
    return [
      { ability: '速度', value: 0 },
      { ability: '耐力', value: 0 },
      { ability: '爆发力', value: 0 },
      { ability: '灵活性', value: 0 },
      { ability: '体能', value: 0 },
      { ability: '持久力', value: 0 },
    ]
  }
  const avgSpeed = list.reduce((s, v) => s + (v.avgSpeedKmh || 0), 0) / list.length
  const maxSpeed = Math.max(...list.map(s => s.maxSpeedKmh || 0))
  const avgDist = list.reduce((s, v) => s + (v.totalDistanceMeters || 0), 0) / list.length / 1000
  const totalSprints = list.reduce((s, v) => s + (v.sprintCount || 0), 0)
  return [
    { ability: '速度', value: Math.min(100, Math.round(maxSpeed * 4)) },
    { ability: '耐力', value: Math.min(100, Math.round(avgDist * 15)) },
    { ability: '爆发力', value: Math.min(100, Math.round(totalSprints * 5)) },
    { ability: '灵活性', value: Math.min(100, Math.round(avgSpeed * 8)) },
    { ability: '体能', value: Math.min(100, Math.round((avgDist + avgSpeed) * 6)) },
    { ability: '持久力', value: Math.min(100, Math.round(avgDist * 12)) },
  ]
})

async function loadData() {
  if (!isLoggedIn()) return
  try {
    const [sessRes, matchRes] = await Promise.all([getSessions(), getMatches()])
    sessions.value = sessRes.sessions
    upcomingMatches.value = matchRes.matches
  } catch (e) {
    console.error('Failed to load home data', e)
  }
}

function getMatchStatus(matchDate: number): { type: string; label: string } {
  const now = Date.now()
  const diff = now - matchDate
  if (diff < 0) return { type: 'upcoming', label: '即将开赛' }
  if (diff < 2 * 3600 * 1000) return { type: 'live', label: '进行中' }
  return { type: 'finished', label: '比赛完结' }
}

const visibleMatches = computed(() => {
  const now = Date.now()
  const twelveHours = 12 * 3600 * 1000
  return upcomingMatches.value.filter(m => now - m.matchDate < twelveHours)
})

function formatMatchTime(ts: number): string {
  return `${formatWeekday(ts)} ${formatDateTime(ts)}`
}

function goMatchDetail(id: string) {
  uni.navigateTo({ url: `/pages/match-detail/index?id=${id}` })
}

function goBindWatch() {
  uni.navigateTo({ url: '/pages/bind-watch/index' })
}

function handleShare() {
  uni.showLoading({ title: '生成中...' })
  // Pre-calculate the same totalH as drawShareCard
  const canvasH = calcShareCardHeight()
  shareCanvasHeight.value = canvasH
  nextTick(() => {
    setTimeout(() => {
      drawShareCard(() => {
        uni.canvasToTempFilePath({
          canvasId: 'shareCanvas',
          width: 375,
          height: canvasH,
          destWidth: 750,
          destHeight: canvasH * 2,
          success: (res) => {
            uni.hideLoading()
            shareImage.value = res.tempFilePath
            showSharePopup.value = true
          },
          fail: () => {
            uni.hideLoading()
            uni.showToast({ title: '生成失败', icon: 'none' })
          },
        })
      })
    }, 100)
  })
}

function calcShareCardHeight(): number {
  const pad = 24
  const contentW = 375 - pad * 2
  const gap = 20 // uniform gap between all sections
  let yOffset = 200 // hero

  // Stats: 2 rows
  const statsTop = yOffset + gap
  const statCellH = 90
  const statsH = statCellH * 2 + 18
  yOffset = statsTop + statsH + gap

  // Heart rate (today)
  if (timeRange.value === 'today') {
    yOffset += 180 + gap
  }

  // Radar
  const radarCardH = 32 + 100 + 70 + 30 // title + space + radarR + bottom padding
  yOffset += radarCardH + gap

  // Heatmap (today)
  if (timeRange.value === 'today') {
    const hmH = Math.round(contentW * 3 / 4)
    yOffset += hmH + 40 + gap // hmH + title area + gap
  }

  // Footer
  yOffset += 48 + gap

  return yOffset
}

function saveShareImage() {
  if (!shareImage.value || shareSuccess.value) return
  uni.saveImageToPhotosAlbum({
    filePath: shareImage.value,
    success: () => {
      shareSuccess.value = true
      setTimeout(() => {
        shareSuccess.value = false
        showSharePopup.value = false
      }, 1500)
    },
    fail: () => {
      uni.showToast({ title: '保存失败', icon: 'none' })
    },
  })
}

function drawShareCard(callback: () => void) {
  const ctx = uni.createCanvasContext('shareCanvas')
  const W = 375
  const pad = 24
  const contentW = W - pad * 2
  const green = '#07c160'
  const cardRadius = 12
  const gap = 20 // uniform gap between all sections

  // We'll compute total height dynamically
  let yOffset = 0

  // --- Hero Section ---
  const heroH = 200
  yOffset = heroH

  // --- Stats Section ---
  const statsTop = yOffset + gap
  const statCellW = Math.floor((contentW - 12) / 3)  // 3 cols, 6px gap each
  const statCellH = 90
  const statsH = statCellH * 2 + 18  // 2 rows + gap
  yOffset = statsTop + statsH + gap

  // --- Heart Rate chart (today only) ---
  let heartRateTop = 0
  const showHeartRate = timeRange.value === 'today'
  if (showHeartRate) {
    heartRateTop = yOffset
    yOffset += 180 + gap // chart area + gap
  }

  // --- Radar Section ---
  const radarSectionTop = yOffset
  const radarCardH = 32 + 100 + 70 + 30 // title + space + radarR + bottom padding
  const radarCenterY = radarSectionTop + 32 + 100
  const radarR = 70
  yOffset = radarSectionTop + radarCardH + gap

  // --- Heatmap Section (today only) ---
  let hmSectionTop = 0
  const showHeatmap = timeRange.value === 'today'
  if (showHeatmap) {
    hmSectionTop = yOffset
    const hmH = Math.round(contentW * 3 / 4)
    yOffset = hmSectionTop + hmH + 40 + gap // hmH + title area + gap
  }

  // --- Footer ---
  const footerTop = yOffset
  yOffset = footerTop + 48

  const totalH = yOffset + gap

  // Now draw everything
  // Background
  ctx.setFillStyle('#000000')
  ctx.fillRect(0, 0, W, totalH)

  // === Hero Section: background image with dark overlay ===
  // Draw hero background image first (will be loaded)
  try {
    ctx.drawImage('/static/share-hero-bg.png', 0, 0, W, heroH)
  } catch (e) {
    // fallback: dark fill
    ctx.setFillStyle('#111111')
    ctx.fillRect(0, 0, W, heroH)
  }

  // Heavy dark gradient overlay to simulate blur/darken effect
  const heroGrd = ctx.createLinearGradient(0, 0, 0, heroH)
  heroGrd.addColorStop(0, 'rgba(0,0,0,0.65)')
  heroGrd.addColorStop(0.4, 'rgba(0,0,0,0.7)')
  heroGrd.addColorStop(0.7, 'rgba(0,0,0,0.85)')
  heroGrd.addColorStop(1, 'rgba(0,0,0,1)')
  ctx.setFillStyle(heroGrd)
  ctx.fillRect(0, 0, W, heroH)

  // Header: "FootyTrack" + subtitle
  ctx.setFontSize(24)
  ctx.setTextAlign('left')
  ctx.setFillStyle('#FFFFFF')
  ctx.fillText('FootyTrack', pad, 50)

  const title = timeRange.value === 'week' ? '本周运动数据' : '今日运动数据'
  ctx.setFontSize(13)
  ctx.setFillStyle(green)
  ctx.fillText(title, pad, 72)

  // Green icon box (top right)
  const iconBoxSize = 48
  const iconBoxX = W - pad - iconBoxSize
  const iconBoxY = 30
  ctx.setFillStyle(green)
  roundRect(ctx, iconBoxX, iconBoxY, iconBoxSize, iconBoxSize, 14)
  ctx.fill()
  // Share icon (three dots connected by lines)
  const icx = iconBoxX + iconBoxSize / 2
  const icy = iconBoxY + iconBoxSize / 2
  ctx.setStrokeStyle('#FFFFFF')
  ctx.setFillStyle('#FFFFFF')
  ctx.setLineWidth(1.5)
  // Three dots
  const dots = [
    { x: icx + 8, y: icy - 10 },  // top-right
    { x: icx - 10, y: icy },       // middle-left
    { x: icx + 8, y: icy + 10 },   // bottom-right
  ]
  for (const d of dots) {
    ctx.beginPath()
    ctx.arc(d.x, d.y, 3, 0, Math.PI * 2)
    ctx.fill()
  }
  // Lines connecting dots
  ctx.beginPath()
  ctx.moveTo(dots[1].x, dots[1].y)
  ctx.lineTo(dots[0].x, dots[0].y)
  ctx.stroke()
  ctx.beginPath()
  ctx.moveTo(dots[1].x, dots[1].y)
  ctx.lineTo(dots[2].x, dots[2].y)
  ctx.stroke()

  // Date badge
  const now = new Date()
  const dateStr = `${now.getFullYear()}年${now.getMonth() + 1}月${now.getDate()}日`
  ctx.setFontSize(11)
  const dateW = ctx.measureText(dateStr).width + 24
  const dateBadgeX = pad
  const dateBadgeY = heroH - 40
  ctx.setFillStyle('rgba(255,255,255,0.1)')
  roundRect(ctx, dateBadgeX, dateBadgeY, dateW, 28, 14)
  ctx.fill()
  ctx.setStrokeStyle('rgba(255,255,255,0.2)')
  roundRect(ctx, dateBadgeX, dateBadgeY, dateW, 28, 14)
  ctx.stroke()
  ctx.setFontSize(11)
  ctx.setTextAlign('center')
  ctx.setFillStyle('#FFFFFF')
  ctx.fillText(dateStr, dateBadgeX + dateW / 2, dateBadgeY + 18)

  // === Stats Grid (3x2) ===
  const stats = currentStats.value
  const borderColors = [
    { border: 'rgba(7,193,96,0.2)', accent: green },         // matches - green
    { border: 'rgba(249,115,22,0.2)', accent: '#f97316' },   // calories - orange
    { border: 'rgba(59,130,246,0.2)', accent: '#3b82f6' },   // distance - blue
    { border: 'rgba(234,179,8,0.2)', accent: '#eab308' },    // sprints - yellow
    { border: 'rgba(168,85,247,0.2)', accent: '#a855f7' },   // duration - purple
    { border: 'rgba(239,68,68,0.2)', accent: '#ef4444' },    // heart rate - red
  ]
  const dateText = timeRange.value === 'week' ? '本周' : '今日'
  const statsData = [
    { label: `${dateText}踢球`, value: `${stats.matches}`, unit: '场' },
    { label: '热量', value: `${stats.calories}`, unit: 'kcal' },
    { label: '距离', value: `${stats.distance}`, unit: 'km' },
    { label: '冲刺', value: `${stats.sprints}`, unit: '次' },
    { label: '时间', value: `${stats.duration}`, unit: '分钟' },
    { label: '心率', value: `${stats.maxHeartRate}`, unit: 'bpm' },
  ]

  for (let i = 0; i < 6; i++) {
    const col = i % 3
    const row = Math.floor(i / 3)
    const gap = 6
    const cx = pad + col * (statCellW + gap)
    const cy = statsTop + row * (statCellH + gap + 6)

    // Card bg with gradient
    const grd = ctx.createLinearGradient(cx, cy, cx + statCellW, cy + statCellH)
    grd.addColorStop(0, '#1a1a1a')
    grd.addColorStop(1, '#2a2a2a')
    ctx.setFillStyle(grd)
    roundRect(ctx, cx, cy, statCellW, statCellH, 10)
    ctx.fill()

    // Accent border
    ctx.setStrokeStyle(borderColors[i].border)
    ctx.setLineWidth(1)
    roundRect(ctx, cx, cy, statCellW, statCellH, 10)
    ctx.stroke()

    // Label
    ctx.setFontSize(10)
    ctx.setTextAlign('left')
    ctx.setFillStyle('#999999')
    ctx.fillText(statsData[i].label, cx + 12, cy + 22)

    // Value
    ctx.setFontSize(26)
    ctx.setFillStyle('#FFFFFF')
    ctx.fillText(statsData[i].value, cx + 12, cy + 56)

    // Unit
    ctx.setFontSize(10)
    ctx.setFillStyle(borderColors[i].accent)
    ctx.fillText(statsData[i].unit, cx + 12, cy + 76)
  }

  // === Heart Rate Curve (today only) ===
  if (showHeartRate) {
    const hrX = pad
    const hrY = heartRateTop
    const hrW = contentW
    const hrH = 170

    // Card bg
    const hrGrd = ctx.createLinearGradient(hrX, hrY, hrX + hrW, hrY + hrH)
    hrGrd.addColorStop(0, '#1a1a1a')
    hrGrd.addColorStop(1, '#2a2a2a')
    ctx.setFillStyle(hrGrd)
    roundRect(ctx, hrX, hrY, hrW, hrH, 14)
    ctx.fill()
    ctx.setStrokeStyle('rgba(7,193,96,0.2)')
    ctx.setLineWidth(1)
    roundRect(ctx, hrX, hrY, hrW, hrH, 14)
    ctx.stroke()

    // Title
    ctx.setFontSize(12)
    ctx.setTextAlign('left')
    ctx.setFillStyle('#FFFFFF')
    ctx.fillText('今日心率曲线', hrX + 16, hrY + 28)

    // Draw a simple heart rate curve from session data
    const chartX = hrX + 16
    const chartY = hrY + 44
    const chartW = hrW - 32
    const chartH = hrH - 60
    const hrMin = Math.max(stats.avgHeartRate - 30, 60)
    const hrMax = stats.maxHeartRate + 10

    // Generate sample data points
    const todayList = todaySessions.value
    if (todayList.length > 0 && hrMax > hrMin) {
      // Draw grid lines
      ctx.setStrokeStyle('rgba(255,255,255,0.1)')
      ctx.setLineWidth(0.5)
      for (let g = 0; g <= 3; g++) {
        const gy = chartY + (chartH / 3) * g
        ctx.beginPath()
        ctx.moveTo(chartX, gy)
        ctx.lineTo(chartX + chartW, gy)
        ctx.stroke()
      }

      // Simple curve using avg and max HR
      const hrPoints = [
        stats.avgHeartRate,
        stats.avgHeartRate + 10,
        stats.maxHeartRate - 5,
        stats.maxHeartRate,
        stats.maxHeartRate - 15,
        stats.avgHeartRate + 5,
        stats.avgHeartRate
      ]

      ctx.beginPath()
      for (let p = 0; p < hrPoints.length; p++) {
        const px = chartX + (chartW / (hrPoints.length - 1)) * p
        const py = chartY + chartH - ((hrPoints[p] - hrMin) / (hrMax - hrMin)) * chartH
        if (p === 0) ctx.moveTo(px, py)
        else ctx.lineTo(px, py)
      }
      ctx.setStrokeStyle(green)
      ctx.setLineWidth(2.5)
      ctx.stroke()

      // Fill under curve
      ctx.lineTo(chartX + chartW, chartY + chartH)
      ctx.lineTo(chartX, chartY + chartH)
      ctx.closePath()
      ctx.setFillStyle('rgba(7,193,96,0.1)')
      ctx.fill()
    }
  }

  // === Radar Chart ===
  ctx.setFontSize(12)
  ctx.setFillStyle('#FFFFFF')
  ctx.setTextAlign('left')
  const radarTitle = timeRange.value === 'week' ? '本周能力分析' : '今日能力分析'

  // Radar card bg
  const radarCardX = pad
  const radarCardY = radarSectionTop
  const radarCardW = contentW
  const radarCardGrd = ctx.createLinearGradient(radarCardX, radarCardY, radarCardX + radarCardW, radarCardY + radarCardH)
  radarCardGrd.addColorStop(0, '#1a1a1a')
  radarCardGrd.addColorStop(1, '#2a2a2a')
  ctx.setFillStyle(radarCardGrd)
  roundRect(ctx, radarCardX, radarCardY, radarCardW, radarCardH, 14)
  ctx.fill()
  ctx.setStrokeStyle('rgba(7,193,96,0.2)')
  ctx.setLineWidth(1)
  roundRect(ctx, radarCardX, radarCardY, radarCardW, radarCardH, 14)
  ctx.stroke()

  ctx.setFontSize(12)
  ctx.setFillStyle('#FFFFFF')
  ctx.setTextAlign('left')
  ctx.fillText(radarTitle, radarCardX + 16, radarCardY + 26)

  const radarCx = W / 2
  const data = abilityData.value
  const count = data.length
  const angleStep = (Math.PI * 2) / count
  const startAngle = -Math.PI / 2

  // Grid rings
  for (let lv = 1; lv <= 4; lv++) {
    const r = (radarR / 4) * lv
    ctx.beginPath()
    for (let i = 0; i <= count; i++) {
      const angle = startAngle + angleStep * (i % count)
      const x = radarCx + r * Math.cos(angle)
      const y = radarCenterY + r * Math.sin(angle)
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.closePath()
    ctx.setStrokeStyle('rgba(255,255,255,0.2)')
    ctx.setLineWidth(0.5)
    ctx.stroke()
  }

  // Data polygon
  ctx.beginPath()
  for (let i = 0; i <= count; i++) {
    const idx = i % count
    const angle = startAngle + angleStep * idx
    const r = (data[idx].value / 100) * radarR
    const x = radarCx + r * Math.cos(angle)
    const y = radarCenterY + r * Math.sin(angle)
    if (i === 0) ctx.moveTo(x, y)
    else ctx.lineTo(x, y)
  }
  ctx.closePath()
  ctx.setFillStyle('rgba(7,193,96,0.6)')
  ctx.fill()
  ctx.setStrokeStyle(green)
  ctx.setLineWidth(2)
  ctx.stroke()

  // Labels
  ctx.setFontSize(11)
  ctx.setTextAlign('center')
  ctx.setFillStyle('rgba(255,255,255,0.9)')
  for (let i = 0; i < count; i++) {
    const angle = startAngle + angleStep * i
    const lx = radarCx + (radarR + 18) * Math.cos(angle)
    const ly = radarCenterY + (radarR + 18) * Math.sin(angle)
    ctx.fillText(data[i].ability, lx, ly + 4)
  }

  // === Heatmap (today only) ===
  if (showHeatmap) {
    const hmX = pad
    const hmY = hmSectionTop
    const hmW = contentW
    const hmH = Math.round(contentW * 3 / 4)
    const hmCardH = hmH + 40

    // Card bg
    const hmGrd = ctx.createLinearGradient(hmX, hmY, hmX + hmW, hmY + hmCardH)
    hmGrd.addColorStop(0, '#1a1a1a')
    hmGrd.addColorStop(1, '#2a2a2a')
    ctx.setFillStyle(hmGrd)
    roundRect(ctx, hmX, hmY, hmW, hmCardH, 14)
    ctx.fill()
    ctx.setStrokeStyle('rgba(7,193,96,0.2)')
    ctx.setLineWidth(1)
    roundRect(ctx, hmX, hmY, hmW, hmCardH, 14)
    ctx.stroke()

    // Title
    ctx.setFontSize(12)
    ctx.setFillStyle('#FFFFFF')
    ctx.setTextAlign('left')
    ctx.fillText('今日跑动热区', hmX + 16, hmY + 26)

    // Field area
    const fieldX = hmX + 12
    const fieldY = hmY + 36
    const fieldW = hmW - 24
    const fieldH = hmH - 16

    // Field background
    ctx.setFillStyle('#0a2a0f')
    roundRect(ctx, fieldX, fieldY, fieldW, fieldH, 10)
    ctx.fill()
    ctx.setStrokeStyle('rgba(7,193,96,0.1)')
    roundRect(ctx, fieldX, fieldY, fieldW, fieldH, 10)
    ctx.stroke()

    // Field lines
    ctx.setStrokeStyle('rgba(7,193,96,0.3)')
    ctx.setLineWidth(1)
    // Outer border
    ctx.strokeRect(fieldX + 8, fieldY + 8, fieldW - 16, fieldH - 16)
    // Center line
    ctx.beginPath()
    ctx.moveTo(fieldX + 8, fieldY + fieldH / 2)
    ctx.lineTo(fieldX + fieldW - 8, fieldY + fieldH / 2)
    ctx.stroke()
    // Center circle
    ctx.beginPath()
    ctx.arc(fieldX + fieldW / 2, fieldY + fieldH / 2, 20, 0, Math.PI * 2)
    ctx.stroke()

    // Draw heat points
    const points = parseTrackPoints(todaySessions.value)
    if (points.length > 0) {
      let minLat = Infinity, maxLat = -Infinity, minLng = Infinity, maxLng = -Infinity
      for (const p of points) {
        if (p.latitude < minLat) minLat = p.latitude
        if (p.latitude > maxLat) maxLat = p.latitude
        if (p.longitude < minLng) minLng = p.longitude
        if (p.longitude > maxLng) maxLng = p.longitude
      }
      const latPad2 = Math.max((maxLat - minLat) * 0.1, 0.0002)
      const lngPad2 = Math.max((maxLng - minLng) * 0.1, 0.0002)
      minLat -= latPad2; maxLat += latPad2
      minLng -= lngPad2; maxLng += lngPad2
      const latRange = maxLat - minLat || 0.001
      const lngRange = maxLng - minLng || 0.001
      const maxSpd = Math.max(...points.map(p => p.speed), 1)

      for (const p of points) {
        const px = fieldX + 8 + ((p.longitude - minLng) / lngRange) * (fieldW - 16)
        const py = fieldY + 8 + (1 - (p.latitude - minLat) / latRange) * (fieldH - 16)
        const intensity = Math.min(p.speed / maxSpd, 1)
        const radius = 6 + intensity * 8
        let cr: number, cg: number, cb: number
        if (intensity < 0.5) {
          const t = intensity * 2
          cr = Math.round(22 + t * 212); cg = Math.round(163 + t * 16); cb = Math.round(74 - t * 74)
        } else {
          const t = (intensity - 0.5) * 2
          cr = Math.round(234 + t * 5); cg = Math.round(179 - t * 111); cb = Math.round(t * 68)
        }
        ctx.beginPath()
        ctx.arc(px, py, radius, 0, Math.PI * 2)
        ctx.setFillStyle(`rgba(${cr},${cg},${cb},${0.5 + intensity * 0.3})`)
        ctx.fill()
      }
    } else {
      // Placeholder heat blobs
      ctx.beginPath()
      ctx.arc(fieldX + fieldW * 0.3, fieldY + fieldH * 0.35, 24, 0, Math.PI * 2)
      ctx.setFillStyle('rgba(239,68,68,0.6)')
      ctx.fill()
      ctx.beginPath()
      ctx.arc(fieldX + fieldW * 0.5, fieldY + fieldH * 0.5, 28, 0, Math.PI * 2)
      ctx.setFillStyle('rgba(249,115,22,0.7)')
      ctx.fill()
      ctx.beginPath()
      ctx.arc(fieldX + fieldW * 0.7, fieldY + fieldH * 0.65, 24, 0, Math.PI * 2)
      ctx.setFillStyle('rgba(234,179,8,0.6)')
      ctx.fill()
    }
  }

  // === Footer ===
  // Footer card bg
  const footerX = pad
  const footerW = contentW
  const footerH = 48
  const footerGrd = ctx.createLinearGradient(footerX, footerTop, footerX + footerW, footerTop + footerH)
  footerGrd.addColorStop(0, 'rgba(7,193,96,0.1)')
  footerGrd.addColorStop(1, 'rgba(5,168,80,0.1)')
  ctx.setFillStyle(footerGrd)
  roundRect(ctx, footerX, footerTop, footerW, footerH, 10)
  ctx.fill()
  ctx.setStrokeStyle('rgba(7,193,96,0.2)')
  ctx.setLineWidth(1)
  roundRect(ctx, footerX, footerTop, footerW, footerH, 10)
  ctx.stroke()

  ctx.setFontSize(11)
  ctx.setTextAlign('center')
  ctx.setFillStyle('#999999')
  ctx.fillText('来自 FootyTrack · 记录你的每一场精彩', W / 2, footerTop + 30)

  ctx.draw(false, () => {
    setTimeout(() => callback(), 300)
  })
}

function roundRect(ctx: any, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath()
  ctx.moveTo(x + r, y)
  ctx.lineTo(x + w - r, y)
  ctx.arcTo(x + w, y, x + w, y + r, r)
  ctx.lineTo(x + w, y + h - r)
  ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
  ctx.lineTo(x + r, y + h)
  ctx.arcTo(x, y + h, x, y + h - r, r)
  ctx.lineTo(x, y + r)
  ctx.arcTo(x, y, x + r, y, r)
  ctx.closePath()
}

function drawRadar() {
  const ctx = uni.createCanvasContext('radarCanvas')
  const data = abilityData.value
  const count = data.length
  if (count === 0) return

  // Canvas size in px (will be scaled by device pixel ratio via CSS)
  const size = 280
  const cx = size / 2
  const cy = size / 2
  const maxR = size / 2 - 40
  const levels = 4
  const angleStep = (Math.PI * 2) / count
  const startAngle = -Math.PI / 2

  // Clear
  ctx.clearRect(0, 0, size, size)

  // Draw grid rings
  for (let lv = 1; lv <= levels; lv++) {
    const r = (maxR / levels) * lv
    ctx.beginPath()
    for (let i = 0; i <= count; i++) {
      const angle = startAngle + angleStep * (i % count)
      const x = cx + r * Math.cos(angle)
      const y = cy + r * Math.sin(angle)
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.closePath()
    ctx.setStrokeStyle('rgba(255,255,255,0.08)')
    ctx.setLineWidth(1)
    ctx.stroke()
  }

  // Draw axis lines
  for (let i = 0; i < count; i++) {
    const angle = startAngle + angleStep * i
    ctx.beginPath()
    ctx.moveTo(cx, cy)
    ctx.lineTo(cx + maxR * Math.cos(angle), cy + maxR * Math.sin(angle))
    ctx.setStrokeStyle('rgba(255,255,255,0.06)')
    ctx.setLineWidth(1)
    ctx.stroke()
  }

  // Draw data area
  ctx.beginPath()
  for (let i = 0; i <= count; i++) {
    const idx = i % count
    const angle = startAngle + angleStep * idx
    const r = (data[idx].value / 100) * maxR
    const x = cx + r * Math.cos(angle)
    const y = cy + r * Math.sin(angle)
    if (i === 0) ctx.moveTo(x, y)
    else ctx.lineTo(x, y)
  }
  ctx.closePath()
  ctx.setFillStyle('rgba(7,193,96,0.3)')
  ctx.fill()
  ctx.setStrokeStyle('#07c160')
  ctx.setLineWidth(2)
  ctx.stroke()

  // Draw data points
  for (let i = 0; i < count; i++) {
    const angle = startAngle + angleStep * i
    const r = (data[i].value / 100) * maxR
    const x = cx + r * Math.cos(angle)
    const y = cy + r * Math.sin(angle)
    ctx.beginPath()
    ctx.arc(x, y, 3, 0, Math.PI * 2)
    ctx.setFillStyle('#07c160')
    ctx.fill()
  }

  // Draw labels
  ctx.setFontSize(11)
  ctx.setTextAlign('center')
  ctx.setTextBaseline('middle')
  ctx.setFillStyle('#999999')
  for (let i = 0; i < count; i++) {
    const angle = startAngle + angleStep * i
    const labelR = maxR + 20
    const x = cx + labelR * Math.cos(angle)
    const y = cy + labelR * Math.sin(angle)
    ctx.fillText(data[i].ability, x, y)
  }

  ctx.draw(false, () => {
    setTimeout(() => {
      uni.canvasToTempFilePath({
        canvasId: 'radarCanvas',
        success: (res) => { radarImage.value = res.tempFilePath },
        fail: (err) => { console.error('canvasToTempFilePath fail', err) },
      })
    }, 150)
  })
}

interface TrackPoint {
  latitude: number
  longitude: number
  speed: number
}

function parseTrackPoints(sessions: SessionDto[]): TrackPoint[] {
  const points: TrackPoint[] = []
  for (const s of sessions) {
    if (!s.trackPointsData) continue
    try {
      const json = decodeURIComponent(escape(atob(s.trackPointsData)))
      const arr = JSON.parse(json) as any[]
      for (const p of arr) {
        if (p.latitude && p.longitude) {
          points.push({ latitude: p.latitude, longitude: p.longitude, speed: p.speed || 0 })
        }
      }
    } catch {}
  }
  return points
}

function drawHeatmap() {
  const ctx = uni.createCanvasContext('heatmapCanvas')
  const w = 350
  const h = 263 // 4:3 ratio

  ctx.clearRect(0, 0, w, h)

  // Dark green base (low activity)
  ctx.setFillStyle('#0a2a0f')
  ctx.fillRect(0, 0, w, h)

  const points = parseTrackPoints(todaySessions.value)

  if (points.length > 0) {
    // Compute bounding box
    let minLat = Infinity, maxLat = -Infinity, minLng = Infinity, maxLng = -Infinity
    for (const p of points) {
      if (p.latitude < minLat) minLat = p.latitude
      if (p.latitude > maxLat) maxLat = p.latitude
      if (p.longitude < minLng) minLng = p.longitude
      if (p.longitude > maxLng) maxLng = p.longitude
    }

    // Add padding
    const latPad = Math.max((maxLat - minLat) * 0.1, 0.0002)
    const lngPad = Math.max((maxLng - minLng) * 0.1, 0.0002)
    minLat -= latPad; maxLat += latPad
    minLng -= lngPad; maxLng += lngPad

    const latRange = maxLat - minLat || 0.001
    const lngRange = maxLng - minLng || 0.001

    // Find max speed for normalization
    const maxSpeed = Math.max(...points.map(p => p.speed), 1)

    // Draw heat blobs
    for (const p of points) {
      const x = ((p.longitude - minLng) / lngRange) * w
      const y = (1 - (p.latitude - minLat) / latRange) * h // flip Y
      const intensity = Math.min(p.speed / maxSpeed, 1)
      const radius = 8 + intensity * 8

      // Color: green(low) → yellow → red(high)
      let r: number, g: number, b: number
      if (intensity < 0.5) {
        const t = intensity * 2
        r = Math.round(22 + t * (234 - 22))
        g = Math.round(163 + t * (179 - 163))
        b = Math.round(74 - t * 74)
      } else {
        const t = (intensity - 0.5) * 2
        r = Math.round(234 + t * (239 - 234))
        g = Math.round(179 - t * (179 - 68))
        b = Math.round(0 + t * 68)
      }

      const alpha = 0.35 + intensity * 0.35
      ctx.beginPath()
      ctx.arc(x, y, radius, 0, Math.PI * 2)
      ctx.setFillStyle(`rgba(${r},${g},${b},${alpha})`)
      ctx.fill()
    }
  }

  ctx.draw(false, () => {
    setTimeout(() => {
      uni.canvasToTempFilePath({
        canvasId: 'heatmapCanvas',
        success: (res) => { heatmapImage.value = res.tempFilePath },
        fail: (err) => { console.error('heatmap canvasToTempFilePath fail', err) },
      })
    }, 150)
  })
}

watch([timeRange, abilityData], () => {
  nextTick(() => {
    setTimeout(() => drawRadar(), 100)
    setTimeout(() => drawHeatmap(), 100)
  })
})

onShow(() => {
  loadData()
  nextTick(() => {
    setTimeout(() => drawRadar(), 300)
    setTimeout(() => drawHeatmap(), 400)
  })
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
  display: flex;
  flex-direction: column;
}

.scroll-content {
  flex: 1;
  height: calc(100vh - 260rpx);
}

// ============================================================
// Header
// ============================================================
.header {
  background: linear-gradient(135deg, $green, $greenDark);
  padding: 100rpx 32rpx 48rpx;
  box-shadow: 0 8rpx 32rpx rgba(7, 193, 96, 0.2);
}

.header-title {
  font-size: 44rpx;
  font-weight: 700;
  color: $textPrimary;
  display: block;
  margin-bottom: 20rpx;
}

.watch-badge {
  display: inline-flex;
  align-items: center;
  padding: 10rpx 20rpx;
  border-radius: 100rpx;
}

.watch-badge.connected {
  background: rgba(255, 255, 255, 0.2);
}

.watch-badge.disconnected {
  background: #FFFFFF;
}

.watch-badge-text {
  font-size: 24rpx;
  font-weight: 500;
}

.watch-badge.connected .watch-badge-text {
  color: $textPrimary;
}

.watch-badge.disconnected .watch-badge-text {
  color: $green;
}

// ============================================================
// Sections
// ============================================================
.section {
  padding: 0 32rpx 24rpx;
  &:first-child {
    padding-top: 24rpx;
  }
}

.section--last {
  padding-bottom: 160rpx;
}

// ============================================================
// Upcoming Matches
// ============================================================
.upcoming-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.upcoming-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 28rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.upcoming-card-top {
  display: flex;
  align-items: center;
  margin-bottom: 20rpx;
}

.upcoming-name {
  flex: 1;
  font-size: 30rpx;
  font-weight: 600;
  color: $textPrimary;
}

.match-status-tag {
  padding: 4rpx 16rpx;
  border-radius: 8rpx;
  margin-right: 12rpx;
  flex-shrink: 0;
}

.match-status--upcoming {
  background: rgba(7, 193, 96, 0.15);
}

.match-status--live {
  background: rgba(250, 204, 21, 0.2);
}

.match-status--finished {
  background: rgba(255, 255, 255, 0.08);
}

.match-status-tag-text {
  font-size: 22rpx;
  font-weight: 500;
}

.match-status--upcoming .match-status-tag-text {
  color: $green;
}

.match-status--live .match-status-tag-text {
  color: #FACC15;
}

.match-status--finished .match-status-tag-text {
  color: $textSecondary;
}

.upcoming-arrow {
  font-size: 36rpx;
  color: $textMuted;
  font-weight: 300;
  flex-shrink: 0;
}

.upcoming-info-rows {
  display: flex;
  flex-direction: column;
  gap: 10rpx;
  padding-left: 28rpx;
}

.upcoming-info-row {
  display: flex;
  align-items: center;
  gap: 10rpx;
}

.upcoming-info-icon {
  font-size: 22rpx;
  flex-shrink: 0;
}

.upcoming-info-text {
  font-size: 24rpx;
  color: $textSecondary;
}

// ============================================================
// Toggle Bar
// ============================================================
.toggle-bar {
  display: flex;
  background: $cardBg;
  border-radius: 100rpx;
  padding: 4rpx;
  border: $border;
}

.toggle-item {
  flex: 1;
  padding: 16rpx 0;
  border-radius: 100rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.3s;

  &.active {
    background: $green;
    box-shadow: 0 4rpx 16rpx rgba(7, 193, 96, 0.5);
  }
}

.toggle-text {
  font-size: 28rpx;
  font-weight: 500;
  color: $textMuted;

  &.active {
    color: $textPrimary;
  }
}

// ============================================================
// Match Count Card
// ============================================================
.match-count-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 36rpx 32rpx;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.match-count-left {
  display: flex;
  flex-direction: column;
}

.match-count-label {
  font-size: 28rpx;
  color: #ccc;
  margin-bottom: 8rpx;
}

.match-count-value {
  font-size: 72rpx;
  font-weight: 700;
  color: $green;
  line-height: 1;
}

.match-count-icon {
  width: 112rpx;
  height: 112rpx;
  border-radius: 32rpx;
  background: linear-gradient(135deg, $green, $greenDark);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 24rpx rgba(7, 193, 96, 0.3);
}

.match-count-weekday {
  font-size: 22rpx;
  color: rgba(255, 255, 255, 0.85);
  font-weight: 500;
  line-height: 1;
}

.match-count-date {
  font-size: 48rpx;
  font-weight: 700;
  color: $textPrimary;
  line-height: 1.1;
}

// ============================================================
// Stats Grid
// ============================================================
.stats-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16rpx;
}

.stats-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 24rpx;
  display: flex;
  flex-direction: column;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.stats-icon-box {
  width: 72rpx;
  height: 72rpx;
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 16rpx;
  box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.2);
}

.orange-red { background: linear-gradient(135deg, #fb923c, #ef4444); }
.blue { background: linear-gradient(135deg, #60a5fa, #3b82f6); }
.yellow-orange { background: linear-gradient(135deg, #facc15, #f97316); }
.purple { background: linear-gradient(135deg, #a78bfa, #7c3aed); }
.pink-red { background: linear-gradient(135deg, #f472b6, #ef4444); }
.green-teal { background: linear-gradient(135deg, #4ade80, #14b8a6); }

.stats-icon {
  font-size: 36rpx;
}

.stats-label {
  font-size: 24rpx;
  color: $textSecondary;
  margin-bottom: 8rpx;
}

.stats-value {
  font-size: 44rpx;
  font-weight: 700;
  color: $textPrimary;
  line-height: 1.1;
}

.stats-unit {
  font-size: 22rpx;
  color: $textMuted;
  margin-top: 4rpx;
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
// Radar Canvas
// ============================================================
.radar-canvas-wrap {
  display: flex;
  justify-content: center;
  align-items: center;
}

.radar-image {
  width: 560rpx;
  height: 560rpx;
}

.offscreen-canvas {
  position: fixed;
  left: -9999rpx;
  top: -9999rpx;
  width: 280px;
  height: 280px;
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
  background: #0a2a0f;
}

.heatmap-image {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
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

.offscreen-canvas--heatmap {
  width: 350px;
  height: 263px;
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
// Share Button
// ============================================================
.share-btn {
  background: linear-gradient(135deg, $green, $greenDark);
  border-radius: 100rpx;
  padding: 24rpx 40rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 14rpx;
  box-shadow: 0 8rpx 32rpx rgba(7, 193, 96, 0.3);
}

.share-btn-icon {
  width: 36rpx;
  height: 36rpx;
  flex-shrink: 0;
}

.share-btn-svg {
  width: 36rpx;
  height: 36rpx;
}

.share-btn-text {
  font-size: 30rpx;
  font-weight: 500;
  color: $textPrimary;
}

// ============================================================
// Share Dialog (Bottom Sheet)
// ============================================================
.share-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 100;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(8rpx);
  display: flex;
  align-items: flex-end;
  justify-content: center;
}

.share-sheet {
  width: 100%;
  background: $pageBg;
  border-radius: 48rpx 48rpx 0 0;
  overflow: hidden;
  box-shadow: 0 -8rpx 48rpx rgba(0, 0, 0, 0.5);
}

.share-sheet-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 32rpx;
  border-bottom: $border;
}

.share-sheet-title {
  font-size: 34rpx;
  font-weight: 600;
  color: $textPrimary;
}

.share-sheet-close {
  width: 64rpx;
  height: 64rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
}

.share-sheet-close-text {
  font-size: 32rpx;
  color: #999;
}

.share-card-scroll {
  // header ~100rpx, actions ~160rpx, safe area ~68rpx => ~328rpx overhead
  height: calc(90vh - 328rpx);
}

.share-card-preview {
  padding: 24rpx 32rpx;
}

.share-card-image {
  width: 100%;
  border-radius: 24rpx;
  box-shadow: 0 8rpx 32rpx rgba(0, 0, 0, 0.5);
}

.share-actions {
  padding: 24rpx 32rpx;
  padding-bottom: calc(24rpx + env(safe-area-inset-bottom));
  border-top: $border;
}

.share-action-btn-primary {
  width: 100%;
  padding: 24rpx 0;
  background: $green;
  border-radius: 100rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.3s;
}

.share-action-btn-text {
  font-size: 30rpx;
  font-weight: 500;
  color: $textPrimary;
}

.share-action-hint {
  display: block;
  text-align: center;
  font-size: 22rpx;
  color: $textMuted;
  margin-top: 16rpx;
}
</style>
