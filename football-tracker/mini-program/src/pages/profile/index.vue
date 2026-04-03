<template>
  <view class="page">
    <view class="nav-bar">
      <text class="nav-title">我的</text>
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
      <!-- Hero Card -->
      <view class="hero-card">
        <view class="hero-top">
          <view class="avatar-circle">
            <text class="avatar-letter">{{ avatarLetter }}</text>
          </view>
          <view class="hero-info">
            <view class="name-row">
              <text class="nickname">{{ profile?.nickname || '球员' }}</text>
              <view class="member-pill">
                <text class="member-text">高级会员</text>
              </view>
            </view>
          </view>
        </view>
        <view class="hero-stats">
          <view class="hero-stat">
            <text class="hero-stat-value">{{ totalSessions }}</text>
            <text class="hero-stat-label">总场次</text>
          </view>
          <view class="hero-stat-divider" />
          <view class="hero-stat">
            <text class="hero-stat-value">{{ totalDistanceStr }}</text>
            <text class="hero-stat-label">总距离</text>
          </view>
          <view class="hero-stat-divider" />
          <view class="hero-stat">
            <text class="hero-stat-value">{{ totalCaloriesStr }}</text>
            <text class="hero-stat-label">总卡路里</text>
          </view>
        </view>
      </view>

      <!-- Menu Group 1 -->
      <view class="menu-group">
        <view class="menu-row" @tap="loadAnalysis">
          <view class="menu-icon-box">
            <text class="menu-icon">🧠</text>
          </view>
          <text class="menu-label">AI 球风分析</text>
          <text class="menu-chevron">›</text>
        </view>

        <!-- AI Analysis Expand -->
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

        <view class="menu-row" @tap="showBadges = !showBadges">
          <view class="menu-icon-box">
            <text class="menu-icon">🏆</text>
          </view>
          <text class="menu-label">徽章墙</text>
          <view class="badge-count-pill">
            <text class="badge-count-text">{{ earnedCount }}/{{ totalBadges }}</text>
          </view>
          <text class="menu-chevron">›</text>
        </view>

        <!-- Badges Grid Expand -->
        <view v-if="showBadges" class="badges-expand">
          <view class="badges-grid">
            <view v-for="b in allBadges" :key="b.id" class="badge-item" :class="{ earned: isEarned(b.id) }">
              <view class="badge-icon-wrap">
                <text class="badge-icon">{{ badgeIcon(b.iconName) }}</text>
              </view>
              <text class="badge-name">{{ b.name }}</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Menu Group 2 -->
      <view class="menu-group">
        <view class="menu-row" @tap="goBindWatch">
          <view class="menu-icon-box">
            <text class="menu-icon">⌚</text>
          </view>
          <text class="menu-label">绑定 Apple Watch</text>
          <text class="menu-chevron">›</text>
        </view>

        <view class="menu-divider" />

        <view class="menu-row">
          <view class="menu-icon-box">
            <text class="menu-icon">⚙️</text>
          </view>
          <text class="menu-label">个人信息</text>
          <text class="menu-sub">{{ profile?.weightKg || '-' }}kg / {{ profile?.age || '-' }}岁</text>
          <text class="menu-chevron">›</text>
        </view>
      </view>

      <!-- Logout -->
      <view class="menu-group logout-group" @tap="handleLogout">
        <text class="logout-text">退出登录</text>
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
  clearAuth, isLoggedIn, type UserProfile, type SessionDto, type Badge, type UserBadge
} from '../../utils/api'
import { formatDistance } from '../../utils/format'

const profile = ref<UserProfile | null>(null)
const sessions = ref<SessionDto[]>([])
const analysis = ref<{ type: string; description: string; strengths: string[]; advice: string } | null>(null)
const allBadges = ref<Badge[]>([])
const earnedBadges = ref<UserBadge[]>([])
const showBadges = ref(false)
const loggedIn = ref(isLoggedIn())

const avatarLetter = computed(() => (profile.value?.nickname || '球')[0])
const totalSessions = computed(() => sessions.value.length)
const totalDistanceStr = computed(() => formatDistance(sessions.value.reduce((s, v) => s + (v.totalDistanceMeters || 0), 0)))
const totalCaloriesStr = computed(() => Math.round(sessions.value.reduce((s, v) => s + (v.caloriesBurned || 0), 0)).toString())
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

