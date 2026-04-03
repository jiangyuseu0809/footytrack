<template>
  <view class="page">
    <!-- Nav Bar -->
    <view class="nav-bar">
      <text class="nav-title">球队</text>
    </view>

    <!-- No Team State: Hero + CTA -->
    <view v-if="teams.length === 0" class="content">
      <view class="hero-card">
        <view class="hero-icon-row">
          <text class="hero-icon">⚽</text>
        </view>
        <text class="hero-title">加入或创建球队</text>
        <text class="hero-subtitle">组建你的球队，一起追踪训练数据，互相比拼提升</text>
      </view>

      <view class="feature-list">
        <view class="feature-row">
          <view class="feature-icon-box feature-icon-1">
            <text class="feature-icon-text">📊</text>
          </view>
          <view class="feature-text-col">
            <text class="feature-title">数据共享</text>
            <text class="feature-desc">查看队友的训练数据和排行榜</text>
          </view>
        </view>
        <view class="feature-row">
          <view class="feature-icon-box feature-icon-2">
            <text class="feature-icon-text">🏆</text>
          </view>
          <view class="feature-text-col">
            <text class="feature-title">队内排行</text>
            <text class="feature-desc">距离、速度、卡路里等多维度排名</text>
          </view>
        </view>
        <view class="feature-row">
          <view class="feature-icon-box feature-icon-3">
            <text class="feature-icon-text">📅</text>
          </view>
          <view class="feature-text-col">
            <text class="feature-title">比赛组织</text>
            <text class="feature-desc">快速创建比赛、分组和报名管理</text>
          </view>
        </view>
      </view>

      <view class="cta-buttons">
        <view class="btn-create" @tap="showCreateModal = true">
          <text class="btn-create-text">创建球队</text>
        </view>
        <view class="btn-join" @tap="showJoinModal = true">
          <text class="btn-join-text">加入球队</text>
        </view>
      </view>
    </view>

    <!-- Has Teams State -->
    <view v-else class="content">
      <view v-for="team in teams" :key="team.id" class="team-card" @tap="goTeamDetail(team.id)">
        <view class="team-avatar">
          <text class="team-avatar-text">⚽</text>
        </view>
        <view class="team-info">
          <text class="team-name">{{ team.name }}</text>
          <text class="team-code">邀请码: {{ team.inviteCode }}</text>
        </view>
        <text class="chevron">›</text>
      </view>

      <view class="cta-buttons">
        <view class="btn-create" @tap="showCreateModal = true">
          <text class="btn-create-text">创建球队</text>
        </view>
        <view class="btn-join" @tap="showJoinModal = true">
          <text class="btn-join-text">加入球队</text>
        </view>
      </view>
    </view>

    <!-- Create Modal -->
    <view v-if="showCreateModal" class="modal-mask" @tap="showCreateModal = false">
      <view class="modal" @tap.stop>
        <text class="modal-title">创建球队</text>
        <text class="modal-desc">为你的球队取一个响亮的名字</text>
        <input class="modal-input" v-model="newTeamName" placeholder="球队名称" placeholder-class="placeholder" />
        <view class="modal-actions">
          <view class="modal-btn-cancel" @tap="showCreateModal = false">
            <text class="modal-btn-cancel-text">取消</text>
          </view>
          <view class="modal-btn-confirm" @tap="handleCreate">
            <text class="modal-btn-confirm-text">确定</text>
          </view>
        </view>
      </view>
    </view>

    <!-- Join Modal -->
    <view v-if="showJoinModal" class="modal-mask" @tap="showJoinModal = false">
      <view class="modal" @tap.stop>
        <text class="modal-title">加入球队</text>
        <text class="modal-desc">输入队长分享的邀请码</text>
        <input class="modal-input" v-model="joinCode" placeholder="输入邀请码" placeholder-class="placeholder" />
        <view class="modal-actions">
          <view class="modal-btn-cancel" @tap="showJoinModal = false">
            <text class="modal-btn-cancel-text">取消</text>
          </view>
          <view class="modal-btn-confirm" @tap="handleJoin">
            <text class="modal-btn-confirm-text">加入</text>
          </view>
        </view>
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
  if (!isLoggedIn()) return
  try {
    const res = await getTeams()
    teams.value = res.teams
  } catch (e) { console.error(e) }
}

async function handleCreate() {
  if (!isLoggedIn()) { uni.navigateTo({ url: '/pages/login/index' }); return }
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
  if (!isLoggedIn()) { uni.navigateTo({ url: '/pages/login/index' }); return }
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
  padding: 100rpx 32rpx 28rpx;

  .nav-title {
    font-size: 42rpx;
    font-weight: 700;
    color: #FFFFFF;
  }
}

