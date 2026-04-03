<template>
  <view class="page">
    <!-- Header -->
    <view class="header">
      <view class="header-nav">
        <view class="back-row" @tap="goBack">
          <text class="back-arrow">‹</text>
          <text class="back-text">返回</text>
        </view>
        <text class="nav-title">{{ detail?.team.name || '球队详情' }}</text>
        <view class="nav-right" />
      </view>
    </view>

    <scroll-view v-if="detail" scroll-y class="scroll-area">
      <!-- Hero Card -->
      <view class="section">
        <view class="hero-card">
          <text class="hero-team-name">{{ detail.team.name }}</text>
          <view class="hero-stats-row">
            <view class="hero-stat">
              <text class="hero-stat-value">{{ detail.members.length }}</text>
              <text class="hero-stat-label">队员</text>
            </view>
            <view class="hero-stat-divider" />
            <view class="hero-stat">
              <text class="hero-stat-value">{{ avgDistance }}</text>
              <text class="hero-stat-label">平均距离(km)</text>
            </view>
            <view class="hero-stat-divider" />
            <view class="hero-stat">
              <text class="hero-stat-value">{{ totalSessions }}</text>
              <text class="hero-stat-label">总场次</text>
            </view>
          </view>
          <view class="hero-invite-row" @tap="copyInviteCode">
            <text class="hero-invite-label">邀请码</text>
            <view class="hero-invite-code-box">
              <text class="hero-invite-code">{{ detail.team.inviteCode }}</text>
              <text class="hero-invite-copy">复制</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Squad Section -->
      <view class="section">
        <view class="section-header-row">
          <view class="section-icon-box">
            <text class="section-icon-text">👥</text>
          </view>
          <text class="section-title">球队阵容</text>
        </view>

        <view class="member-list">
          <view v-for="m in detail.members" :key="m.userUid" class="member-card">
            <view class="member-avatar">
              <text class="member-avatar-text">{{ m.nickname[0] }}</text>
            </view>
            <view class="member-info">
              <view class="member-name-row">
                <text class="member-name">{{ m.nickname }}</text>
                <view v-if="m.role === 'creator'" class="role-badge role-badge-creator">
                  <text class="role-badge-text role-badge-text-creator">队长</text>
                </view>
                <view v-else class="role-badge role-badge-member">
                  <text class="role-badge-text role-badge-text-member">队员</text>
                </view>
              </view>
              <view class="member-stats-row">
                <text class="member-stat">{{ m.sessionCount }} 场训练</text>
                <text class="member-stat-dot">·</text>
                <text class="member-stat">{{ (m.totalDistanceMeters / 1000).toFixed(1) }} km</text>
              </view>
            </view>
          </view>
        </view>
      </view>

      <!-- Leave Button -->
      <view class="section section--last">
        <view class="leave-btn" @tap="handleLeave">
          <text class="leave-btn-text">离开球队</text>
        </view>
      </view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { getTeamDetail, leaveTeam } from '../../utils/api'

const detail = ref<any>(null)
const teamId = ref('')

const avgDistance = computed(() => {
  if (!detail.value || detail.value.members.length === 0) return '0'
  const total = detail.value.members.reduce((sum: number, m: any) => sum + (m.totalDistanceMeters || 0), 0)
  return (total / detail.value.members.length / 1000).toFixed(1)
})

const totalSessions = computed(() => {
  if (!detail.value) return 0
  return detail.value.members.reduce((sum: number, m: any) => sum + (m.sessionCount || 0), 0)
})

function goBack() { uni.navigateBack() }

function copyInviteCode() {
  if (!detail.value) return
  uni.setClipboardData({
    data: detail.value.team.inviteCode,
    success: () => uni.showToast({ title: '已复制', icon: 'success' })
  })
}

async function handleLeave() {
  uni.showModal({
    title: '确认离开',
    content: '确定要离开这支球队吗？',
    async success(res) {
      if (!res.confirm) return
      try {
        await leaveTeam(teamId.value)
        uni.showToast({ title: '已离开', icon: 'success' })
        setTimeout(() => uni.navigateBack(), 1000)
      } catch (e: any) {
        uni.showToast({ title: e.message, icon: 'none' })
      }
    }
  })
}

