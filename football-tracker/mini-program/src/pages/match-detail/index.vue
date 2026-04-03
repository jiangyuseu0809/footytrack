<template>
  <view class="page">
    <!-- Nav Bar -->
    <view class="nav-bar">
      <text class="back" @tap="goBack">‹</text>
      <text class="nav-title">{{ detail?.match.title || '比赛详情' }}</text>
    </view>

    <view v-if="detail" class="content">
      <!-- Match Info Hero -->
      <view class="match-hero">
        <text class="hero-title">{{ detail.match.title }}</text>
        <view class="status-badge" :class="'status-' + detail.match.status">
          <text class="status-text">{{ statusText }}</text>
        </view>
        <view class="hero-info-rows">
          <view class="hero-info-row">
            <text class="hero-info-emoji">📍</text>
            <text class="hero-info-text">{{ detail.match.location }}</text>
          </view>
          <view class="hero-info-row">
            <text class="hero-info-emoji">📅</text>
            <text class="hero-info-text">{{ formatDateTime(detail.match.matchDate) }}</text>
          </view>
          <view class="hero-info-row">
            <text class="hero-info-emoji">👥</text>
            <text class="hero-info-text">{{ detail.registrations.length }}/{{ detail.match.groups * detail.match.playersPerGroup }} 人已报名</text>
          </view>
        </view>
      </view>

      <!-- Groups Section -->
      <view class="section-header">
        <view class="section-icon-box">
          <text class="section-icon-text">👥</text>
        </view>
        <text class="section-title">分组报名</text>
      </view>

      <view class="groups-list">
        <view v-for="(group, idx) in groupsList" :key="idx" class="group-card">
          <view class="group-color-border" :style="{ backgroundColor: group.color }" />
          <view class="group-content">
            <view class="group-top">
              <text class="group-name">{{ group.color }}队</text>
              <text class="group-count">{{ group.members.length }}/{{ detail.match.playersPerGroup }}</text>
            </view>
            <view v-for="m in group.members" :key="m.userUid" class="member-row">
              <view class="member-avatar">
                <text class="member-avatar-text">{{ m.nickname[0] }}</text>
              </view>
              <view class="member-info">
                <text class="member-name">{{ m.nickname }}</text>
                <text class="member-time">{{ formatDateTime(m.registeredAt) }}</text>
              </view>
            </view>
            <view v-if="group.members.length === 0" class="group-empty">
              <text class="group-empty-text">暂无队员</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Action Buttons -->
      <view v-if="detail.match.status === 'upcoming'" class="action-area">
        <view v-if="!detail.isRegistered" class="btn-register" @tap="handleRegister">
          <text class="btn-register-text">报名参加</text>
        </view>
        <view v-else class="btn-cancel" @tap="handleCancel">
          <text class="btn-cancel-text">取消报名</text>
        </view>
      </view>

      <!-- Rankings -->
      <view v-if="rankings && rankings.distanceRanking && rankings.distanceRanking.length > 0" class="rankings-section">
        <view class="section-header">
          <view class="section-icon-box section-icon-rank">
            <text class="section-icon-text">🏆</text>
          </view>
          <text class="section-title">距离排行</text>
        </view>
        <view class="rank-card">
          <view class="rank-card-header">
            <text class="rank-card-header-text">🏃 距离排行榜</text>
          </view>
          <view class="rank-list">
            <view v-for="(r, i) in rankings.distanceRanking" :key="r.userUid" class="rank-item">
              <view class="rank-medal-box">
                <text v-if="i < 3" class="rank-medal" :class="'medal-' + i">{{ ['🥇','🥈','🥉'][i] }}</text>
                <text v-else class="rank-number">{{ i + 1 }}</text>
              </view>
              <text class="rank-name">{{ r.nickname }}</text>
              <text class="rank-value">{{ (r.value / 1000).toFixed(1) }} km</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Calories Rankings -->
      <view v-if="rankings && rankings.caloriesRanking && rankings.caloriesRanking.length > 0" class="rankings-section">
        <view class="rank-card">
          <view class="rank-card-header rank-card-header-orange">
            <text class="rank-card-header-text">🔥 卡路里排行榜</text>
          </view>
          <view class="rank-list">
            <view v-for="(r, i) in rankings.caloriesRanking" :key="r.userUid" class="rank-item">
              <view class="rank-medal-box">
                <text v-if="i < 3" class="rank-medal" :class="'medal-' + i">{{ ['🥇','🥈','🥉'][i] }}</text>
                <text v-else class="rank-number">{{ i + 1 }}</text>
              </view>
              <text class="rank-name">{{ r.nickname }}</text>
              <text class="rank-value rank-value-orange">{{ Math.round(r.value) }} kcal</text>
            </view>
          </view>
        </view>
      </view>

      <!-- AI Summary -->
      <view v-if="summary" class="ai-summary-card">
        <view class="ai-summary-header">
          <text class="ai-summary-icon">🤖</text>
          <text class="ai-summary-title">AI 比赛总结</text>
        </view>
        <text class="ai-summary-text">{{ summary }}</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import {
  getMatchDetail, registerForMatch, cancelMatchRegistration,
  getMatchRankings, getMatchSummary, type MatchRegistration
} from '../../utils/api'
import { formatDateTime } from '../../utils/format'

