<template>
  <view class="page">
    <!-- Header -->
    <view class="header">
      <text class="header-title">圈子</text>
    </view>

    <!-- Empty State -->
    <scroll-view v-if="loaded && circles.length === 0" scroll-y class="scroll-area">
      <view class="empty-state">
        <view class="empty-icon-wrap">
          <text class="empty-icon">👥</text>
        </view>
        <text class="empty-title">欢迎来到圈子</text>
        <text class="empty-desc">创建你的第一个运动圈子&#10;邀请好友一起PK运动数据</text>
        <view class="empty-btn" @tap="showCreateModal = true">
          <text class="empty-btn-text">+ 创建圈子</text>
        </view>
        <view class="empty-btn-join" @tap="showJoinModal = true">
          <text class="empty-btn-join-text">加入圈子</text>
        </view>
      </view>
    </scroll-view>

    <!-- Main Content -->
    <scroll-view v-else-if="loaded && circles.length > 0" scroll-y class="scroll-area">
      <view class="content-fade" :class="{ 'content-fade--visible': contentVisible }">
      <!-- Circle Info Card -->
      <view v-if="selectedCircle" class="section">
        <view class="info-card" :style="{ background: getCircleGradient(selectedCircle.id) }">
          <view class="info-deco info-deco--tr"></view>
          <view class="info-deco info-deco--bl"></view>
          <view class="info-content">
            <view class="info-header">
              <view class="info-header-left">
                <view class="info-avatar" @tap.stop="openAvatarPicker">
                  <image v-if="selectedCircle.avatarUrl" :src="selectedCircle.avatarUrl" class="info-avatar-img" mode="aspectFill" />
                  <text v-else class="info-avatar-emoji">⚽</text>
                </view>
                <view class="info-title-col">
                  <text class="info-name">{{ selectedCircle.name }}</text>
                  <text class="info-subtitle">{{ timePeriodLabel }}运动数据PK</text>
                </view>
              </view>
              <view v-if="circles.length > 1" class="info-switch-btn" @tap.stop="toggleCircleList">
                <text class="info-switch-icon">⇄</text>
              </view>
            </view>
            <view class="info-stats">
              <view class="info-stat-badge">
                <text class="info-stat-label">成员</text>
                <text class="info-stat-value">{{ selectedCircle.memberCount }}</text>
              </view>
              <view class="info-stat-badge">
                <text class="info-stat-label">{{ timePeriodLabel }}活跃</text>
                <text class="info-stat-value">{{ activeCount }}</text>
              </view>
              <view class="info-stat-badge">
                <text class="info-stat-label">邀请码</text>
                <text class="info-stat-value" @tap.stop="copyCode">{{ selectedCircle.inviteCode }}</text>
              </view>
            </view>
            <view class="share-btn" @tap="showInviteInfo = true">
              <view class="share-btn-icon">
                <image src="/static/icons/share.svg" class="share-btn-svg" />
              </view>
              <text class="share-btn-text">邀请好友加入</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Stats Filter -->
      <view class="section">
        <view class="filter-card">
          <!-- Time Period Selector -->
          <view class="filter-period-row">
            <text class="filter-period-label">排行榜</text>
            <view class="filter-period-tabs">
              <view
                class="filter-period-tab"
                :class="{ 'filter-period-tab--active': timePeriod === 'day' }"
                @tap="switchPeriod('day')"
              ><text class="filter-period-text" :class="{ 'filter-period-text--active': timePeriod === 'day' }">今日</text></view>
              <view
                class="filter-period-tab"
                :class="{ 'filter-period-tab--active': timePeriod === 'week' }"
                @tap="switchPeriod('week')"
              ><text class="filter-period-text" :class="{ 'filter-period-text--active': timePeriod === 'week' }">本周</text></view>
              <view
                class="filter-period-tab"
                :class="{ 'filter-period-tab--active': timePeriod === 'month' }"
                @tap="switchPeriod('month')"
              ><text class="filter-period-text" :class="{ 'filter-period-text--active': timePeriod === 'month' }">本月</text></view>
              <view
                class="filter-period-tab"
                :class="{ 'filter-period-tab--active': timePeriod === 'year' }"
                @tap="switchPeriod('year')"
              ><text class="filter-period-text" :class="{ 'filter-period-text--active': timePeriod === 'year' }">本年</text></view>
            </view>
          </view>
          <text class="filter-title">{{ timePeriodLabel }}数据排行</text>
          <view class="filter-grid">
            <view
              class="filter-btn"
              :class="{ 'filter-btn--active filter-btn--distance': selectedStat === 'distance' }"
              @tap="selectedStat = 'distance'"
            >
              <text class="filter-btn-label">距离</text>
            </view>
            <view
              class="filter-btn"
              :class="{ 'filter-btn--active filter-btn--calories': selectedStat === 'calories' }"
              @tap="selectedStat = 'calories'"
            >
              <text class="filter-btn-label">热量</text>
            </view>
            <view
              class="filter-btn"
              :class="{ 'filter-btn--active filter-btn--sprints': selectedStat === 'sprints' }"
              @tap="selectedStat = 'sprints'"
            >
              <text class="filter-btn-label">冲刺</text>
            </view>
            <view
              class="filter-btn"
              :class="{ 'filter-btn--active filter-btn--duration': selectedStat === 'duration' }"
              @tap="selectedStat = 'duration'"
            >
              <text class="filter-btn-label">时长</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Ranking List -->
      <view class="section section--last">
        <view v-for="(member, index) in rankedMembers" :key="member.userUid" class="rank-card">
          <view class="rank-row">
            <!-- Rank Badge -->
            <view class="rank-badge" :class="getRankClass(index + 1)">
              <text v-if="index < 3" class="rank-trophy">🏆</text>
              <text v-else class="rank-number">{{ index + 1 }}</text>
            </view>

            <!-- Avatar -->
            <view class="rank-avatar">
              <text class="rank-avatar-text">{{ member.nickname?.charAt(0) || '?' }}</text>
            </view>

            <!-- Info -->
            <view class="rank-info">
              <text class="rank-name">{{ member.nickname }}</text>
              <view class="rank-sub-stats">
                <text class="rank-sub">{{ formatDistance(member.totalDistanceMeters) }}</text>
                <text class="rank-sub">{{ Math.round(member.totalCalories) }} kcal</text>
              </view>
            </view>

            <!-- Stat Value -->
            <view class="rank-value-col">
              <text class="rank-value">{{ getStatValue(member) }}</text>
              <text class="rank-unit">{{ getStatUnit() }}</text>
            </view>
          </view>

          <!-- Progress Bar -->
          <view class="rank-bar-bg">
            <view class="rank-bar" :style="{ width: getBarWidth(member) + '%' }"></view>
          </view>
        </view>

        <!-- No members -->
        <view v-if="rankedMembers.length === 0" class="empty-rank">
          <text class="empty-rank-text">暂无{{ timePeriodLabel }}数据</text>
        </view>

        <!-- Leave circle -->
        <view v-if="selectedCircle" class="leave-btn" @tap="handleLeave">
          <text class="leave-btn-text">退出圈子</text>
        </view>
      </view>
      </view>
    </scroll-view>

    <!-- FAB Popup -->
    <view v-if="showFabMenu" class="fab-popup-mask" @tap="closeFabMenu"></view>
    <view v-if="showFabMenu" class="fab-popup" :class="{ 'fab-popup--show': fabMenuVisible }" @tap.stop>
      <view class="fab-popup-item" @tap="fabAction('join')">
        <view class="fab-popup-icon fab-popup-icon--join">
          <image src="/static/icons/fab-join.svg" class="fab-popup-icon-svg" />
        </view>
        <view class="fab-popup-item-info">
          <text class="fab-popup-item-title">加入圈子</text>
          <text class="fab-popup-item-desc">输入邀请码加入足球圈</text>
        </view>
      </view>
      <view class="fab-popup-item" @tap="fabAction('create')">
        <view class="fab-popup-icon fab-popup-icon--create">
          <image src="/static/icons/fab-create.svg" class="fab-popup-icon-svg" />
        </view>
        <view class="fab-popup-item-info">
          <text class="fab-popup-item-title">新建圈子</text>
          <text class="fab-popup-item-desc">创建你的足球圈</text>
        </view>
      </view>
    </view>

    <!-- FAB: Create Circle -->
    <view v-if="loaded && circles.length > 0" class="fab" @tap="toggleFabMenu">
      <text class="fab-icon" :class="{ 'fab-icon--open': showFabMenu }">+</text>
    </view>

    <!-- Create Modal -->
    <view v-if="showCreateModal" class="modal-mask" @tap="showCreateModal = false">
      <view class="modal" @tap.stop>
        <text class="modal-title">创建圈子</text>
        <text class="modal-desc">为圈子取个名字，创建后可设置头像</text>
        <input class="modal-input" v-model="newCircleName" placeholder="圈子名称" placeholder-class="placeholder" maxlength="20" />
        <view class="modal-actions">
          <view class="modal-btn-cancel" @tap="showCreateModal = false">
            <text class="modal-btn-cancel-text">取消</text>
          </view>
          <view class="modal-btn-confirm" @tap="handleCreate">
            <text class="modal-btn-confirm-text">创建</text>
          </view>
        </view>
      </view>
    </view>

    <!-- Join Modal -->
    <view v-if="showJoinModal" class="modal-mask" @tap="showJoinModal = false">
      <view class="modal" @tap.stop>
        <text class="modal-title">加入圈子</text>
        <text class="modal-desc">输入好友分享的邀请码</text>
        <input class="modal-input" v-model="joinCode" placeholder="输入邀请码" placeholder-class="placeholder" maxlength="6" />
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

    <!-- Invite Info Modal -->
    <view v-if="showInviteInfo" class="modal-mask" @tap="showInviteInfo = false">
      <view class="modal" @tap.stop>
        <text class="modal-title">邀请好友</text>
        <text class="modal-desc">分享以下邀请码给好友，即可加入圈子</text>
        <view class="invite-code-box">
          <text class="invite-code">{{ selectedCircle?.inviteCode }}</text>
        </view>
        <view class="modal-actions">
          <view class="modal-btn-confirm modal-btn-full" @tap="copyCode(); showInviteInfo = false">
            <text class="modal-btn-confirm-text">复制邀请码</text>
          </view>
        </view>
      </view>
    </view>

    <!-- Circle Switcher Popup (floating from top-right) -->
    <view v-if="showCircleList" class="switcher-mask" @tap="showCircleList = false">
      <view class="switcher-popup" :class="{ 'switcher-popup--show': circleListVisible }" @tap.stop>
        <view class="switcher-header">
          <text class="switcher-title">切换圈子</text>
        </view>
        <scroll-view scroll-y class="switcher-list">
          <view
            v-for="circle in circles"
            :key="circle.id"
            class="switcher-item"
            :class="{ 'switcher-item--active': circle.id === selectedCircleId }"
            @tap.stop="selectCircle(circle.id)"
          >
            <view class="switcher-avatar" :style="{ background: circle.avatarUrl ? '' : getCircleGradient(circle.id) }">
              <image v-if="circle.avatarUrl" :src="circle.avatarUrl" class="switcher-avatar-img" mode="aspectFill" />
              <text v-else class="switcher-avatar-icon">⚽</text>
            </view>
            <view class="switcher-info">
              <text class="switcher-name">{{ circle.name }}</text>
              <text class="switcher-count">{{ circle.memberCount }} 位成员</text>
            </view>
            <text v-if="circle.id === selectedCircleId" class="switcher-check">✓</text>
          </view>
        </scroll-view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import {
  getCircles, createCircle, joinCircle, getCircleDetail, leaveCircle, uploadCircleAvatar,
  ensureLogin, getUid, type Circle, type CircleMember,
} from '../../utils/api'

