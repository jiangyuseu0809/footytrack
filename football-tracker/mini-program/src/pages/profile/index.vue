<template>
  <view class="page">
    <!-- Header -->
    <view class="header">
      <text class="header-title">我的</text>

      <!-- User Info -->
      <view class="user-info">
        <button class="avatar-btn" open-type="chooseAvatar" @chooseavatar="onChooseAvatar">
          <image v-if="profile?.avatarUrl" class="avatar-img" :src="profile.avatarUrl" mode="aspectFill" />
          <view v-else class="avatar-circle">
            <text class="avatar-icon">👤</text>
          </view>
        </button>
        <view class="user-text">
          <input
            type="nickname"
            class="nickname-input"
            :value="profile?.nickname || '足球爱好者'"
            placeholder="设置昵称"
            placeholder-class="nickname-placeholder"
            @blur="onNicknameBlur"
          />
          <text class="join-date">加入于 {{ joinDate }}</text>
        </view>
      </view>
    </view>

    <scroll-view scroll-y class="scroll-area">
      <!-- Not Logged In State -->
      <view v-if="!loggedIn" class="login-prompt">
        <view class="login-prompt-icon">
          <text class="login-prompt-emoji">👤</text>
        </view>
        <text class="login-prompt-title">登录后查看个人数据</text>
        <text class="login-prompt-sub">登录后可查看训练统计、徽章和AI分析</text>
        <view class="login-prompt-btn" @tap="goLogin">
          <text class="login-prompt-btn-text">去登录</text>
        </view>
      </view>

      <template v-if="loggedIn">
        <!-- Stats Cards -->
        <view class="section">
          <view class="stats-row">
            <view class="stat-card">
              <view class="stat-icon-box green-gradient">
                <text class="stat-icon">🏆</text>
              </view>
              <text class="stat-card-value">{{ totalSessions }}</text>
              <text class="stat-card-label">场比赛</text>
            </view>
            <view class="stat-card">
              <view class="stat-icon-box blue-gradient">
                <text class="stat-icon">🎯</text>
              </view>
              <text class="stat-card-value">{{ totalDistanceStr }}</text>
              <text class="stat-card-label">公里</text>
            </view>
            <view class="stat-card">
              <view class="stat-icon-box orange-gradient">
                <text class="stat-icon">🔥</text>
              </view>
              <text class="stat-card-value">{{ totalCaloriesStr }}</text>
              <text class="stat-card-label">千卡</text>
            </view>
          </view>
        </view>

        <!-- Monthly Goal -->
        <view class="section">
          <view class="goal-card">
            <view class="goal-header">
              <text class="goal-title">本月目标</text>
              <text class="goal-percent">{{ monthGoalPercent }}%</text>
            </view>
            <view class="goal-bar-track">
              <view class="goal-bar-fill" :style="{ width: monthGoalPercent + '%' }" />
            </view>
            <text class="goal-desc">已完成 {{ monthSessions }}/{{ monthGoalTarget }} 场比赛，继续加油！</text>
          </view>
        </view>

        <!-- Menu Items -->
        <view class="section">
          <view class="menu-card">
            <!-- AI Analysis -->
            <view class="menu-row" @tap="loadAnalysis">
              <view class="menu-icon-box blue-icon">
                <text class="menu-icon-text">🧠</text>
              </view>
              <text class="menu-label">球风分析</text>
              <text class="menu-chevron">›</text>
            </view>

            <view v-if="analysis" class="analysis-expand">
              <view class="analysis-inner">
                <text class="analysis-type">{{ analysis.type }}</text>
                <text class="analysis-desc">{{ analysis.description }}</text>
                <view class="analysis-strengths">
                  <text v-for="s in analysis.strengths" :key="s" class="strength-tag">{{ s }}</text>
                </view>
                <text class="analysis-advice">💡 {{ analysis.advice }}</text>
              </view>
            </view>

            <view class="menu-divider" />

            <!-- Badges -->
            <view class="menu-row" @tap="showBadges = !showBadges">
              <view class="menu-icon-box orange-icon">
                <text class="menu-icon-text">🏆</text>
              </view>
              <text class="menu-label">徽章墙</text>
              <view class="badge-count-pill">
                <text class="badge-count-text">{{ earnedCount }}/{{ totalBadges }}</text>
              </view>
              <text class="menu-chevron">›</text>
            </view>

            <view v-if="showBadges" class="badges-expand">
              <view class="badges-grid">
                <view v-for="b in allBadges" :key="b.id" class="badge-item" :class="{ earned: isEarned(b.id) }">
                  <view class="badge-icon-wrap">
                    <text class="badge-icon-text">{{ badgeIcon(b.iconName) }}</text>
                  </view>
                  <text class="badge-name">{{ b.name }}</text>
                </view>
              </view>
            </view>
          </view>
        </view>

        <!-- Menu Group 2 -->
        <view class="section">
          <view class="menu-card">
            <view class="menu-row" @tap="goBindWatch">
              <view class="menu-icon-box green-icon">
                <text class="menu-icon-text">⌚</text>
              </view>
              <text class="menu-label">绑定手表</text>
              <text class="menu-chevron">›</text>
            </view>

            <view class="menu-divider" />

            <view class="menu-row">
              <view class="menu-icon-box purple-icon">
                <text class="menu-icon-text">💬</text>
              </view>
              <text class="menu-label">意见反馈</text>
              <text class="menu-chevron">›</text>
            </view>

            <view class="menu-divider" />

            <view class="menu-row">
              <view class="menu-icon-box pink-icon">
                <text class="menu-icon-text">❤️</text>
              </view>
              <text class="menu-label">打赏支持</text>
              <text class="menu-chevron">›</text>
            </view>
          </view>
        </view>

        <!-- Logout -->
        <view class="section">
          <view class="logout-btn" @tap="handleLogout">
            <text class="logout-text">退出登录</text>
          </view>
        </view>

        <!-- About -->
        <view class="about-section section--last">
          <text class="about-text">FootyTrack v1.0.0</text>
          <text class="about-sub">记录每一次精彩瞬间</text>
        </view>
      </template>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import {
  getProfile, getSessions, getPlayerAnalysis, getEarnedBadges,
  clearAuth, isLoggedIn, updateProfile, uploadAvatar,
  type UserProfile, type SessionDto, type Badge, type UserBadge
} from '../../utils/api'
import { formatDistance } from '../../utils/format'