const detail = ref<any>(null)
const rankings = ref<any>(null)
const summary = ref('')
const matchId = ref('')

const statusText = computed(() => {
  if (!detail.value) return ''
  const s = detail.value.match.status
  return s === 'upcoming' ? '报名中' : s === 'completed' ? '已结束' : '已取消'
})
const statusColor = computed(() => {
  if (!detail.value) return '#6B7280'
  const s = detail.value.match.status
  return s === 'upcoming' ? '#FACC15' : s === 'completed' ? '#6B7280' : '#EF4444'
})

const groupsList = computed(() => {
  if (!detail.value) return []
  const colors = detail.value.match.groupColors.split(',').map((c: string) => c.trim())
  return colors.map((color: string) => ({
    color,
    members: detail.value.registrations.filter((r: MatchRegistration) => r.groupColor === color),
  }))
})

function goBack() { uni.navigateBack() }

async function loadData() {
  try {
    detail.value = await getMatchDetail(matchId.value)
    try { rankings.value = await getMatchRankings(matchId.value) } catch {}
    try { const s = await getMatchSummary(matchId.value); summary.value = s.summary } catch {}
  } catch (e) { console.error(e) }
}

async function handleRegister() {
  const colors = detail.value.match.groupColors.split(',').map((c: string) => c.trim())
  try {
    await registerForMatch(matchId.value, colors[0] || '')
    await loadData()
    uni.showToast({ title: '报名成功', icon: 'success' })
  } catch (e: any) { uni.showToast({ title: e.message, icon: 'none' }) }
}

async function handleCancel() {
  try {
    await cancelMatchRegistration(matchId.value)
    await loadData()
    uni.showToast({ title: '已取消', icon: 'success' })
  } catch (e: any) { uni.showToast({ title: e.message, icon: 'none' }) }
}

onLoad(async (options) => {
  matchId.value = options?.id || ''
  if (matchId.value) await loadData()
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

/* ---- Match Hero ---- */
.match-hero {
  background: linear-gradient(135deg, #16803B, #166534);
  border-radius: 36rpx;
  padding: 32rpx;
  margin-bottom: 32rpx;
}

.hero-title {
  font-size: 36rpx;
  font-weight: 700;
  color: #FFFFFF;
  display: block;
  margin-bottom: 16rpx;
}

.status-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 6rpx 16rpx;
  border-radius: 12rpx;
  margin-bottom: 20rpx;
}

.status-upcoming {
  background: #FACC15;
}

.status-live {
  background: #22C55E;
}

.status-completed {
  background: #6B7280;
}

.status-cancelled {
  background: #6B7280;
}

.status-text {
  font-size: 22rpx;
  font-weight: 700;
  color: #000000;
}

.hero-info-rows {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.hero-info-row {
  display: flex;
  align-items: center;
  gap: 12rpx;
}

.hero-info-emoji {
  font-size: 24rpx;
}

.hero-info-text {
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.85);
}

/* ---- Section Headers ---- */
.section-header {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-bottom: 20rpx;
}

.section-icon-box {
  width: 52rpx;
  height: 52rpx;
  border-radius: 16rpx;
  background: rgba(0, 230, 118, 0.16);
  display: flex;
  align-items: center;
  justify-content: center;
}

.section-icon-rank {
  background: rgba(255, 165, 2, 0.16);
}

.section-icon-text {
  font-size: 24rpx;
}

.section-title {
  font-size: 30rpx;
  font-weight: 600;
  color: #FFFFFF;
}

/* ---- Groups ---- */
.groups-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
  margin-bottom: 32rpx;
}

.group-card {
  background: #1C2333;
  border-radius: 32rpx;
  display: flex;
  overflow: hidden;
  border: 1rpx solid rgba(255, 255, 255, 0.08);
}

.group-color-border {
  width: 6rpx;
  flex-shrink: 0;
}

.group-content {
  flex: 1;
  padding: 24rpx;
}

.group-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16rpx;
}

