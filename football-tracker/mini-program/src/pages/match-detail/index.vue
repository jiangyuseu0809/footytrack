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
        <text class="nav-title">{{ detail?.match.title || '比赛详情' }}</text>
        <view class="nav-right" />
      </view>
    </view>

    <scroll-view v-if="detail" scroll-y class="scroll-area">
      <!-- Match Info Hero -->
      <view class="section">
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
      </view>

      <!-- Groups Section -->
      <view class="section">
        <view class="section-header-row">
          <view class="section-icon-box green-icon">
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
      </view>

      <!-- Action Buttons -->
      <view v-if="detail.match.status === 'upcoming'" class="section">
        <view v-if="!detail.isRegistered" class="btn-register" @tap="handleRegister">
          <text class="btn-register-text">报名参加</text>
        </view>
        <view v-else class="btn-cancel" @tap="handleCancel">
          <text class="btn-cancel-text">取消报名</text>
        </view>
      </view>

      <!-- Rankings: Distance -->
      <view v-if="rankings && rankings.distanceRanking && rankings.distanceRanking.length > 0" class="section">
        <view class="section-header-row">
          <view class="section-icon-box orange-icon">
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
                <text v-if="i < 3" class="rank-medal">{{ ['🥇','🥈','🥉'][i] }}</text>
                <text v-else class="rank-number">{{ i + 1 }}</text>
              </view>
              <text class="rank-name">{{ r.nickname }}</text>
              <text class="rank-value">{{ (r.value / 1000).toFixed(1) }} km</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Rankings: Calories -->
      <view v-if="rankings && rankings.caloriesRanking && rankings.caloriesRanking.length > 0" class="section">
        <view class="rank-card">
          <view class="rank-card-header rank-card-header-orange">
            <text class="rank-card-header-text">🔥 卡路里排行榜</text>
          </view>
          <view class="rank-list">
            <view v-for="(r, i) in rankings.caloriesRanking" :key="r.userUid" class="rank-item">
              <view class="rank-medal-box">
                <text v-if="i < 3" class="rank-medal">{{ ['🥇','🥈','🥉'][i] }}</text>
                <text v-else class="rank-number">{{ i + 1 }}</text>
              </view>
              <text class="rank-name">{{ r.nickname }}</text>
              <text class="rank-value rank-value-orange">{{ Math.round(r.value) }} kcal</text>
            </view>
          </view>
        </view>
      </view>

      <!-- AI Summary -->
      <view v-if="summary" class="section section--last">
        <view class="ai-summary-card">
          <view class="ai-summary-header">
            <text class="ai-summary-icon">🤖</text>
            <text class="ai-summary-title">AI 比赛总结</text>
          </view>
          <text class="ai-summary-text">{{ summary }}</text>
        </view>
      </view>
    </scroll-view>
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

const menuBtn = uni.getMenuButtonBoundingClientRect()
const sysInfo = uni.getSystemInfoSync()
const statusBarHeight = sysInfo.statusBarHeight || 44
const capsuleHeight = menuBtn.height
const navBarHeight = (menuBtn.top - statusBarHeight) * 2 + menuBtn.height

const statusText = computed(() => {
  if (!detail.value) return ''
  const s = detail.value.match.status
  return s === 'upcoming' ? '报名中' : s === 'completed' ? '已结束' : '已取消'
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
function goHome() { uni.switchTab({ url: '/pages/home/index' }) }

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
  height: calc(100vh - 240rpx);
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

.section-header-row {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-bottom: 20rpx;
}

.section-icon-box {
  width: 52rpx;
  height: 52rpx;
  border-radius: 16rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.green-icon { background: rgba(7, 193, 96, 0.16); }
.orange-icon { background: rgba(255, 165, 2, 0.16); }

.section-icon-text {
  font-size: 24rpx;
}

.section-title {
  font-size: 30rpx;
  font-weight: 600;
  color: $textPrimary;
}

// ============================================================
// Match Hero
// ============================================================
.match-hero {
  background: linear-gradient(135deg, $green, $greenDark);
  border-radius: 32rpx;
  padding: 32rpx;
  box-shadow: 0 8rpx 32rpx rgba(7, 193, 96, 0.2);
}

.hero-title {
  font-size: 36rpx;
  font-weight: 700;
  color: $textPrimary;
  display: block;
  margin-bottom: 16rpx;
}

.status-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 6rpx 20rpx;
  border-radius: 16rpx;
  margin-bottom: 20rpx;
}

.status-upcoming { background: #FACC15; }
.status-live { background: #22C55E; }
.status-completed { background: rgba(255, 255, 255, 0.2); }
.status-cancelled { background: rgba(255, 255, 255, 0.2); }

.status-text {
  font-size: 22rpx;
  font-weight: 700;
  color: #000000;
}

.status-completed .status-text,
.status-cancelled .status-text {
  color: $textPrimary;
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

// ============================================================
// Groups
// ============================================================
.groups-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.group-card {
  background: $cardBg;
  border-radius: 32rpx;
  display: flex;
  overflow: hidden;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
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
  color: $textPrimary;
}

.group-count {
  font-size: 24rpx;
  color: $textSecondary;
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
  background: #252525;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.member-avatar-text {
  font-size: 28rpx;
  color: $green;
  font-weight: 600;
}

.member-info {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.member-name {
  font-size: 26rpx;
  color: $textPrimary;
}

.member-time {
  font-size: 22rpx;
  color: $textSecondary;
  margin-top: 2rpx;
}

.group-empty {
  padding: 16rpx 0;
}

.group-empty-text {
  font-size: 24rpx;
  color: $textSecondary;
}

// ============================================================
// Action Buttons
// ============================================================
.btn-register {
  background: linear-gradient(90deg, $green, $greenDark);
  border-radius: 100rpx;
  height: 96rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 24rpx rgba(7, 193, 96, 0.3);
}

.btn-register-text {
  font-size: 30rpx;
  font-weight: 600;
  color: $textPrimary;
}

.btn-cancel {
  background: transparent;
  border: 2rpx solid #EF4444;
  border-radius: 100rpx;
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

// ============================================================
// Rankings
// ============================================================
.rank-card {
  background: $cardBg;
  border-radius: 32rpx;
  overflow: hidden;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.rank-card-header {
  background: linear-gradient(135deg, $green, $greenDark);
  padding: 20rpx 24rpx;
}

.rank-card-header-orange {
  background: linear-gradient(135deg, #FFA502, #FF6348);
}

.rank-card-header-text {
  font-size: 26rpx;
  font-weight: 600;
  color: $textPrimary;
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

.rank-number {
  font-size: 28rpx;
  font-weight: 600;
  color: $textSecondary;
}

.rank-name {
  flex: 1;
  font-size: 28rpx;
  color: $textPrimary;
}

.rank-value {
  font-size: 28rpx;
  font-weight: 600;
  color: $green;
}

.rank-value-orange {
  color: #FFA502;
}

// ============================================================
// AI Summary
// ============================================================
.ai-summary-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 28rpx 32rpx;
  border: 1rpx solid rgba(168, 85, 247, 0.3);
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
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
  color: $textPrimary;
}

.ai-summary-text {
  font-size: 26rpx;
  color: $textSecondary;
  line-height: 1.7;
}
</style>
