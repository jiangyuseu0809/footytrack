<template>
  <view class="page">
    <!-- Header -->
    <view class="header">
      <text class="header-title">我的</text>

      <!-- User Info -->
      <view class="user-info" @tap="!loggedIn && handleLogin()">
        <view v-if="loggedIn">
          <button class="avatar-btn" open-type="chooseAvatar" @chooseavatar="onChooseAvatar">
            <image v-if="profile?.avatarUrl" class="avatar-img" :src="profile.avatarUrl" mode="aspectFill" />
            <view v-else class="avatar-circle">
              <text class="avatar-icon">👤</text>
            </view>
          </button>
        </view>
        <view v-else class="avatar-circle">
          <text class="avatar-icon">👤</text>
        </view>
        <view class="user-text">
          <template v-if="loggedIn">
            <input
              type="nickname"
              class="nickname-input"
              :value="profile?.nickname || '足球爱好者'"
              placeholder="设置昵称"
              placeholder-class="nickname-placeholder"
              @blur="onNicknameBlur"
            />
            <text class="join-date">加入于 {{ joinDate }}</text>
          </template>
          <template v-else>
            <text class="nickname-input login-hint">点击登录</text>
            <text class="join-date">登录后查看个人数据</text>
          </template>
        </view>
      </view>
    </view>

    <scroll-view scroll-y class="scroll-area">
      <template v-if="loggedIn">
        <!-- Stats Cards -->
        <view class="section">
          <view class="stats-row">
            <view class="stat-card">
              <text class="stat-card-value">{{ totalSessions }}</text>
              <text class="stat-card-label">场比赛</text>
            </view>
            <view class="stat-card">
              <text class="stat-card-value">{{ totalDistanceStr }}</text>
              <text class="stat-card-label">公里</text>
            </view>
            <view class="stat-card">
              <text class="stat-card-value">{{ totalCaloriesStr }}</text>
              <text class="stat-card-label">千卡</text>
            </view>
          </view>
        </view>

        <!-- Monthly Goal -->
        <view class="section">
          <!-- No goals set: prompt -->
          <view v-if="!hasGoals" class="goal-card goal-prompt" @tap="openGoalModal">
            <text class="goal-prompt-text">设置你的月度运动目标</text>
            <view class="goal-prompt-btn">
              <text class="goal-prompt-btn-text">设置目标</text>
            </view>
          </view>

          <!-- Goals set: progress bars -->
          <view v-else class="goal-card">
            <view class="goal-header">
              <text class="goal-title">本月目标</text>
              <text class="goal-edit" @tap="openGoalModal">编辑</text>
            </view>

            <view v-if="goals.distance > 0" class="goal-row">
              <view class="goal-row-top">
                <text class="goal-row-label">距离</text>
                <text class="goal-row-value">{{ monthDistance.toFixed(1) }}/{{ goals.distance }} km</text>
              </view>
              <view class="goal-bar-track">
                <view class="goal-bar-fill" :style="{ width: goalPercent(monthDistance, goals.distance) + '%' }" />
              </view>
              <text class="goal-row-percent">{{ goalPercent(monthDistance, goals.distance) }}%</text>
            </view>

            <view v-if="goals.calories > 0" class="goal-row">
              <view class="goal-row-top">
                <text class="goal-row-label">热量</text>
                <text class="goal-row-value">{{ Math.round(monthCalories) }}/{{ goals.calories }} kcal</text>
              </view>
              <view class="goal-bar-track">
                <view class="goal-bar-fill" :style="{ width: goalPercent(monthCalories, goals.calories) + '%' }" />
              </view>
              <text class="goal-row-percent">{{ goalPercent(monthCalories, goals.calories) }}%</text>
            </view>

            <view v-if="goals.matches > 0" class="goal-row">
              <view class="goal-row-top">
                <text class="goal-row-label">场次</text>
                <text class="goal-row-value">{{ monthSessions }}/{{ goals.matches }} 场</text>
              </view>
              <view class="goal-bar-track">
                <view class="goal-bar-fill" :style="{ width: goalPercent(monthSessions, goals.matches) + '%' }" />
              </view>
              <text class="goal-row-percent">{{ goalPercent(monthSessions, goals.matches) }}%</text>
            </view>
          </view>
        </view>

        <!-- Goal Setting Modal -->
        <view v-if="showGoalModal" class="modal-mask" @tap="showGoalModal = false">
          <view class="modal-box" @tap.stop>
            <text class="modal-title">设置月度目标</text>

            <view class="modal-field">
              <text class="modal-label">距离目标 (km)</text>
              <input class="modal-input" type="digit" v-model="goalForm.distance" placeholder="0" />
            </view>
            <view class="modal-field">
              <text class="modal-label">热量目标 (kcal)</text>
              <input class="modal-input" type="digit" v-model="goalForm.calories" placeholder="0" />
            </view>
            <view class="modal-field">
              <text class="modal-label">场次目标</text>
              <input class="modal-input" type="number" v-model="goalForm.matches" placeholder="0" />
            </view>

            <view class="modal-actions">
              <view class="modal-btn modal-btn--cancel" @tap="showGoalModal = false">
                <text class="modal-btn-text">取消</text>
              </view>
              <view class="modal-btn modal-btn--confirm" @tap="saveGoals">
                <text class="modal-btn-text modal-btn-text--confirm">确定</text>
              </view>
            </view>
          </view>
        </view>

        <!-- Menu Items -->
        <view class="section">
          <view class="menu-card">
            <!-- AI Analysis -->
            <view class="menu-row" @tap="loadAnalysis">
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
                <text class="analysis-advice">{{ analysis.advice }}</text>
              </view>
            </view>

            <view class="menu-divider" />

            <!-- Badges -->
            <view class="menu-row" @tap="showBadges = !showBadges">
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

        <!-- Logout -->
        <view class="section">
          <view class="logout-btn" @tap="handleLogout">
            <text class="logout-text">退出登录</text>
          </view>
        </view>
      </template>

      <!-- Menu Group 2 (always visible) -->
      <view class="section">
        <view class="menu-card">
          <view class="menu-row" @tap="goBindWatch">
            <text class="menu-label">绑定手表</text>
            <text class="menu-chevron">›</text>
          </view>

          <view class="menu-divider" />

          <view class="menu-row" @tap="goFeedback">
            <text class="menu-label">意见反馈</text>
            <text class="menu-chevron">›</text>
          </view>

          <view class="menu-divider" />

          <view class="menu-row" @tap="goDonate">
            <text class="menu-label">打赏支持</text>
            <text class="menu-chevron">›</text>
          </view>
        </view>
      </view>

      <!-- About -->
      <view class="about-section section--last">
        <text class="about-text">FootyTrack v1.0.0</text>
        <text class="about-sub">记录你的每一场球</text>
      </view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import {
  getProfile, getSessions, getPlayerAnalysis, getEarnedBadges,
  clearAuth, isLoggedIn, updateProfile, uploadAvatar, wxLogin, setToken, setUid,
  type UserProfile, type SessionDto, type Badge, type UserBadge
} from '../../utils/api'
import { formatDistance } from '../../utils/format'

