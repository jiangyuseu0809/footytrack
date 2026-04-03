<template>
  <view class="page">
    <!-- Header -->
    <view class="header">
      <text class="header-title">球队</text>
    </view>

    <!-- No Team State: Hero + CTA -->
    <scroll-view v-if="teams.length === 0" scroll-y class="scroll-area">
      <view class="section">
        <view class="hero-card">
          <view class="hero-icon-row">
            <text class="hero-icon">⚽</text>
          </view>
          <text class="hero-title">加入或创建球队</text>
          <text class="hero-subtitle">组建你的球队，一起追踪训练数据，互相比拼提升</text>
        </view>
      </view>

      <view class="section">
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
      </view>

      <view class="section section--last">
        <view class="btn-create" @tap="showCreateModal = true">
          <text class="btn-create-text">创建球队</text>
        </view>
        <view class="btn-join" @tap="showJoinModal = true">
          <text class="btn-join-text">加入球队</text>
        </view>
      </view>
    </scroll-view>

    <!-- Has Teams State -->
    <scroll-view v-else scroll-y class="scroll-area">
      <view class="section">
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
      </view>

      <view class="section section--last">
        <view class="btn-create" @tap="showCreateModal = true">
          <text class="btn-create-text">创建球队</text>
        </view>
        <view class="btn-join" @tap="showJoinModal = true">
          <text class="btn-join-text">加入球队</text>
        </view>
      </view>
    </scroll-view>

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
  display: flex;
  flex-direction: column;
}

.scroll-area {
  flex: 1;
  height: calc(100vh - 170rpx);
}

// ============================================================
// Header
// ============================================================
.header {
  background: $cardBg;
  padding: 100rpx 32rpx 24rpx;
  border-bottom: $border;
}

.header-title {
  font-size: 40rpx;
  font-weight: 700;
  color: $textPrimary;
  text-align: center;
}

// ============================================================
// Sections
// ============================================================
.section {
  padding: 24rpx 32rpx 0;
}

.section--last {
  padding-bottom: 160rpx;
}

// ============================================================
// Hero Card (No Team State)
// ============================================================
.hero-card {
  background: linear-gradient(135deg, $green, $greenDark);
  border-radius: 32rpx;
  padding: 40rpx 32rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  box-shadow: 0 8rpx 32rpx rgba(7, 193, 96, 0.2);
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
  color: $textPrimary;
  display: block;
  margin-bottom: 12rpx;
}

.hero-subtitle {
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.85);
  line-height: 1.5;
}

// ============================================================
// Feature List
// ============================================================
.feature-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.feature-row {
  display: flex;
  align-items: center;
  gap: 20rpx;
  background: $cardBg;
  border-radius: 32rpx;
  padding: 24rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.feature-icon-box {
  width: 64rpx;
  height: 64rpx;
  border-radius: 16rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.2);
}

.feature-icon-1 { background: linear-gradient(135deg, #60a5fa, #3b82f6); }
.feature-icon-2 { background: linear-gradient(135deg, #facc15, #f97316); }
.feature-icon-3 { background: linear-gradient(135deg, $green, $greenDark); }

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
  color: $textPrimary;
}

.feature-desc {
  font-size: 22rpx;
  color: $textSecondary;
  margin-top: 4rpx;
}

// ============================================================
// CTA Buttons
// ============================================================
.btn-create {
  background: linear-gradient(90deg, $green, $greenDark);
  border-radius: 100rpx;
  height: 96rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 24rpx rgba(7, 193, 96, 0.3);
}

.btn-create-text {
  font-size: 30rpx;
  font-weight: 600;
  color: $textPrimary;
}

.btn-join {
  margin-top: 16rpx;
  background: $cardBg;
  border: 2rpx solid $green;
  border-radius: 100rpx;
  height: 96rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.btn-join-text {
  font-size: 30rpx;
  font-weight: 600;
  color: $green;
}

// ============================================================
// Team Cards (Has Team State)
// ============================================================
.team-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 24rpx 28rpx;
  margin-bottom: 16rpx;
  display: flex;
  align-items: center;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.team-avatar {
  width: 88rpx;
  height: 88rpx;
  border-radius: 50%;
  background: #252525;
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
}

.team-name {
  font-size: 30rpx;
  font-weight: 600;
  color: $textPrimary;
  display: block;
}

.team-code {
  font-size: 24rpx;
  color: $textSecondary;
  display: block;
  margin-top: 6rpx;
}

.chevron {
  font-size: 40rpx;
  color: $textMuted;
  font-weight: 300;
}

// ============================================================
// Modal
// ============================================================
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
  background: $cardBg;
  border-radius: 32rpx;
  padding: 40rpx;
  border: $border;
}

.modal-title {
  font-size: 34rpx;
  font-weight: 700;
  color: $textPrimary;
  display: block;
  margin-bottom: 8rpx;
}

.modal-desc {
  font-size: 24rpx;
  color: $textSecondary;
  display: block;
  margin-bottom: 28rpx;
}

.modal-input {
  background: #252525;
  border-radius: 20rpx;
  padding: 24rpx 28rpx;
  font-size: 28rpx;
  color: $textPrimary;
  margin-bottom: 28rpx;
  border: 1rpx solid #333;
}

.modal-actions {
  display: flex;
  gap: 16rpx;
}

.modal-btn-cancel {
  flex: 1;
  height: 80rpx;
  border-radius: 100rpx;
  background: #252525;
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-btn-cancel-text {
  font-size: 28rpx;
  font-weight: 600;
  color: $textSecondary;
}

.modal-btn-confirm {
  flex: 1;
  height: 80rpx;
  border-radius: 100rpx;
  background: linear-gradient(90deg, $green, $greenDark);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4rpx 16rpx rgba(7, 193, 96, 0.3);
}

.modal-btn-confirm-text {
  font-size: 28rpx;
  font-weight: 600;
  color: $textPrimary;
}

.placeholder {
  color: $textMuted;
}
</style>
