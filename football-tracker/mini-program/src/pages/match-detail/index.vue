<template>
  <view class="page">
    <view class="nav-bar">
      <text class="back" @tap="goBack">‹</text>
      <text class="nav-title">{{ detail?.match.title || '比赛详情' }}</text>
    </view>

    <view v-if="detail" class="content">
      <view class="match-hero">
        <text class="match-status">{{ statusText }}</text>
        <text class="match-location">📍 {{ detail.match.location }}</text>
        <text class="match-date">🕐 {{ formatDateTime(detail.match.matchDate) }}</text>
      </view>

      <!-- Groups -->
      <view class="section-title">分组报名 ({{ detail.registrations.length }}/{{ detail.match.groups * detail.match.playersPerGroup }})</view>
      <view class="groups">
        <view v-for="(group, idx) in groupsList" :key="idx" class="group-card">
          <view class="group-header" :style="{ borderLeftColor: group.color }">
            <text class="group-name">{{ group.color }}队</text>
            <text class="group-count">{{ group.members.length }}/{{ detail.match.playersPerGroup }}</text>
          </view>
          <view v-for="m in group.members" :key="m.userUid" class="group-member">
            <text>{{ m.nickname }}</text>
          </view>
        </view>
      </view>

      <!-- Register/Cancel -->
      <view v-if="detail.match.status === 'upcoming'" class="action-area">
        <view v-if="!detail.isRegistered" class="btn register" @tap="handleRegister">
          <text>报名参加</text>
        </view>
        <view v-else class="btn cancel" @tap="handleCancel">
          <text>取消报名</text>
        </view>
      </view>

      <!-- Rankings -->
      <view v-if="rankings" class="section-title">排行榜</view>
      <view v-if="rankings" class="rankings">
        <view class="rank-section">
          <text class="rank-label">🏃 距离排行</text>
          <view v-for="(r, i) in rankings.distanceRanking" :key="r.userUid" class="rank-item">
            <text class="rank-pos">{{ ['🥇','🥈','🥉'][i] || (i+1) }}</text>
            <text class="rank-name">{{ r.nickname }}</text>
            <text class="rank-value">{{ (r.value/1000).toFixed(1) }} km</text>
          </view>
        </view>
      </view>

      <!-- AI Summary -->
      <view v-if="summary" class="summary-card">
        <text class="summary-title">🤖 AI 比赛总结</text>
        <text class="summary-text">{{ summary }}</text>
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
.page { min-height: 100vh; background: #0D1117; }
.nav-bar {
  padding: 100rpx 28rpx 28rpx; display: flex; align-items: center;
  .back { font-size: 52rpx; color: #00E676; margin-right: 12rpx; font-weight: 300; }
  .nav-title { font-size: 36rpx; font-weight: 600; color: #fff; }
}
.content { padding: 0 28rpx 60rpx; }
.match-hero {
  background: linear-gradient(135deg, #3B82F6, #4F46E5);
  border-radius: 28rpx; padding: 32rpx; margin-bottom: 24rpx;
  .match-status { font-size: 36rpx; font-weight: 700; color: #fff; display: block; margin-bottom: 12rpx; }
  .match-location, .match-date { font-size: 26rpx; color: rgba(255,255,255,0.8); display: block; margin-bottom: 6rpx; }
}
.section-title { font-size: 28rpx; font-weight: 600; color: #8B949E; margin-bottom: 16rpx; }
.groups { display: flex; flex-wrap: wrap; gap: 16rpx; margin-bottom: 24rpx;
  .group-card {
    flex: 1; min-width: 45%;
    background: #1C2333; border-radius: 20rpx; padding: 16rpx;
    border: 1rpx solid rgba(255,255,255,0.08);
    .group-header {
      display: flex; justify-content: space-between; border-left: 6rpx solid; padding-left: 12rpx; margin-bottom: 8rpx;
      .group-name { font-size: 26rpx; font-weight: 600; color: #fff; }
      .group-count { font-size: 22rpx; color: #8B949E; }
    }
    .group-member { font-size: 24rpx; color: #8B949E; padding: 4rpx 0 4rpx 18rpx; }
  }
}
.action-area { margin-bottom: 24rpx;
  .btn {
    text-align: center; padding: 24rpx; border-radius: 44rpx; font-size: 30rpx; font-weight: 600;
    &.register { background: #00E676; color: #0D1117; }
    &.cancel { background: #1C2333; color: #E53935; border: 1rpx solid #E53935; }
  }
}
.rankings { margin-bottom: 24rpx;
  .rank-section { .rank-label { font-size: 26rpx; color: #8B949E; display: block; margin-bottom: 12rpx; } }
  .rank-item {
    background: #1C2333; border-radius: 16rpx; padding: 16rpx 20rpx;
    display: flex; align-items: center; margin-bottom: 8rpx;
    .rank-pos { font-size: 28rpx; margin-right: 16rpx; }
    .rank-name { flex: 1; font-size: 26rpx; color: #fff; }
    .rank-value { font-size: 26rpx; color: #00E676; }
  }
}
.summary-card {
  background: #1C2333; border-radius: 28rpx; padding: 24rpx;
  border: 1rpx solid rgba(0,230,118,0.15);
  .summary-title { font-size: 28rpx; font-weight: 600; color: #00E676; display: block; margin-bottom: 12rpx; }
  .summary-text { font-size: 26rpx; color: #8B949E; line-height: 1.6; }
}
</style>