const STORAGE_KEY = 'selected_circle_id'
const CACHE_CIRCLES = 'cache_circles'
const CACHE_MEMBERS = 'cache_circle_members'

const loading = ref(false)
const loaded = ref(false)
const circles = ref<Circle[]>([])
const selectedCircleId = ref(uni.getStorageSync(STORAGE_KEY) || '')
const members = ref<CircleMember[]>([])

// Restore from cache immediately
const cachedCircles = uni.getStorageSync(CACHE_CIRCLES)
const cachedMembers = uni.getStorageSync(CACHE_MEMBERS)
if (cachedCircles && cachedCircles.length > 0) {
  circles.value = cachedCircles
  if (cachedMembers) members.value = cachedMembers
  if (!selectedCircleId.value || !cachedCircles.find((c: Circle) => c.id === selectedCircleId.value)) {
    selectedCircleId.value = cachedCircles[0].id
  }
  loaded.value = true
}
const showCircleList = ref(false)
const circleListVisible = ref(false)
const contentVisible = ref(true)
const showCreateModal = ref(false)
const showJoinModal = ref(false)
const showInviteInfo = ref(false)
const showFabMenu = ref(false)
const fabMenuVisible = ref(false)
const newCircleName = ref('')
const joinCode = ref('')
const selectedStat = ref<'distance' | 'calories' | 'sprints' | 'duration'>('distance')
const timePeriod = ref<'day' | 'week' | 'month' | 'year'>('week')

