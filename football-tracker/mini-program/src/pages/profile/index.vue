<template>
  <view class="page">
    <view class="nav-bar">
      <text class="nav-title">我的</text>
    </view>

    <!-- Profile Card -->
    <view class="profile-card">
      <view class="avatar-wrap">
        <text class="avatar-text">{{ avatarLetter }}</text>
      </view>
      <view class="profile-info">
        <text class="nickname">{{ profile?.nickname || '球员' }}</text>
        <text class="member-badge">高级会员</text>
      </view>
      <view class="profile-stats">
        <view class="p-stat">
          <text class="p-stat-value">{{ totalSessions }}</text>
          <text class="p-stat-label">总场次</text>
        </view>
        <view class="p-stat">
          <text class="p-stat-value">{{ totalDistanceStr }}</text>
          <text class="p-stat-label">总距离</text>
        </view>
        <view class="p-stat">
          <text class="p-stat-value">{{ totalCaloriesStr }}</text>
          <text class="p-stat-label">总卡路里</text>
        </view>
      </view>
    </view>

    <!-- AI Analysis -->
    <view class="section">
      <view class="menu-card" @tap="loadAnalysis">
        <text class="menu-icon">🧠</text>
        <text class="menu-text">AI 球风分析</text>
        <text class="chevron">›</text>
      </view>
      <view v-if="analysis" class="analysis-card">
        <text class="analysis-type">{{ analysis.type }}</text>
        <text class="analysis-desc">{{ analysis.description }}</text>
        <view class="analysis-strengths">
          <text v-for="s in analysis.strengths" :key="s" class="strength-tag">{{ s }}</text>
        </view>
        <text class="analysis-advice">💡 {{ analysis.advice }}</text>
      </view>
    </view>

    <!-- Badges -->
    <view class="section">
      <view class="menu-card" @tap="showBadges = !showBadges">
        <text class="menu-icon">🏆</text>
        <text class="menu-text">徽章墙</text>
        <text class="badge-count">{{ earnedCount }}/{{ totalBadges }}</text>
        <text class="chevron">›</text>
      </view>
      <view v-if="showBadges" class="badges-grid">
        <view v-for="b in allBadges" :key="b.id" class="badge-item" :class="{ earned: isEarned(b.id) }">
          <text class="badge-icon">{{ badgeIcon(b.iconName) }}</text>
          <text class="badge-name">{{ b.name }}</text>
        </view>
      </view>
    </view>

    <!-- Menu -->
    <view class="section">
      <view class="menu-card">
        <text class="menu-icon">⚙️</text>
        <text class="menu-text">体重 {{ profile?.weightKg || '-' }} kg / 年龄 {{ profile?.age || '-' }}</text>
      </view>
    </view>

    <!-- Logout -->
    <view class="section">
      <view class="menu-card logout" @tap="handleLogout">
        <text class="logout-text">退出登录</text>
      </view>
    </view>
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
  }
  return map[iconName] || '🏅'
}

async function loadData() {
  if (!isLoggedIn()) { uni.reLaunch({ url: '/pages/login/index' }); return }
  try {
    const [p, s, b] = await Promise.all([getProfile(), getSessions(), getEarnedBadges()])
    profile.value = p
    sessions.value = s.sessions
    allBadges.value = b.allBadges
    earnedBadges.value = b.earnedBadges
  } catch (e) { console.error(e) }
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
.page {
  min-height: 100vh;
  background: #0D1117;
  padding-bottom: 120rpx;
}
.nav-bar {
  padding: 100rpx 28rpx 28rpx;
  .nav-title { font-size: 42rpx; font-weight: 700; color: #fff; }
}
.profile-card {
  margin: 0 28rpx 24rpx;
  background: linear-gradient(135deg, #3B82F6, #4F46E5);
  border-radius: 28rpx;
  padding: 32rpx;
  .avatar-wrap {
    width: 100rpx; height: 100rpx; border-radius: 50%;
    background: rgba(255,255,255,0.2);
    display: flex; align-items: center; justify-content: center;
    margin-bottom: 12rpx;
    .avatar-text { font-size: 44rpx; color: #fff; font-weight: 700; }
  }
  .profile-info {
    margin-bottom: 20rpx;
    .nickname { font-size: 34rpx; font-weight: 700; color: #fff; }
    .member-badge {
      font-size: 20rpx; color: #FFD700;
      background: rgba(255,215,0,0.15);
      padding: 4rpx 12rpx; border-radius: 12rpx;
      margin-left: 12rpx;
    }
  }
  .profile-stats {
    display: flex; justify-content: space-between;
    .p-stat {
      text-align: center;
      .p-stat-value { font-size: 32rpx; font-weight: 700; color: #fff; display: block; }
      .p-stat-label { font-size: 22rpx; color: rgba(255,255,255,0.7); display: block; }
    }
  }
}
.section { padding: 0 28rpx 16rpx; }
.menu-card {
  background: #1C2333;
  border-radius: 28rpx;
  padding: 24rpx 28rpx;
  display: flex;
  align-items: center;
  border: 1rpx solid rgba(255,255,255,0.08);
  margin-bottom: 12rpx;
  .menu-icon { font-size: 32rpx; margin-right: 16rpx; }
  .menu-text { flex: 1; font-size: 28rpx; color: #fff; }
  .badge-count { font-size: 24rpx; color: #8B949E; margin-right: 8rpx; }
  .chevron { font-size: 36rpx; color: #30363D; }
}
.logout {
  justify-content: center;
  .logout-text { color: #E53935; font-size: 28rpx; font-weight: 600; }
}
.analysis-card {
  background: #1C2333;
  border-radius: 28rpx;
  padding: 24rpx;
  margin-bottom: 12rpx;
  border: 1rpx solid rgba(0,230,118,0.2);
  .analysis-type { font-size: 32rpx; font-weight: 700; color: #00E676; display: block; margin-bottom: 8rpx; }
  .analysis-desc { font-size: 24rpx; color: #8B949E; display: block; margin-bottom: 12rpx; }
  .analysis-strengths {
    display: flex; flex-wrap: wrap; gap: 8rpx; margin-bottom: 12rpx;
    .strength-tag {
      background: rgba(0,230,118,0.1); color: #00E676;
      font-size: 22rpx; padding: 6rpx 16rpx; border-radius: 16rpx;
    }
  }
  .analysis-advice { font-size: 24rpx; color: #FFA502; display: block; }
}
.badges-grid {
  display: flex; flex-wrap: wrap; gap: 16rpx;
  padding: 12rpx 0;
  .badge-item {
    width: calc(25% - 12rpx);
    text-align: center; padding: 16rpx 0;
    opacity: 0.3;
    &.earned { opacity: 1; }
    .badge-icon { font-size: 48rpx; display: block; }
    .badge-name { font-size: 20rpx; color: #8B949E; display: block; }
  }
}
</style>