.content {
  padding: 0 32rpx;
}

/* ---- Hero Card (No Team State) ---- */
.hero-card {
  background: linear-gradient(135deg, #3B82F6, #4F46E5);
  border-radius: 36rpx;
  padding: 40rpx 32rpx;
  margin-bottom: 32rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
}

.hero-icon-row {
  margin-bottom: 20rpx;
}

.hero-icon {
  font-size: 56rpx;
}

.hero-title {
  font-size: 36rpx;
  font-weight: 700;
  color: #FFFFFF;
  display: block;
  margin-bottom: 12rpx;
}

.hero-subtitle {
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.75);
  line-height: 1.5;
}

/* ---- Feature List ---- */
.feature-list {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
  margin-bottom: 40rpx;
}

.feature-row {
  display: flex;
  align-items: center;
  gap: 20rpx;
  background: #1C2333;
  border-radius: 32rpx;
  padding: 24rpx;
  border: 1rpx solid rgba(255, 255, 255, 0.08);
}

.feature-icon-box {
  width: 64rpx;
  height: 64rpx;
  border-radius: 16rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.feature-icon-1 {
  background: rgba(59, 130, 246, 0.16);
}

.feature-icon-2 {
  background: rgba(255, 165, 2, 0.16);
}

.feature-icon-3 {
  background: rgba(0, 230, 118, 0.16);
}

.feature-icon-text {
  font-size: 28rpx;
}

.feature-text-col {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.feature-title {
  font-size: 28rpx;
  font-weight: 600;
  color: #FFFFFF;
}

.feature-desc {
  font-size: 22rpx;
  color: #8B949E;
  margin-top: 4rpx;
}

/* ---- CTA Buttons ---- */
.cta-buttons {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
  margin-top: 8rpx;
}

.btn-create {
  background: linear-gradient(135deg, #00E676, #00BFA5);
  border-radius: 24rpx;
  height: 96rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.btn-create-text {
  font-size: 30rpx;
  font-weight: 600;
  color: #0D1117;
}

.btn-join {
  background: transparent;
  border: 2rpx solid #00E676;
  border-radius: 24rpx;
  height: 96rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.btn-join-text {
  font-size: 30rpx;
  font-weight: 600;
  color: #00E676;
}

/* ---- Team Cards (Has Team State) ---- */
.team-card {
  background: #1C2333;
  border-radius: 32rpx;
  padding: 24rpx 28rpx;
  margin-bottom: 16rpx;
  display: flex;
  align-items: center;
  border: 1rpx solid rgba(255, 255, 255, 0.08);
}

.team-avatar {
  width: 88rpx;
  height: 88rpx;
  border-radius: 50%;
  background: #242D3D;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  margin-right: 20rpx;
}

.team-avatar-text {
  font-size: 40rpx;
}

.team-info {
  flex: 1;

  .team-name {
    font-size: 30rpx;
    font-weight: 600;
    color: #FFFFFF;
    display: block;
  }

  .team-code {
    font-size: 24rpx;
    color: #8B949E;
    display: block;
    margin-top: 6rpx;
  }
}

.chevron {
  font-size: 40rpx;
  color: #30363D;
}

/* ---- Modal ---- */
.modal-mask {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.65);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 999;
}

.modal {
  width: 80%;
  background: #1C2333;
  border-radius: 32rpx;
  padding: 40rpx;
  border: 1rpx solid rgba(255, 255, 255, 0.08);
}

.modal-title {
  font-size: 34rpx;
  font-weight: 700;
  color: #FFFFFF;
  display: block;
  margin-bottom: 8rpx;
}

.modal-desc {
  font-size: 24rpx;
  color: #8B949E;
  display: block;
  margin-bottom: 28rpx;
}

.modal-input {
  background: #0D1117;
  border-radius: 24rpx;
  padding: 24rpx 28rpx;
  font-size: 28rpx;
  color: #FFFFFF;
  margin-bottom: 28rpx;
  border: 1rpx solid rgba(255, 255, 255, 0.08);
}

.modal-actions {
  display: flex;
  gap: 16rpx;
}

.modal-btn-cancel {
  flex: 1;
  height: 80rpx;
  border-radius: 24rpx;
  background: #242D3D;
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-btn-cancel-text {
  font-size: 28rpx;
  font-weight: 600;
  color: #8B949E;
}

.modal-btn-confirm {
  flex: 1;
  height: 80rpx;
  border-radius: 24rpx;
  background: linear-gradient(135deg, #00E676, #00BFA5);
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-btn-confirm-text {
  font-size: 28rpx;
  font-weight: 600;
  color: #0D1117;
}

.placeholder {
  color: #545d68;
}
</style>