// Persist selected circle ID
watch(selectedCircleId, (val) => {
  if (val) {
    uni.setStorageSync(STORAGE_KEY, val)
  } else {
    uni.removeStorageSync(STORAGE_KEY)
  }
})

const timePeriodLabel = computed(() => {
  switch (timePeriod.value) {
    case 'day': return '今日'
    case 'week': return '本周'
    case 'month': return '本月'
    case 'year': return '本年'
  }
})

const selectedCircle = computed(() => circles.value.find(c => c.id === selectedCircleId.value))
const activeCount = computed(() => members.value.filter(m => m.totalDistanceMeters > 0 || m.totalCalories > 0).length)
const isOwner = computed(() => selectedCircle.value && selectedCircle.value.createdBy === getUid())

const gradients = [
  'linear-gradient(135deg, #3b82f6, #8b5cf6)',
  'linear-gradient(135deg, #f97316, #ef4444)',
  'linear-gradient(135deg, #07c160, #05a850)',
  'linear-gradient(135deg, #ec4899, #f97316)',
  'linear-gradient(135deg, #8b5cf6, #ec4899)',
  'linear-gradient(135deg, #06b6d4, #3b82f6)',
]

function getCircleGradient(circleId: string): string {
  let hash = 0
  for (let i = 0; i < circleId.length; i++) {
    hash = ((hash << 5) - hash) + circleId.charCodeAt(i)
    hash |= 0
  }
  return gradients[Math.abs(hash) % gradients.length]
}