onLoad(async (options) => {
  teamId.value = options?.id || ''
  if (teamId.value) {
    try {
      detail.value = await getTeamDetail(teamId.value)
    } catch (e) { console.error(e) }
  }
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
  background: linear-gradient(135deg, $green, $greenDark);
  padding: 100rpx 32rpx 36rpx;
  box-shadow: 0 8rpx 32rpx rgba(7, 193, 96, 0.2);
}

.header-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
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
  background: rgba(7, 193, 96, 0.16);
  display: flex;
  align-items: center;
  justify-content: center;
}

.section-icon-text {
  font-size: 24rpx;
}

.section-title {
  font-size: 30rpx;
  font-weight: 600;
  color: $textPrimary;
}

// ============================================================
// Hero Card
// ============================================================
.hero-card {
  background: linear-gradient(135deg, $green, $greenDark);
  border-radius: 32rpx;
  padding: 32rpx;
  box-shadow: 0 8rpx 32rpx rgba(7, 193, 96, 0.2);
}

.hero-team-name {
  font-size: 40rpx;
  font-weight: 700;
  color: $textPrimary;
  display: block;
  margin-bottom: 24rpx;
}

.hero-stats-row {
  display: flex;
  align-items: center;
  background: rgba(255, 255, 255, 0.15);
  border-radius: 24rpx;
  padding: 20rpx 0;
  margin-bottom: 24rpx;
}

.hero-stat {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.hero-stat-value {
  font-size: 36rpx;
  font-weight: 700;
  color: $textPrimary;
}

.hero-stat-label {
  font-size: 20rpx;
  color: rgba(255, 255, 255, 0.75);
  margin-top: 4rpx;
}

.hero-stat-divider {
  width: 1rpx;
  height: 48rpx;
  background: rgba(255, 255, 255, 0.2);
}

.hero-invite-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.hero-invite-label {
  font-size: 24rpx;
  color: rgba(255, 255, 255, 0.75);
}

.hero-invite-code-box {
  display: flex;
  align-items: center;
  gap: 12rpx;
  background: rgba(255, 255, 255, 0.15);
  border-radius: 16rpx;
  padding: 10rpx 20rpx;
}

.hero-invite-code {
  font-size: 28rpx;
  font-weight: 600;
  color: $textPrimary;
  font-family: monospace;
  letter-spacing: 2rpx;
}

.hero-invite-copy {
  font-size: 22rpx;
  color: rgba(255, 255, 255, 0.7);
}

// ============================================================
// Member List
// ============================================================
.member-list {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.member-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 24rpx;
  display: flex;
  align-items: center;
  gap: 20rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.member-avatar {
  width: 88rpx;
  height: 88rpx;
  border-radius: 50%;
  background: #252525;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.member-avatar-text {
  font-size: 32rpx;
  color: $green;
  font-weight: 600;
}

.member-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 6rpx;
}

.member-name-row {
  display: flex;
  align-items: center;
  gap: 12rpx;
}

.member-name {
  font-size: 28rpx;
  font-weight: 600;
  color: $textPrimary;
}

.role-badge {
  padding: 4rpx 14rpx;
  border-radius: 10rpx;
}

.role-badge-creator {
  background: rgba(7, 193, 96, 0.16);
}

.role-badge-member {
  background: rgba(153, 153, 153, 0.16);
}

.role-badge-text {
  font-size: 20rpx;
  font-weight: 600;
}

.role-badge-text-creator {
  color: $green;
}

.role-badge-text-member {
  color: $textSecondary;
}

.member-stats-row {
  display: flex;
  align-items: center;
  gap: 8rpx;
}

.member-stat {
  font-size: 22rpx;
  color: $textSecondary;
}

.member-stat-dot {
  font-size: 22rpx;
  color: #2a2a2a;
}

// ============================================================
// Leave Button
// ============================================================
.leave-btn {
  border: 2rpx solid #FF4757;
  border-radius: 100rpx;
  height: 96rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
}

.leave-btn-text {
  font-size: 30rpx;
  font-weight: 600;
  color: #FF4757;
}
</style>
