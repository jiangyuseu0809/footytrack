<template>
  <view class="page">
    <view class="nav-bar">
      <text class="back" @tap="goBack">‹</text>
      <text class="nav-title">{{ detail?.team.name || '球队详情' }}</text>
    </view>

    <view v-if="detail" class="content">
      <!-- Team Info -->
      <view class="team-hero">
        <text class="team-name">{{ detail.team.name }}</text>
        <view class="invite-row" @tap="copyInviteCode">
          <text class="invite-label">邀请码:</text>
          <text class="invite-code">{{ detail.team.inviteCode }}</text>
          <text class="copy-hint">点击复制</text>
        </view>
      </view>

      <!-- Members -->
      <text class="section-title">队员 ({{ detail.members.length }})</text>
      <view v-for="m in detail.members" :key="m.userUid" class="member-card">
        <view class="member-avatar">
          <text>{{ m.nickname[0] }}</text>
        </view>
        <view class="member-info">
          <text class="member-name">{{ m.nickname }}</text>
          <text class="member-role">{{ m.role === 'creator' ? '队长' : '队员' }}</text>
        </view>
        <view class="member-stats">
          <text class="m-stat">{{ m.sessionCount }} 场</text>
          <text class="m-stat">{{ (m.totalDistanceMeters / 1000).toFixed(1) }} km</text>
        </view>
      </view>

      <!-- Leave -->
      <view class="leave-btn" @tap="handleLeave">
        <text>离开球队</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { getTeamDetail, leaveTeam } from '../../utils/api'

const detail = ref<any>(null)
const teamId = ref('')

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
.page { min-height: 100vh; background: #0D1117; }
.nav-bar {
  padding: 100rpx 28rpx 28rpx; display: flex; align-items: center;
  .back { font-size: 52rpx; color: #00E676; margin-right: 12rpx; font-weight: 300; }
  .nav-title { font-size: 36rpx; font-weight: 600; color: #fff; }
}
.content { padding: 0 28rpx 60rpx; }
.team-hero {
  background: linear-gradient(135deg, #3B82F6, #4F46E5);
  border-radius: 28rpx; padding: 32rpx; margin-bottom: 24rpx;
  .team-name { font-size: 40rpx; font-weight: 700; color: #fff; display: block; margin-bottom: 12rpx; }
  .invite-row {
    display: flex; align-items: center; gap: 8rpx;
    .invite-label { font-size: 24rpx; color: rgba(255,255,255,0.7); }
    .invite-code { font-size: 28rpx; font-weight: 600; color: #fff; }
    .copy-hint { font-size: 20rpx; color: rgba(255,255,255,0.5); }
  }
}
.section-title { font-size: 28rpx; font-weight: 600; color: #8B949E; margin-bottom: 16rpx; }
.member-card {
  background: #1C2333; border-radius: 20rpx; padding: 20rpx;
  display: flex; align-items: center; margin-bottom: 12rpx;
  border: 1rpx solid rgba(255,255,255,0.08);
  .member-avatar {
    width: 72rpx; height: 72rpx; border-radius: 50%;
    background: #242D3D; display: flex; align-items: center; justify-content: center;
    color: #00E676; font-size: 28rpx; font-weight: 600; margin-right: 16rpx;
  }
  .member-info {
    flex: 1;
    .member-name { font-size: 28rpx; color: #fff; display: block; }
    .member-role { font-size: 22rpx; color: #8B949E; display: block; }
  }
  .member-stats {
    text-align: right;
    .m-stat { font-size: 22rpx; color: #8B949E; display: block; }
  }
}
.leave-btn {
  background: #1C2333; border: 1rpx solid #E53935;
  text-align: center; padding: 22rpx; border-radius: 44rpx;
  margin-top: 40rpx;
  color: #E53935; font-size: 28rpx; font-weight: 600;
}
</style>