const rankedMembers = computed(() => {
  return [...members.value].sort((a, b) => getStatRaw(b) - getStatRaw(a))
})

function getStatRaw(m: CircleMember): number {
  switch (selectedStat.value) {
    case 'distance': return m.totalDistanceMeters
    case 'calories': return m.totalCalories
    case 'sprints': return m.sprintCount
    case 'duration': return m.totalDurationMinutes
  }
}

function getStatValue(m: CircleMember): string {
  switch (selectedStat.value) {
    case 'distance': return (m.totalDistanceMeters / 1000).toFixed(1)
    case 'calories': return Math.round(m.totalCalories).toString()
    case 'sprints': return m.sprintCount.toString()
    case 'duration': return m.totalDurationMinutes.toString()
  }
}

function getStatUnit(): string {
  switch (selectedStat.value) {
    case 'distance': return 'km'
    case 'calories': return 'kcal'
    case 'sprints': return '次'
    case 'duration': return '分钟'
  }
}

function formatDistance(meters: number): string {
  if (meters >= 1000) return (meters / 1000).toFixed(1) + ' km'
  return Math.round(meters) + ' m'
}

function getBarWidth(m: CircleMember): number {
  const max = rankedMembers.value.length > 0 ? getStatRaw(rankedMembers.value[0]) : 1
  if (max === 0) return 0
  return Math.round((getStatRaw(m) / max) * 100)
}

function getRankClass(rank: number): string {
  if (rank === 1) return 'rank-badge--gold'
  if (rank === 2) return 'rank-badge--silver'
  if (rank === 3) return 'rank-badge--bronze'
  return ''
}

function toggleCircleList() {
  if (showCircleList.value) {
    circleListVisible.value = false
    setTimeout(() => { showCircleList.value = false }, 200)
  } else {
    showCircleList.value = true
    nextTick(() => { circleListVisible.value = true })
  }
}

function toggleFabMenu() {
  if (showFabMenu.value) {
    closeFabMenu()
  } else {
    showFabMenu.value = true
    nextTick(() => { fabMenuVisible.value = true })
  }
}

function closeFabMenu() {
  fabMenuVisible.value = false
  setTimeout(() => { showFabMenu.value = false }, 200)
}

function fabAction(type: 'join' | 'create') {
  closeFabMenu()
  setTimeout(() => {
    if (type === 'join') showJoinModal.value = true
    else showCreateModal.value = true
  }, 200)
}

function selectCircle(id: string) {
  if (id === selectedCircleId.value) {
    circleListVisible.value = false
    setTimeout(() => { showCircleList.value = false }, 200)
    return
  }
  // Fade out content
  contentVisible.value = false
  circleListVisible.value = false
  setTimeout(() => {
    showCircleList.value = false
    selectedCircleId.value = id
    loadCircleDetail(id).then(() => {
      // Fade in content
      nextTick(() => { contentVisible.value = true })
    })
  }, 200)
}

function switchPeriod(period: 'day' | 'week' | 'month' | 'year') {
  timePeriod.value = period
  if (selectedCircleId.value) loadCircleDetail(selectedCircleId.value)
}

function copyCode() {
  if (!selectedCircle.value) return
  uni.setClipboardData({
    data: selectedCircle.value.inviteCode,
    success: () => uni.showToast({ title: '已复制邀请码', icon: 'success' }),
  })
}