const CACHE_PROFILE = 'cache_profile'
const CACHE_PROFILE_SESSIONS = 'cache_profile_sessions'
const GOAL_KEY = 'monthly_goals'

const profile = ref<UserProfile | null>(null)
const sessions = ref<SessionDto[]>([])
const analysis = ref<{ type: string; description: string; strengths: string[]; advice: string } | null>(null)
const allBadges = ref<Badge[]>([])
const earnedBadges = ref<UserBadge[]>([])
const showBadges = ref(false)
const loggedIn = ref(isLoggedIn())

// Restore from cache immediately
const cachedProfile = uni.getStorageSync(CACHE_PROFILE)
const cachedSessions = uni.getStorageSync(CACHE_PROFILE_SESSIONS)
if (cachedProfile) profile.value = cachedProfile
if (cachedSessions) sessions.value = cachedSessions

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

const monthDistance = computed(() => {
  const now = new Date()
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).getTime()
  const meters = sessions.value.filter(s => s.startTime >= monthStart).reduce((sum, s) => sum + (s.totalDistanceMeters || 0), 0)
  return meters / 1000
})

const monthCalories = computed(() => {
  const now = new Date()
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).getTime()
  return sessions.value.filter(s => s.startTime >= monthStart).reduce((sum, s) => sum + (s.caloriesBurned || 0), 0)
})

// Monthly goals
const savedGoals = uni.getStorageSync(GOAL_KEY)
const goals = ref<{ distance: number; calories: number; matches: number }>(
  savedGoals ? savedGoals : { distance: 0, calories: 0, matches: 0 }
)
const hasGoals = computed(() => goals.value.distance > 0 || goals.value.calories > 0 || goals.value.matches > 0)
const showGoalModal = ref(false)
const goalForm = reactive({ distance: 0, calories: 0, matches: 0 })

function goalPercent(current: number, target: number) {
  if (target <= 0) return 0
  return Math.min(100, Math.round((current / target) * 100))
}

function openGoalModal() {
  goalForm.distance = goals.value.distance
  goalForm.calories = goals.value.calories
  goalForm.matches = goals.value.matches
  showGoalModal.value = true
}