/* Hero Card */
.hero-card {
  margin: 0 32rpx 32rpx;
  background: linear-gradient(135deg, #3B82F6, #4F46E5);
  border-radius: 36rpx;
  padding: 32rpx;
}
.hero-top {
  display: flex;
  align-items: center;
  gap: 24rpx;
  margin-bottom: 28rpx;
}
.avatar-circle {
  width: 152rpx; height: 152rpx;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.2);
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
  .avatar-letter { font-size: 80rpx; color: $textPrimary; font-weight: 700; }
}
.hero-info {
  flex: 1;
}
.name-row {
  display: flex;
  align-items: center;
  gap: 12rpx;
  .nickname { font-size: 36rpx; font-weight: 700; color: $textPrimary; }
  .member-pill {
    background: rgba(255, 255, 255, 0.2);
    padding: 4rpx 16rpx;
    border-radius: 16rpx;
    .member-text { font-size: 20rpx; color: #FFD700; font-weight: 600; }
  }
}
.hero-stats {
  display: flex;
  align-items: center;
  padding-top: 24rpx;
  border-top: 1rpx solid rgba(255, 255, 255, 0.2);
}
.hero-stat {
  flex: 1;
  text-align: center;
  .hero-stat-value { font-size: 32rpx; font-weight: 700; color: $textPrimary; display: block; }
  .hero-stat-label { font-size: 22rpx; color: rgba(255, 255, 255, 0.7); display: block; margin-top: 4rpx; }
}
.hero-stat-divider {
  width: 1rpx;
  height: 48rpx;
  background: rgba(255, 255, 255, 0.25);
}

/* Menu Groups */
.menu-group {
  margin: 0 32rpx 24rpx;
  background: $cardBg;
  border-radius: 32rpx;
  border: 1rpx solid rgba(255, 255, 255, 0.08);
  overflow: hidden;
}
.menu-row {
  display: flex;
  align-items: center;
  padding: 24rpx 28rpx;
  gap: 16rpx;
}
.menu-icon-box {
  width: 68rpx; height: 68rpx;
  border-radius: 18rpx;
  background: $cardBgLight;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
  .menu-icon { font-size: 32rpx; }
}
.menu-label {
  flex: 1;
  font-size: 28rpx;
  font-weight: 500;
  color: $textPrimary;
}
.menu-sub {
  font-size: 24rpx;
  color: $textSecondary;
  margin-right: 8rpx;
}
.menu-chevron {
  font-size: 36rpx;
  color: $divider;
  font-weight: 300;
}
.badge-count-pill {
  background: rgba(0, 230, 118, 0.12);
  padding: 4rpx 12rpx;
  border-radius: 12rpx;
  margin-right: 8rpx;
  .badge-count-text { font-size: 22rpx; color: $neonGreen; font-weight: 600; }
}
.menu-divider {
  height: 1rpx;
  background: rgba(48, 54, 61, 0.6);
  margin: 0 28rpx;
}

/* AI Analysis Expand */
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
  .strength-tag {
    background: rgba(168, 85, 247, 0.12);
    color: #A855F7;
    font-size: 22rpx;
    padding: 8rpx 20rpx;
    border-radius: 20rpx;
    font-weight: 500;
  }
}
.analysis-advice {
  font-size: 24rpx;
  color: #FFA502;
  display: block;
  line-height: 1.5;
}

/* Badges Expand */
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
      border: 1rpx solid rgba(0, 230, 118, 0.3);
      box-shadow: 0 0 16rpx rgba(0, 230, 118, 0.15);
    }
  }
}
.badge-icon-wrap {
  width: 80rpx; height: 80rpx;
  border-radius: 24rpx;
  background: $cardBgLight;
  display: flex; align-items: center; justify-content: center;
  margin: 0 auto 8rpx;
  .badge-icon { font-size: 40rpx; }
}
.badge-name {
  font-size: 20rpx;
  color: $textSecondary;
  display: block;
}

/* Logout */
.logout-group {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 28rpx;
}
.logout-text {
  font-size: 28rpx;
  font-weight: 600;
  color: #FF4757;
}

/* Login Prompt */
.login-prompt {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 120rpx 48rpx 60rpx;
}
.login-prompt-icon {
  width: 120rpx;
  height: 120rpx;
  border-radius: 32rpx;
  background: rgba(0, 230, 118, 0.1);
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
  background: linear-gradient(135deg, #00E676, #00BFA5);
  border-radius: 24rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}
.login-prompt-btn-text {
  font-size: 30rpx;
  font-weight: 600;
  color: #FFFFFF;
}
</style>