function openAvatarPicker() {
  if (!isOwner.value || !selectedCircle.value) return
  uni.chooseImage({
    count: 1,
    sizeType: ['compressed'],
    sourceType: ['album', 'camera'],
    success: async (res) => {
      const tempFilePath = res.tempFilePaths[0]
      try {
        uni.showLoading({ title: '上传中...' })
        const updated = await uploadCircleAvatar(selectedCircle.value!.id, tempFilePath)
        const idx = circles.value.findIndex(c => c.id === updated.id)
        if (idx >= 0) circles.value[idx].avatarUrl = updated.avatarUrl
        uni.hideLoading()
        uni.showToast({ title: '头像已更新', icon: 'success' })
      } catch (e: any) {
        uni.hideLoading()
        uni.showToast({ title: e.message, icon: 'none' })
      }
    },
  })
}

async function loadData() {
  await ensureLogin()
  loading.value = true
  try {
    const res = await getCircles()
    circles.value = res.circles
    uni.setStorageSync(CACHE_CIRCLES, res.circles)
    if (res.circles.length > 0) {
      if (!selectedCircleId.value || !res.circles.find(c => c.id === selectedCircleId.value)) {
        selectedCircleId.value = res.circles[0].id
      }
      await loadCircleDetail(selectedCircleId.value)
    }
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
    loaded.value = true
  }
}

async function loadCircleDetail(circleId: string) {
  try {
    const res = await getCircleDetail(circleId, timePeriod.value)
    members.value = res.members
    uni.setStorageSync(CACHE_MEMBERS, res.members)
    const idx = circles.value.findIndex(c => c.id === circleId)
    if (idx >= 0) {
      circles.value[idx].memberCount = res.circle.memberCount
      circles.value[idx].avatarUrl = res.circle.avatarUrl
    }
  } catch (e) {
    console.error(e)
  }
}

async function handleCreate() {
  if (!newCircleName.value.trim()) return
  try {
    const circle = await createCircle(newCircleName.value.trim())
    showCreateModal.value = false
    newCircleName.value = ''
    await loadData()
    selectedCircleId.value = circle.id
    uni.showToast({ title: '创建成功', icon: 'success' })
  } catch (e: any) {
    uni.showToast({ title: e.message, icon: 'none' })
  }
}

async function handleJoin() {
  if (!joinCode.value.trim()) return
  try {
    const circle = await joinCircle(joinCode.value.trim())
    showJoinModal.value = false
    joinCode.value = ''
    await loadData()
    selectedCircleId.value = circle.id
    uni.showToast({ title: '加入成功', icon: 'success' })
  } catch (e: any) {
    uni.showToast({ title: e.message, icon: 'none' })
  }
}

async function handleLeave() {
  if (!selectedCircle.value) return
  uni.showModal({
    title: '退出圈子',
    content: `确定要退出「${selectedCircle.value.name}」吗？`,
    confirmText: '退出',
    confirmColor: '#ef4444',
    success: async (res) => {
      if (!res.confirm) return
      try {
        await leaveCircle(selectedCircleId.value)
        selectedCircleId.value = ''
        members.value = []
        await loadData()
        uni.showToast({ title: '已退出', icon: 'success' })
      } catch (e: any) {
        uni.showToast({ title: e.message, icon: 'none' })
      }
    },
  })
}

onShow(() => { loadData() })
</script>

<style lang="scss" scoped>
$pageBg: #0a0a0a;
$cardBg: #1a1a1a;
$cardBgLight: #252525;
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
  height: calc(100vh - 200rpx);
}

// ============================================================
// Header
// ============================================================
.header {
  background: $cardBg;
  padding: 120rpx 32rpx 28rpx;
  border-bottom: $border;
}

.header-title {
  font-size: 34rpx;
  font-weight: 700;
  color: $textPrimary;
  display: block;
  text-align: center;
}

// ============================================================
// FAB (Floating Action Button)
// ============================================================
.fab {
  position: fixed;
  right: 40rpx;
  bottom: calc(env(safe-area-inset-bottom) + 40rpx);
  width: 96rpx;
  height: 96rpx;
  border-radius: 50%;
  background: linear-gradient(135deg, $green, $greenDark);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 24rpx rgba(7, 193, 96, 0.4);
  z-index: 100;
}

.fab-icon {
  font-size: 48rpx;
  font-weight: 300;
  color: $textPrimary;
  margin-top: -4rpx;
  transition: transform 0.25s ease;
}

.fab-icon--open {
  transform: rotate(45deg);
}

// ============================================================
// FAB Popup
// ============================================================
.fab-popup-mask {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 99;
}