const profile = ref<UserProfile | null>(null)
const sessions = ref<SessionDto[]>([])
const analysis = ref<{ type: string; description: string; strengths: string[]; advice: string } | null>(null)
const allBadges = ref<Badge[]>([])
const earnedBadges = ref<UserBadge[]>([])
const showBadges = ref(false)
const loggedIn = ref(isLoggedIn())

const totalSessions = computed(() => sessions.value.length)
const totalDistanceStr = computed(() => {
  const meters = sessions.value.reduce((s, v) => s + (v.totalDistanceMeters || 0), 0)
  return (meters / 1000).toFixed(1)
})
const totalCaloriesStr = computed(() => {
  const cal = sessions.value.reduce((s, v) => s + (v.caloriesBurned || 0), 0)
  return cal >= 1000 ? (cal / 1000).toFixed(1) + 'k' : Math.round(cal).toString()
})

const joinDate = computed(() => {
  if (!profile.value?.createdAt) return '--'
  const d = new Date(profile.value.createdAt)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
})

const monthSessions = computed(() => {
  const now = new Date()
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).getTime()
  return sessions.value.filter(s => s.startTime >= monthStart).length
})

const monthGoalTarget = 12
const monthGoalPercent = computed(() => Math.min(100, Math.round((monthSessions.value / monthGoalTarget) * 100)))

const earnedCount = computed(() => earnedBadges.value.length)
const totalBadges = computed(() => allBadges.value.length)

function isEarned(id: string) {
  return earnedBadges.value.some(e => e.badge.id === id)
}

function badgeIcon(iconName: string): string {
  const map: Record<string, string> = {
    'flame.fill': '🔥', 'bolt.fill': '⚡', 'star.fill': '⭐',
    'trophy.fill': '🏆', 'figure.run': '🏃', 'heart.fill': '❤️',
    iron_man: '🦾', century_legend: '👑', speed_star: '⚡',
    marathon_runner: '🏃', calorie_burner: '🔥', perfect_month: '📅',
    sprint_king: '💨',
  }
  return map[iconName] || '🏅'
}

async function loadData() {
  loggedIn.value = isLoggedIn()
  if (!loggedIn.value) return
  try {
    const [p, s, b] = await Promise.all([getProfile(), getSessions(), getEarnedBadges()])
    profile.value = p
    sessions.value = s.sessions
    allBadges.value = b.allBadges
    earnedBadges.value = b.earnedBadges
  } catch (e) { console.error(e) }
}

function goLogin() {
  uni.navigateTo({ url: '/pages/login/index' })
}

async function onChooseAvatar(e: any) {
  const tempPath = e.detail.avatarUrl
  if (!tempPath) return
  try {
    uni.showLoading({ title: '上传中...' })
    const res = await uploadAvatar(tempPath)
    if (profile.value) profile.value.avatarUrl = res.avatarUrl
    uni.hideLoading()
    uni.showToast({ title: '头像已更新', icon: 'success' })
  } catch (err: any) {
    uni.hideLoading()
    uni.showToast({ title: err.message || '上传失败', icon: 'none' })
  }
}