.group-name {
  font-size: 28rpx;
  font-weight: 600;
  color: #FFFFFF;
}

.group-count {
  font-size: 24rpx;
  color: #8B949E;
}

.member-row {
  display: flex;
  align-items: center;
  gap: 16rpx;
  padding: 12rpx 0;
}

.member-avatar {
  width: 72rpx;
  height: 72rpx;
  border-radius: 50%;
  background: #242D3D;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.member-avatar-text {
  font-size: 28rpx;
  color: #00E676;
  font-weight: 600;
}

.member-info {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.member-name {
  font-size: 26rpx;
  color: #FFFFFF;
}

.member-time {
  font-size: 22rpx;
  color: #8B949E;
  margin-top: 2rpx;
}

.group-empty {
  padding: 16rpx 0;
}

.group-empty-text {
  font-size: 24rpx;
  color: #8B949E;
}

/* ---- Action Buttons ---- */
.action-area {
  margin-bottom: 32rpx;
}

.btn-register {
  background: linear-gradient(135deg, #00E676, #00BFA5);
  border-radius: 24rpx;
  height: 96rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.btn-register-text {
  font-size: 30rpx;
  font-weight: 600;
  color: #0D1117;
}

.btn-cancel {
  background: transparent;
  border: 2rpx solid #EF4444;
  border-radius: 24rpx;
  height: 96rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.btn-cancel-text {
  font-size: 30rpx;
  font-weight: 600;
  color: #EF4444;
}

/* ---- Rankings ---- */
.rankings-section {
  margin-bottom: 24rpx;
}

.rank-card {
  background: #1C2333;
  border-radius: 32rpx;
  overflow: hidden;
  border: 1rpx solid rgba(255, 255, 255, 0.08);
}

.rank-card-header {
  background: linear-gradient(135deg, #16803B, #166534);
  padding: 20rpx 24rpx;
}

.rank-card-header-orange {
  background: linear-gradient(135deg, #FFA502, #FF6348);
}

.rank-card-header-text {
  font-size: 26rpx;
  font-weight: 600;
  color: #FFFFFF;
}

.rank-list {
  padding: 8rpx 0;
}

.rank-item {
  display: flex;
  align-items: center;
  padding: 18rpx 24rpx;
}

.rank-medal-box {
  width: 52rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.rank-medal {
  font-size: 32rpx;
}

.medal-0 {
  color: #FFD700;
}

.medal-1 {
  color: #C0C0C0;
}

.medal-2 {
  color: #CD7F32;
}

.rank-number {
  font-size: 28rpx;
  font-weight: 600;
  color: #8B949E;
}

.rank-name {
  flex: 1;
  font-size: 28rpx;
  color: #FFFFFF;
}

.rank-value {
  font-size: 28rpx;
  font-weight: 600;
  color: #00E676;
}

.rank-value-orange {
  color: #FFA502;
}

/* ---- AI Summary ---- */
.ai-summary-card {
  background: #1C2333;
  border-radius: 32rpx;
  padding: 28rpx 32rpx;
  border: 2rpx solid transparent;
  background-clip: padding-box;
  position: relative;
  margin-bottom: 24rpx;

  &::before {
    content: '';
    position: absolute;
    top: -2rpx;
    left: -2rpx;
    right: -2rpx;
    bottom: -2rpx;
    border-radius: 34rpx;
    background: linear-gradient(135deg, #4F46E5, #7C3AED);
    z-index: -1;
  }
}

.ai-summary-header {
  display: flex;
  align-items: center;
  gap: 12rpx;
  margin-bottom: 20rpx;
}

.ai-summary-icon {
  font-size: 28rpx;
}

.ai-summary-title {
  font-size: 30rpx;
  font-weight: 600;
  color: #FFFFFF;
}

.ai-summary-text {
  font-size: 26rpx;
  color: #8B949E;
  line-height: 1.7;
}
</style>