.fab-popup {
  position: fixed;
  right: 40rpx;
  bottom: calc(env(safe-area-inset-bottom) + 156rpx);
  width: 400rpx;
  background: $cardBg;
  border-radius: 24rpx;
  padding: 12rpx;
  border: $border;
  box-shadow: 0 16rpx 48rpx rgba(0, 0, 0, 0.5);
  z-index: 100;
  opacity: 0;
  transform: translateY(16rpx) scale(0.95);
  transform-origin: bottom right;
  transition: opacity 0.2s ease, transform 0.2s ease;
}

.fab-popup--show {
  opacity: 1;
  transform: translateY(0) scale(1);
}

.fab-popup-item {
  display: flex;
  align-items: center;
  padding: 20rpx;
  border-radius: 20rpx;

  &:active {
    background: $cardBgLight;
  }
}

.fab-popup-icon {
  width: 72rpx;
  height: 72rpx;
  border-radius: 16rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 20rpx;
  flex-shrink: 0;
}

.fab-popup-icon--join {
  background: rgba(59, 130, 246, 0.15);
}

.fab-popup-icon--create {
  background: rgba(7, 193, 96, 0.15);
}

.fab-popup-icon-svg {
  width: 40rpx;
  height: 40rpx;
}

.fab-popup-item-info {
  flex: 1;
  min-width: 0;
}

.fab-popup-item-title {
  font-size: 28rpx;
  font-weight: 600;
  color: $textPrimary;
  display: block;
  margin-bottom: 2rpx;
}

.fab-popup-item-desc {
  font-size: 22rpx;
  color: $textSecondary;
  display: block;
}

// ============================================================
// Sections
// ============================================================
.section {
  padding: 20rpx 32rpx 0;
}

.section--last {
  padding-bottom: 160rpx;
}

// ============================================================
// Empty State
// ============================================================
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 120rpx 48rpx 160rpx;
  text-align: center;
}

.empty-icon-wrap {
  width: 200rpx;
  height: 200rpx;
  border-radius: 50%;
  background: linear-gradient(135deg, $cardBg, $cardBgLight);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 40rpx;
  border: $border;
  box-shadow: 0 8rpx 32rpx rgba(0, 0, 0, 0.4);
}

.empty-icon {
  font-size: 80rpx;
}

.empty-title {
  font-size: 40rpx;
  font-weight: 700;
  color: $textPrimary;
  margin-bottom: 16rpx;
}

.empty-desc {
  font-size: 28rpx;
  color: $textSecondary;
  line-height: 1.6;
  margin-bottom: 48rpx;
}

.empty-btn {
  width: 100%;
  max-width: 480rpx;
  height: 96rpx;
  border-radius: 100rpx;
  background: linear-gradient(90deg, $green, $greenDark);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 24rpx rgba(7, 193, 96, 0.3);
  margin-bottom: 16rpx;
}

.empty-btn-text {
  font-size: 30rpx;
  font-weight: 600;
  color: $textPrimary;
}

.empty-btn-join {
  width: 100%;
  max-width: 480rpx;
  height: 96rpx;
  border-radius: 100rpx;
  background: $cardBg;
  border: 2rpx solid $green;
  display: flex;
  align-items: center;
  justify-content: center;
}

.empty-btn-join-text {
  font-size: 30rpx;
  font-weight: 600;
  color: $green;
}

// ============================================================
// Info Card (gradient hero)
// ============================================================
.info-card {
  border-radius: 32rpx;
  padding: 40rpx 32rpx;
  position: relative;
  overflow: hidden;
  box-shadow: 0 8rpx 32rpx rgba(0, 0, 0, 0.3);
}

.info-deco {
  position: absolute;
  border-radius: 50%;
}

.info-deco--tr {
  top: -80rpx;
  right: -80rpx;
  width: 200rpx;
  height: 200rpx;
  background: rgba(255, 255, 255, 0.1);
}

.info-deco--bl {
  bottom: -60rpx;
  left: -60rpx;
  width: 160rpx;
  height: 160rpx;
  background: rgba(0, 0, 0, 0.1);
}

.info-content {
  position: relative;
  z-index: 1;
}

.info-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 24rpx;
}

.info-header-left {
  display: flex;
  align-items: center;
  flex: 1;
  min-width: 0;
}

.info-title-col {
  flex: 1;
  min-width: 0;
}