async function onNicknameBlur(e: any) {
  const newName = e.detail.value
  if (!newName || newName === profile.value?.nickname) return
  try {
    const res = await updateProfile({ nickname: newName })
    if (profile.value) profile.value.nickname = res.nickname
    uni.showToast({ title: '昵称已更新', icon: 'success' })
  } catch (err: any) {
    uni.showToast({ title: err.message || '更新失败', icon: 'none' })
  }
}

function goBindWatch() {
  uni.navigateTo({ url: '/pages/bind-watch/index' })
}

async function loadAnalysis() {
  if (analysis.value) { analysis.value = null; return }
  try {
    uni.showLoading({ title: 'AI分析中...' })
    analysis.value = await getPlayerAnalysis()
    uni.hideLoading()
  } catch (e: any) {
    uni.hideLoading()
    uni.showToast({ title: e.message || '分析失败', icon: 'none' })
  }
}

function handleLogout() {
  uni.showModal({
    title: '确认退出',
    content: '确定要退出登录吗？',
    success(res) {
      if (res.confirm) {
        clearAuth()
        uni.reLaunch({ url: '/pages/login/index' })
      }
    }
  })
}

onShow(() => { loadData() })
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
  height: calc(100vh - 340rpx);
}

// ============================================================
// Header
// ============================================================
.header {
  background: linear-gradient(135deg, $green, $greenDark);
  padding: 120rpx 32rpx 48rpx;
  box-shadow: 0 8rpx 32rpx rgba(7, 193, 96, 0.2);
}

.header-title {
  font-size: 34rpx;
  font-weight: 700;
  color: $textPrimary;
  display: block;
  margin-bottom: 32rpx;
  text-align: center;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 24rpx;
}

.avatar-circle {
  width: 120rpx;
  height: 120rpx;
  border-radius: 50%;
  background: #FFFFFF;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4rpx 16rpx rgba(0, 0, 0, 0.15);
}

.avatar-btn {
  background: transparent !important;
  border: none;
  padding: 0;
  margin: 0;
  width: 120rpx;
  height: 120rpx;
  border-radius: 50%;
  overflow: hidden;
  flex-shrink: 0;

  &::after {
    border: none;
  }
}

.avatar-img {
  width: 120rpx;
  height: 120rpx;
  border-radius: 50%;
  box-shadow: 0 4rpx 16rpx rgba(0, 0, 0, 0.15);
}

.avatar-icon {
  font-size: 56rpx;
}

.nickname-input {
  font-size: 36rpx;
  font-weight: 700;
  color: $textPrimary;
  background: transparent;
  margin-bottom: 4rpx;
}

.nickname-placeholder {
  color: rgba(255, 255, 255, 0.5);
}

.user-text {
  display: flex;
  flex-direction: column;
}

.join-date {
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.9);
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
// Stats Cards
// ============================================================
.stats-row {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 16rpx;
}

.stat-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 24rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.stat-icon-box {
  width: 72rpx;
  height: 72rpx;
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 12rpx;
  box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.2);
}

