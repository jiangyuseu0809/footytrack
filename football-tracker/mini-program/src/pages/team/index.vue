<template>
  <view class="page">
    <view class="nav-bar">
      <text class="nav-title">球队</text>
    </view>

    <!-- Team List -->
    <view class="section">
      <view v-if="teams.length === 0" class="empty-state">
        <text class="empty-text">还没有加入球队</text>
      </view>
      <view v-for="team in teams" :key="team.id" class="team-card" @tap="goTeamDetail(team.id)">
        <view class="team-icon">⚽</view>
        <view class="team-info">
          <text class="team-name">{{ team.name }}</text>
          <text class="team-code">邀请码: {{ team.inviteCode }}</text>
        </view>
        <text class="chevron">›</text>
      </view>
    </view>

    <!-- Actions -->
    <view class="section">
      <view class="action-row">
        <view class="action-btn create" @tap="showCreateModal = true">
          <text>创建球队</text>
        </view>
        <view class="action-btn join" @tap="showJoinModal = true">
          <text>加入球队</text>
        </view>
      </view>
    </view>

    <!-- Create Modal -->
    <view v-if="showCreateModal" class="modal-mask" @tap="showCreateModal = false">
      <view class="modal" @tap.stop>
        <text class="modal-title">创建球队</text>
        <input class="modal-input" v-model="newTeamName" placeholder="球队名称" placeholder-class="placeholder" />
        <view class="modal-btn" @tap="handleCreate">确定</view>
      </view>
    </view>

    <!-- Join Modal -->
    <view v-if="showJoinModal" class="modal-mask" @tap="showJoinModal = false">
      <view class="modal" @tap.stop>
        <text class="modal-title">加入球队</text>
        <input class="modal-input" v-model="joinCode" placeholder="输入邀请码" placeholder-class="placeholder" />
        <view class="modal-btn" @tap="handleJoin">加入</view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { getTeams, createTeam, joinTeam, isLoggedIn, type Team } from '../../utils/api'

const teams = ref<Team[]>([])
const showCreateModal = ref(false)
const showJoinModal = ref(false)
const newTeamName = ref('')
const joinCode = ref('')

async function loadData() {
  if (!isLoggedIn()) { uni.reLaunch({ url: '/pages/login/index' }); return }
  try {
    const res = await getTeams()
    teams.value = res.teams
  } catch (e) { console.error(e) }
}

async function handleCreate() {
  if (!newTeamName.value) return
  try {
    await createTeam(newTeamName.value)
    showCreateModal.value = false
    newTeamName.value = ''
    await loadData()
    uni.showToast({ title: '创建成功', icon: 'success' })
  } catch (e: any) {
    uni.showToast({ title: e.message, icon: 'none' })
  }
}

async function handleJoin() {
  if (!joinCode.value) return
  try {
    await joinTeam(joinCode.value)
    showJoinModal.value = false
    joinCode.value = ''
    await loadData()
    uni.showToast({ title: '加入成功', icon: 'success' })
  } catch (e: any) {
    uni.showToast({ title: e.message, icon: 'none' })
  }
}

function goTeamDetail(id: string) {
  uni.navigateTo({ url: `/pages/team-detail/index?id=${id}` })
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
.section { padding: 0 28rpx 20rpx; }
.empty-state {
  text-align: center; padding: 80rpx 0;
  .empty-text { color: #8B949E; font-size: 28rpx; }
}
.team-card {
  background: #1C2333;
  border-radius: 28rpx;
  padding: 24rpx 28rpx;
  margin-bottom: 16rpx;
  display: flex;
  align-items: center;
  border: 1rpx solid rgba(255,255,255,0.08);
  .team-icon { font-size: 44rpx; margin-right: 20rpx; }
  .team-info {
    flex: 1;
    .team-name { font-size: 30rpx; font-weight: 600; color: #fff; display: block; }
    .team-code { font-size: 22rpx; color: #8B949E; display: block; margin-top: 4rpx; }
  }
  .chevron { font-size: 36rpx; color: #30363D; }
}
.action-row {
  display: flex; gap: 20rpx;
  .action-btn {
    flex: 1; text-align: center;
    padding: 22rpx; border-radius: 44rpx;
    font-size: 28rpx; font-weight: 600;
    &.create { background: #00E676; color: #0D1117; }
    &.join { background: #1C2333; color: #00E676; border: 1rpx solid #00E676; }
  }
}
.modal-mask {
  position: fixed; top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.6);
  display: flex; align-items: center; justify-content: center;
  z-index: 999;
}
.modal {
  width: 80%; background: #1C2333;
  border-radius: 28rpx; padding: 40rpx;
  .modal-title { font-size: 32rpx; font-weight: 600; color: #fff; display: block; margin-bottom: 24rpx; }
  .modal-input {
    background: #0D1117; border-radius: 20rpx;
    padding: 24rpx; font-size: 28rpx; color: #fff;
    margin-bottom: 24rpx; border: 1rpx solid #30363D;
  }
  .modal-btn {
    background: #00E676; color: #0D1117;
    text-align: center; padding: 22rpx;
    border-radius: 44rpx; font-size: 28rpx; font-weight: 600;
  }
}
.placeholder { color: #545d68; }
</style>