.info-name {
  font-size: 40rpx;
  font-weight: 700;
  color: $textPrimary;
  display: block;
  margin-bottom: 4rpx;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.info-subtitle {
  font-size: 24rpx;
  color: rgba(255, 255, 255, 0.8);
}

.info-avatar {
  width: 80rpx;
  height: 80rpx;
  border-radius: 20rpx;
  background: rgba(255, 255, 255, 0.2);
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  overflow: hidden;
  flex-shrink: 0;
  margin-right: 20rpx;
}

.info-avatar-img {
  width: 80rpx;
  height: 80rpx;
  border-radius: 20rpx;
}

.info-avatar-emoji {
  font-size: 40rpx;
}

.info-switch-btn {
  width: 72rpx;
  height: 72rpx;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.2);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  margin-left: 16rpx;
}

.info-switch-icon {
  font-size: 32rpx;
  color: $textPrimary;
}

// ============================================================
// Circle Switcher Popup
// ============================================================
.switcher-mask {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 998;
}

.switcher-popup {
  position: fixed;
  top: 180rpx;
  right: 32rpx;
  width: 480rpx;
  background: $cardBg;
  border-radius: 24rpx;
  border: $border;
  box-shadow: 0 16rpx 48rpx rgba(0, 0, 0, 0.5);
  z-index: 999;
  opacity: 0;
  transform: translateY(-16rpx) scale(0.95);
  transform-origin: top right;
  transition: opacity 0.2s ease, transform 0.2s ease;
  overflow: hidden;
}

.switcher-popup--show {
  opacity: 1;
  transform: translateY(0) scale(1);
}

.switcher-header {
  padding: 28rpx 28rpx 20rpx;
  border-bottom: $border;
}

.switcher-title {
  font-size: 28rpx;
  font-weight: 700;
  color: $textPrimary;
}

.switcher-list {
  max-height: 480rpx;
  padding: 12rpx 0;
}

.switcher-item {
  display: flex;
  align-items: center;
  padding: 16rpx 28rpx;
  border-radius: 0;
  margin-bottom: 0;
}

.switcher-item--active {
  background: rgba(7, 193, 96, 0.08);
}

.switcher-avatar {
  width: 64rpx;
  height: 64rpx;
  border-radius: 16rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 16rpx;
  flex-shrink: 0;
  overflow: hidden;
}

.switcher-avatar-img {
  width: 64rpx;
  height: 64rpx;
  border-radius: 16rpx;
}

.switcher-avatar-icon {
  font-size: 28rpx;
}

.switcher-info {
  flex: 1;
  min-width: 0;
}

.switcher-name {
  font-size: 26rpx;
  font-weight: 600;
  color: $textPrimary;
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.switcher-count {
  font-size: 22rpx;
  color: $textMuted;
  display: block;
  margin-top: 2rpx;
}

.switcher-check {
  font-size: 28rpx;
  color: $green;
  font-weight: 700;
  flex-shrink: 0;
  margin-left: 12rpx;
}

// ============================================================
// Content Fade Transition
// ============================================================
.content-fade {
  opacity: 0;
  transition: opacity 0.25s ease;
}

.content-fade--visible {
  opacity: 1;
}

.info-stats {
  display: flex;
  gap: 16rpx;
  margin-bottom: 24rpx;
}

.info-stat-badge {
  background: rgba(255, 255, 255, 0.2);
  border-radius: 20rpx;
  padding: 12rpx 20rpx;
}

.info-stat-label {
  font-size: 20rpx;
  color: rgba(255, 255, 255, 0.7);
  display: block;
}

.info-stat-value {
  font-size: 28rpx;
  font-weight: 700;
  color: $textPrimary;
  display: block;
  margin-top: 2rpx;
}

.share-btn {
  background: linear-gradient(135deg, $green, $greenDark);
  border-radius: 100rpx;
  padding: 24rpx 40rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 14rpx;
  box-shadow: 0 8rpx 32rpx rgba(7, 193, 96, 0.3);
}

.share-btn-icon {
  width: 36rpx;
  height: 36rpx;
  flex-shrink: 0;
}

.share-btn-svg {
  width: 36rpx;
  height: 36rpx;
}

.share-btn-text {
  font-size: 30rpx;
  font-weight: 500;
  color: $textPrimary;
}

// ============================================================
// Filter Card
// ============================================================
.filter-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 28rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.filter-period-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 24rpx;
}

.filter-period-label {
  font-size: 24rpx;
  color: $textSecondary;
}

.filter-period-tabs {
  display: flex;
  align-items: center;
  background: $cardBgLight;
  border-radius: 20rpx;
  padding: 4rpx;
  border: 1rpx solid #333;
}

.filter-period-tab {
  padding: 8rpx 20rpx;
  border-radius: 16rpx;
}

.filter-period-tab--active {
  background: $green;
  box-shadow: 0 4rpx 12rpx rgba(7, 193, 96, 0.3);
}

.filter-period-text {
  font-size: 22rpx;
  font-weight: 500;
  color: $textSecondary;
}