.green-gradient { background: linear-gradient(135deg, $green, $greenDark); }
.blue-gradient { background: linear-gradient(135deg, #60a5fa, #3b82f6); }
.orange-gradient { background: linear-gradient(135deg, #fb923c, #ef4444); }

.stat-icon {
  font-size: 36rpx;
}

.stat-card-value {
  font-size: 40rpx;
  font-weight: 700;
  color: $textPrimary;
}

.stat-card-label {
  font-size: 22rpx;
  color: $textMuted;
  margin-top: 4rpx;
}

// ============================================================
// Monthly Goal
// ============================================================
.goal-card {
  background: linear-gradient(135deg, #1a1a2a, #1a2a2a);
  border-radius: 32rpx;
  padding: 32rpx;
  border: 1rpx solid rgba(168, 85, 247, 0.2);
  box-shadow: 0 4rpx 16rpx rgba(0, 0, 0, 0.2);
}

.goal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16rpx;
}

.goal-title {
  font-size: 30rpx;
  font-weight: 500;
  color: $textPrimary;
}

.goal-percent {
  font-size: 24rpx;
  color: $textSecondary;
}

.goal-bar-track {
  width: 100%;
  height: 12rpx;
  background: #2a2a2a;
  border-radius: 6rpx;
  overflow: hidden;
  margin-bottom: 12rpx;
}

.goal-bar-fill {
  height: 100%;
  background: linear-gradient(90deg, $green, $greenDark);
  border-radius: 6rpx;
  box-shadow: 0 0 12rpx rgba(7, 193, 96, 0.5);
}

.goal-desc {
  font-size: 24rpx;
  color: $textSecondary;
}

// ============================================================
// Menu Card
// ============================================================
.menu-card {
  background: $cardBg;
  border-radius: 32rpx;
  overflow: hidden;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.menu-row {
  display: flex;
  align-items: center;
  padding: 24rpx 28rpx;
  gap: 16rpx;
}

.menu-icon-box {
  width: 72rpx;
  height: 72rpx;
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.2);
}

.blue-icon { background: linear-gradient(135deg, #60a5fa, #3b82f6); }
.orange-icon { background: linear-gradient(135deg, #facc15, #f97316); }
.green-icon { background: linear-gradient(135deg, $green, $greenDark); }
.purple-icon { background: linear-gradient(135deg, #60a5fa, #3b82f6); }
.pink-icon { background: linear-gradient(135deg, #f472b6, #ef4444); }

.menu-icon-text {
  font-size: 36rpx;
}

.menu-label {
  flex: 1;
  font-size: 30rpx;
  font-weight: 500;
  color: $textPrimary;
}

.menu-chevron {
  font-size: 36rpx;
  color: $textMuted;
  font-weight: 300;
}

.badge-count-pill {
  background: rgba(7, 193, 96, 0.12);
  padding: 6rpx 16rpx;
  border-radius: 16rpx;
  margin-right: 8rpx;
}

.badge-count-text {
  font-size: 22rpx;
  color: $green;
  font-weight: 600;
}

.menu-divider {
  height: 1rpx;
  background: #2a2a2a;
  margin: 0 28rpx 0 112rpx;
}

// ============================================================
// AI Analysis Expand
// ============================================================
.analysis-expand {
  padding: 0 28rpx 24rpx;
}

.analysis-inner {
  background: $pageBg;
  border-radius: 24rpx;
  padding: 24rpx;
  border: 1rpx solid rgba(79, 70, 229, 0.3);
}

.analysis-type {
  font-size: 32rpx;
  font-weight: 700;
  color: #A855F7;
  display: block;
  margin-bottom: 8rpx;
}

.analysis-desc {
  font-size: 24rpx;
  color: $textSecondary;
  display: block;
  margin-bottom: 16rpx;
  line-height: 1.5;
}

.analysis-strengths {
  display: flex;
  flex-wrap: wrap;
  gap: 10rpx;
  margin-bottom: 16rpx;
}

.strength-tag {
  background: rgba(168, 85, 247, 0.12);
  color: #A855F7;
  font-size: 22rpx;
  padding: 8rpx 20rpx;
  border-radius: 20rpx;
  font-weight: 500;
}

.analysis-advice {
  font-size: 24rpx;
  color: #FFA502;
  display: block;
  line-height: 1.5;
}

// ============================================================
// Badges Expand
// ============================================================
.badges-expand {
  padding: 0 28rpx 24rpx;
}

.badges-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 16rpx;
}

.badge-item {
  width: calc(25% - 12rpx);
  text-align: center;
  padding: 16rpx 0;
  opacity: 0.3;

  &.earned {
    opacity: 1;
    .badge-icon-wrap {
      border: 1rpx solid rgba(7, 193, 96, 0.3);
      box-shadow: 0 0 16rpx rgba(7, 193, 96, 0.15);
    }
  }
}

.badge-icon-wrap {
  width: 80rpx;
  height: 80rpx;
  border-radius: 24rpx;
  background: #252525;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 8rpx;
}

.badge-icon-text {
  font-size: 40rpx;
}

.badge-name {
  font-size: 20rpx;
  color: $textSecondary;
  display: block;
}

// ============================================================
// About
// ============================================================
.about-section {
  text-align: center;
  padding: 32rpx 0 16rpx;
}

.about-text {
  font-size: 22rpx;
  color: $textMuted;
  display: block;
  margin-bottom: 4rpx;
}

.about-sub {
  font-size: 22rpx;
  color: $textMuted;
  display: block;
}

// ============================================================
// Logout
// ============================================================
.logout-btn {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 28rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  border: $border;
}

.logout-text {
  font-size: 28rpx;
  font-weight: 600;
  color: #FF4757;
}

// ============================================================
// Login Prompt
// ============================================================
.login-prompt {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 120rpx 48rpx 60rpx;
}

.login-prompt-icon {
  width: 120rpx;
  height: 120rpx;
  border-radius: 50%;
  background: #FFFFFF;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 24rpx;
}

.login-prompt-emoji {
  font-size: 56rpx;
}

.login-prompt-title {
  font-size: 32rpx;
  font-weight: 600;
  color: $textPrimary;
  display: block;
  margin-bottom: 8rpx;
}

.login-prompt-sub {
  font-size: 26rpx;
  color: $textSecondary;
  display: block;
  margin-bottom: 40rpx;
}

.login-prompt-btn {
  width: 360rpx;
  height: 88rpx;
  background: linear-gradient(135deg, $green, $greenDark);
  border-radius: 100rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 24rpx rgba(7, 193, 96, 0.3);
}

.login-prompt-btn-text {
  font-size: 30rpx;
  font-weight: 600;
  color: #FFFFFF;
}
</style>