function saveGoals() {
  goals.value = {
    distance: Number(goalForm.distance) || 0,
    calories: Number(goalForm.calories) || 0,
    matches: Number(goalForm.matches) || 0,
  }
  uni.setStorageSync(GOAL_KEY, goals.value)
  showGoalModal.value = false
}

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
    uni.setStorageSync(CACHE_PROFILE, p)
    uni.setStorageSync(CACHE_PROFILE_SESSIONS, s.sessions)
  } catch (e) { console.error(e) }
}

async function handleLogin() {
  try {
    const res = await wxLogin()
    setToken(res.token)
    setUid(res.uid)
    loggedIn.value = true
    await loadData()
    uni.showToast({ title: '登录成功', icon: 'success' })
  } catch (e: any) {
    uni.showToast({ title: e.message || '登录失败', icon: 'none' })
  }
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

function goFeedback() {
  uni.navigateTo({ url: '/pages/feedback/index' })
}

function goDonate() {
  uni.navigateTo({ url: '/pages/donate/index' })
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
        loggedIn.value = false
        profile.value = null
        sessions.value = []
        analysis.value = null
        allBadges.value = []
        earnedBadges.value = []
        goals.value = { distance: 0, calories: 0, matches: 0 }
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

.goal-prompt {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 24rpx;
}

.goal-prompt-text {
  font-size: 28rpx;
  color: $textSecondary;
}

.goal-prompt-btn {
  background: linear-gradient(135deg, $green, $greenDark);
  padding: 16rpx 48rpx;
  border-radius: 100rpx;
}

.goal-prompt-btn-text {
  font-size: 28rpx;
  font-weight: 600;
  color: #FFFFFF;
}

.goal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 24rpx;
}

.goal-title {
  font-size: 30rpx;
  font-weight: 500;
  color: $textPrimary;
}

.goal-edit {
  font-size: 24rpx;
  color: $green;
}

.goal-row {
  margin-bottom: 20rpx;
  &:last-child { margin-bottom: 0; }
}

.goal-row-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8rpx;
}

.goal-row-label {
  font-size: 26rpx;
  color: $textPrimary;
  font-weight: 500;
}

.goal-row-value {
  font-size: 24rpx;
  color: $textSecondary;
}

.goal-bar-track {
  width: 100%;
  height: 12rpx;
  background: #2a2a2a;
  border-radius: 6rpx;
  overflow: hidden;
  margin-bottom: 4rpx;
}

.goal-bar-fill {
  height: 100%;
  background: linear-gradient(90deg, $green, $greenDark);
  border-radius: 6rpx;
  box-shadow: 0 0 12rpx rgba(7, 193, 96, 0.5);
  transition: width 0.3s;
}

.goal-row-percent {
  font-size: 22rpx;
  color: $textMuted;
  display: block;
  text-align: right;
}

// ============================================================
// Goal Modal
// ============================================================
.modal-mask {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 999;
}

.modal-box {
  width: 600rpx;
  background: $cardBg;
  border-radius: 32rpx;
  padding: 40rpx;
  border: 1rpx solid #2a2a2a;
}

.modal-title {
  font-size: 32rpx;
  font-weight: 700;
  color: $textPrimary;
  display: block;
  text-align: center;
  margin-bottom: 32rpx;
}

.modal-field {
  margin-bottom: 24rpx;
}

.modal-label {
  font-size: 26rpx;
  color: $textSecondary;
  display: block;
  margin-bottom: 8rpx;
}

.modal-input {
  width: 100%;
  height: 80rpx;
  background: $pageBg;
  border: 1rpx solid #2a2a2a;
  border-radius: 16rpx;
  padding: 0 24rpx;
  font-size: 28rpx;
  color: $textPrimary;
  box-sizing: border-box;
}

.modal-actions {
  display: flex;
  gap: 16rpx;
  margin-top: 32rpx;
}

.modal-btn {
  flex: 1;
  height: 80rpx;
  border-radius: 100rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-btn--cancel {
  background: #252525;
  border: 1rpx solid #2a2a2a;
}

.modal-btn--confirm {
  background: linear-gradient(135deg, $green, $greenDark);
}

.modal-btn-text {
  font-size: 28rpx;
  font-weight: 600;
  color: $textSecondary;
}

.modal-btn-text--confirm {
  color: #FFFFFF;
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
  padding: 8rpx 16rpx;
  border-radius: 16rpx;
  margin-right: 8rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.badge-count-text {
  font-size: 22rpx;
  color: $green;
  font-weight: 600;
  line-height: 1;
}

.menu-divider {
  height: 1rpx;
  background: #2a2a2a;
  margin: 0 28rpx;
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
// Login Hint (in header)
// ============================================================
.login-hint {
  color: rgba(255, 255, 255, 0.6);
}
</style>