.filter-period-text--active {
  color: $textPrimary;
  font-weight: 600;
}

.filter-title {
  font-size: 28rpx;
  color: $textSecondary;
  display: block;
  margin-bottom: 16rpx;
}

.filter-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12rpx;
}

.filter-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 18rpx 0;
  border-radius: 20rpx;
  background: $cardBgLight;
}

.filter-btn--active {
  box-shadow: 0 4rpx 16rpx rgba(0, 0, 0, 0.3);
}

.filter-btn--distance { background: linear-gradient(135deg, #3b82f6, #2563eb); }
.filter-btn--calories { background: linear-gradient(135deg, #f97316, #ea580c); }
.filter-btn--sprints { background: linear-gradient(135deg, #eab308, #ca8a04); }
.filter-btn--duration { background: linear-gradient(135deg, #8b5cf6, #7c3aed); }

.filter-btn-label {
  font-size: 26rpx;
  color: $textSecondary;
}

.filter-btn--active .filter-btn-label {
  color: $textPrimary;
  font-weight: 600;
}

// ============================================================
// Rank Cards
// ============================================================
.rank-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 24rpx 28rpx;
  margin-bottom: 16rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.rank-row {
  display: flex;
  align-items: center;
}

.rank-badge {
  width: 72rpx;
  height: 72rpx;
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 20rpx;
  flex-shrink: 0;
  background: linear-gradient(135deg, $cardBg, $cardBgLight);
  box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.3);
}

.rank-badge--gold {
  background: linear-gradient(135deg, #facc15, #f97316);
}

.rank-badge--silver {
  background: linear-gradient(135deg, #d1d5db, #9ca3af);
}

.rank-badge--bronze {
  background: linear-gradient(135deg, #f97316, #ea580c);
}

.rank-trophy {
  font-size: 32rpx;
}

.rank-number {
  font-size: 28rpx;
  font-weight: 700;
  color: $textPrimary;
}

.rank-avatar {
  width: 72rpx;
  height: 72rpx;
  border-radius: 50%;
  background: linear-gradient(135deg, #2a2a2a, #3a3a3a);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 16rpx;
  flex-shrink: 0;
}

.rank-avatar-text {
  font-size: 28rpx;
  font-weight: 700;
  color: $textPrimary;
}

.rank-info {
  flex: 1;
  min-width: 0;
}

.rank-name {
  font-size: 28rpx;
  font-weight: 600;
  color: $textPrimary;
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rank-sub-stats {
  display: flex;
  gap: 16rpx;
  margin-top: 4rpx;
}

.rank-sub {
  font-size: 22rpx;
  color: $textMuted;
}

.rank-value-col {
  text-align: right;
  flex-shrink: 0;
  margin-left: 12rpx;
}

.rank-value {
  font-size: 40rpx;
  font-weight: 700;
  color: $green;
  display: block;
}

.rank-unit {
  font-size: 20rpx;
  color: $textMuted;
  display: block;
}

.rank-bar-bg {
  margin-top: 16rpx;
  height: 8rpx;
  border-radius: 8rpx;
  background: $cardBgLight;
  overflow: hidden;
}

.rank-bar {
  height: 100%;
  border-radius: 8rpx;
  background: linear-gradient(90deg, $green, $greenDark);
  transition: width 0.5s ease;
}

.empty-rank {
  padding: 60rpx 0;
  display: flex;
  justify-content: center;
}

.empty-rank-text {
  font-size: 26rpx;
  color: $textMuted;
}

// ============================================================
// Leave Button
// ============================================================
.leave-btn {
  margin-top: 24rpx;
  height: 80rpx;
  border-radius: 100rpx;
  background: rgba(239, 68, 68, 0.1);
  border: 1rpx solid rgba(239, 68, 68, 0.3);
  display: flex;
  align-items: center;
  justify-content: center;
}

.leave-btn-text {
  font-size: 28rpx;
  font-weight: 600;
  color: #ef4444;
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
  background: $cardBgLight;
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
  background: $cardBgLight;
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

.modal-btn-full {
  flex: unset;
  width: 100%;
}

.modal-btn-confirm-text {
  font-size: 28rpx;
  font-weight: 600;
  color: $textPrimary;
}

.invite-code-box {
  background: $cardBgLight;
  border-radius: 20rpx;
  padding: 32rpx;
  margin-bottom: 28rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 2rpx dashed #333;
}

.invite-code {
  font-size: 48rpx;
  font-weight: 700;
  color: $green;
  letter-spacing: 12rpx;
}

.placeholder {
  color: $textMuted;
}
</style>
