<template>
  <view class="page">
    <!-- Header -->
    <view class="header">
      <text class="header-title">创建比赛</text>
    </view>

    <scroll-view scroll-y class="scroll-area">
      <!-- Quick Templates (only shown when user has saved templates) -->
      <view v-if="templates.length" class="section">
        <view class="template-card">
          <view class="template-header" @tap="showTemplates = !showTemplates">
            <view class="template-left">
              <view class="template-icon-box">
                <text class="template-icon">⭐</text>
              </view>
              <view class="template-text">
                <text class="template-title">常用模板</text>
                <text class="template-sub">{{ templates.length }} 个已保存</text>
              </view>
            </view>
            <text class="template-chevron" :class="{ rotated: showTemplates }">›</text>
          </view>

          <view v-if="showTemplates" class="template-list">
            <view
              v-for="tpl in templates"
              :key="tpl.id"
              class="template-item"
            >
              <view class="template-item-info" @tap="handleUseTemplate(tpl)">
                <text class="template-item-name">{{ tpl.name }}</text>
                <text class="template-item-meta">{{ tpl.location }} · {{ tpl.groups }}组 · 每组{{ tpl.playersPerGroup }}人</text>
              </view>
              <view class="template-actions">
                <text class="template-plus" @tap="handleUseTemplate(tpl)">＋</text>
                <text class="template-delete" @tap.stop="handleDeleteTemplate(tpl.id)">✕</text>
              </view>
            </view>
          </view>
        </view>
      </view>

      <!-- Create Form -->
      <view class="section">
        <view class="form-card">
          <text class="form-section-title">比赛信息</text>

          <view class="form-group">
            <text class="form-label">比赛名称</text>
            <view class="input-wrapper">
              <input
                class="input-field"
                v-model="title"
                placeholder="输入比赛名称"
                placeholder-class="placeholder"
              />
            </view>
          </view>

          <view class="form-group">
            <text class="form-label">比赛地点</text>
            <view class="input-wrapper input-wrapper--location" @tap="chooseLocation">
              <text :class="['picker-text', { 'picker-placeholder': !location }]">{{ location || '选择比赛地点' }}</text>
              <text class="location-icon">📍</text>
            </view>
          </view>

          <view class="form-group">
            <text class="form-label">比赛时间</text>
            <view class="datetime-row">
              <picker mode="date" @change="onDateChange" class="datetime-picker">
                <view class="input-wrapper input-wrapper--half">
                  <text :class="['picker-text', { 'picker-placeholder': !dateStr }]">{{ dateStr || '选择日期' }}</text>
                  <text class="picker-icon">📅</text>
                </view>
              </picker>
              <picker mode="time" @change="onTimeChange" class="datetime-picker">
                <view class="input-wrapper input-wrapper--half">
                  <text :class="['picker-text', { 'picker-placeholder': !timeStr }]">{{ timeStr || '选择时间' }}</text>
                  <text class="picker-icon">🕐</text>
                </view>
              </picker>
            </view>
          </view>

          <view class="form-group">
            <text class="form-label">分组数</text>
            <view class="stepper-row">
              <view class="stepper-btn" @tap="groups = Math.max(2, groups - 1)">
                <text class="stepper-btn-text">-</text>
              </view>
              <text class="stepper-value">{{ groups }}</text>
              <view class="stepper-btn" @tap="groups++">
                <text class="stepper-btn-text">+</text>
              </view>
              <view class="stepper-preview">
                <text v-for="(c, i) in defaultColors.slice(0, groups)" :key="i" class="color-tag">{{ c }}</text>
              </view>
            </view>
          </view>

          <view class="form-group">
            <text class="form-label">每组人数</text>
            <view class="stepper-row">
              <view class="stepper-btn" @tap="playersPerGroup = Math.max(1, playersPerGroup - 1)">
                <text class="stepper-btn-text">-</text>
              </view>
              <text class="stepper-value">{{ playersPerGroup }}</text>
              <view class="stepper-btn" @tap="playersPerGroup++">
                <text class="stepper-btn-text">+</text>
              </view>
              <text class="stepper-total">共 {{ groups * playersPerGroup }} 人</text>
            </view>
          </view>

          <view class="form-group">
            <text class="form-label">人数上限</text>
            <view class="stepper-row">
              <view class="stepper-btn" @tap="decreaseMaxPlayers">
                <text class="stepper-btn-text">-</text>
              </view>
              <text class="stepper-value">{{ maxPlayers }}</text>
              <view class="stepper-btn" @tap="maxPlayers = Math.min(99, maxPlayers + 1)">
                <text class="stepper-btn-text">+</text>
              </view>
              <text class="stepper-total">最少 {{ groups * playersPerGroup }} 人</text>
            </view>
          </view>

          <view class="form-group">
            <text class="form-label">分队模式</text>
            <view class="toggle-row">
              <view
                class="toggle-btn"
                :class="{ 'toggle-btn--active': teamMode === 'choose' }"
                @tap="teamMode = 'choose'"
              >
                <text class="toggle-btn-text">选择分队</text>
              </view>
              <view
                class="toggle-btn"
                :class="{ 'toggle-btn--active': teamMode === 'random' }"
                @tap="teamMode = 'random'"
              >
                <text class="toggle-btn-text">随机分队</text>
              </view>
            </view>
          </view>
        </view>
      </view>

      <!-- Save as Template + Action Buttons -->
      <view class="section">
        <view class="save-template-row" @tap="saveAsTemplate = !saveAsTemplate">
          <view class="checkbox" :class="{ 'checkbox--checked': saveAsTemplate }">
            <text v-if="saveAsTemplate" class="checkbox-icon">✓</text>
          </view>
          <text class="save-template-text">保存为常用模板</text>
        </view>

        <view class="create-btn" @tap="handleSubmit">
          <text class="create-btn-text">创建比赛</text>
        </view>
        <view class="share-btn">
          <image src="/static/icons/share.svg" class="share-btn-svg" />
          <text class="share-btn-text">分享给好友</text>
        </view>
      </view>

      <!-- Tips -->
      <view class="section section--last">
        <view class="tips-card">
          <text class="tips-text">💡 <text class="tips-highlight">温馨提示：</text>创建比赛后可通过微信分享给好友，邀请他们一起参与</text>
        </view>
      </view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { createMatch } from '../../utils/api'

interface MatchTemplate {
  id: string
  name: string
  location: string
  groups: number
  playersPerGroup: number
  maxPlayers: number
  teamMode: 'choose' | 'random'
}

const TEMPLATE_STORAGE_KEY = 'match_templates'

function loadTemplates(): MatchTemplate[] {
  try {
    const raw = uni.getStorageSync(TEMPLATE_STORAGE_KEY)
    return raw ? JSON.parse(raw) : []
  } catch { return [] }
}

function saveTemplates(list: MatchTemplate[]) {
  uni.setStorageSync(TEMPLATE_STORAGE_KEY, JSON.stringify(list))
}

const title = ref('')
const location = ref('')
const dateStr = ref('')
const timeStr = ref('')
const groups = ref(2)
const playersPerGroup = ref(5)
const maxPlayers = ref(10)
const teamMode = ref<'choose' | 'random'>('choose')
const latitude = ref<number | null>(null)
const longitude = ref<number | null>(null)
const showTemplates = ref(false)
const saveAsTemplate = ref(false)
const templates = ref<MatchTemplate[]>(loadTemplates())

const defaultColors = ['红', '蓝', '绿', '黄', '白', '黑']

// Keep maxPlayers >= groups * playersPerGroup
watch([groups, playersPerGroup], () => {
  const minPlayers = groups.value * playersPerGroup.value
  if (maxPlayers.value < minPlayers) {
    maxPlayers.value = minPlayers
  }
})

function decreaseMaxPlayers() {
  const minPlayers = groups.value * playersPerGroup.value
  maxPlayers.value = Math.max(minPlayers, maxPlayers.value - 1)
}

function handleUseTemplate(tpl: MatchTemplate) {
  title.value = tpl.name
  location.value = tpl.location
  groups.value = tpl.groups
  playersPerGroup.value = tpl.playersPerGroup
  maxPlayers.value = tpl.maxPlayers
  teamMode.value = tpl.teamMode
  latitude.value = null
  longitude.value = null
  showTemplates.value = false
}

function handleDeleteTemplate(id: string) {
  templates.value = templates.value.filter(t => t.id !== id)
  saveTemplates(templates.value)
}

function onDateChange(e: any) { dateStr.value = e.detail.value }
function onTimeChange(e: any) { timeStr.value = e.detail.value }

function chooseLocation() {
  uni.chooseLocation({
    success(res) {
      location.value = res.name || res.address
      latitude.value = res.latitude
      longitude.value = res.longitude
    },
    fail() {
      // User cancelled or permission denied — ignore
    },
  })
}

async function handleSubmit() {
  if (!title.value || !location.value || !dateStr.value || !timeStr.value) {
    uni.showToast({ title: '请填写完整信息', icon: 'none' })
    return
  }
  const matchDate = new Date(`${dateStr.value}T${timeStr.value}`).getTime()
  const groupColors = defaultColors.slice(0, groups.value).join(',')

  try {
    await createMatch({
      title: title.value,
      matchDate,
      location: location.value,
      groups: groups.value,
      playersPerGroup: playersPerGroup.value,
      groupColors,
      maxPlayers: maxPlayers.value,
      teamMode: teamMode.value,
      latitude: latitude.value ?? undefined,
      longitude: longitude.value ?? undefined,
    })

    // Save as template if checked
    if (saveAsTemplate.value) {
      const newTpl: MatchTemplate = {
        id: Date.now().toString(),
        name: title.value,
        location: location.value,
        groups: groups.value,
        playersPerGroup: playersPerGroup.value,
        maxPlayers: maxPlayers.value,
        teamMode: teamMode.value,
      }
      templates.value = [newTpl, ...templates.value].slice(0, 10) // max 10 templates
      saveTemplates(templates.value)
    }

    uni.showToast({ title: '创建成功', icon: 'success' })
    setTimeout(() => uni.switchTab({ url: '/pages/home/index' }), 1000)
  } catch (e: any) {
    uni.showToast({ title: e.message, icon: 'none' })
  }
}
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
  height: calc(100vh - 170rpx);
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
// Sections
// ============================================================
.section {
  padding: 24rpx 32rpx 0;
}

.section--last {
  padding-bottom: 120rpx;
}

// ============================================================
// Template Card
// ============================================================
.template-card {
  background: $cardBg;
  border-radius: 32rpx;
  overflow: hidden;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.template-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 24rpx 28rpx;
}

.template-left {
  display: flex;
  align-items: center;
  gap: 16rpx;
}

.template-icon-box {
  width: 72rpx;
  height: 72rpx;
  border-radius: 20rpx;
  background: linear-gradient(135deg, #facc15, #f97316);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.2);
}

.template-icon {
  font-size: 36rpx;
}

.template-text {
  display: flex;
  flex-direction: column;
}

.template-title {
  font-size: 30rpx;
  font-weight: 500;
  color: $textPrimary;
}

.template-sub {
  font-size: 22rpx;
  color: $textMuted;
}

.template-chevron {
  font-size: 40rpx;
  color: $textMuted;
  font-weight: 300;
  transition: transform 0.3s;

  &.rotated {
    transform: rotate(90deg);
  }
}

.template-list {
  padding: 0 28rpx 24rpx;
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.template-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20rpx 24rpx;
  background: #252525;
  border-radius: 20rpx;
  border: 1rpx solid #333;
}

.template-item-info {
  display: flex;
  flex-direction: column;
}

.template-item-name {
  font-size: 28rpx;
  font-weight: 500;
  color: $textPrimary;
}

.template-item-meta {
  font-size: 22rpx;
  color: $textMuted;
  margin-top: 4rpx;
}

.template-plus {
  font-size: 32rpx;
  color: $green;
  font-weight: 500;
}

.template-actions {
  display: flex;
  align-items: center;
  gap: 24rpx;
}

.template-delete {
  font-size: 26rpx;
  color: $textMuted;
  padding: 8rpx;
}

// ============================================================
// Form Card
// ============================================================
.form-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 28rpx 28rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.form-section-title {
  font-size: 30rpx;
  font-weight: 500;
  color: $textPrimary;
  display: block;
  margin-bottom: 24rpx;
}

.form-group {
  margin-bottom: 24rpx;
}

.form-label {
  font-size: 26rpx;
  color: $textSecondary;
  display: block;
  margin-bottom: 12rpx;
}

.input-wrapper {
  background: #252525;
  border-radius: 20rpx;
  padding: 0 24rpx;
  height: 88rpx;
  display: flex;
  align-items: center;
  border: 1rpx solid #333;
}

.input-wrapper--location {
  justify-content: space-between;
}

.location-icon {
  font-size: 32rpx;
  flex-shrink: 0;
}

.input-field {
  flex: 1;
  font-size: 28rpx;
  color: $textPrimary;
  background: transparent;
}

.picker-text {
  flex: 1;
  font-size: 28rpx;
  color: $textPrimary;
}

.picker-placeholder {
  color: $textMuted;
}

.placeholder {
  color: $textMuted;
}

// ============================================================
// DateTime Row
// ============================================================
.datetime-row {
  display: flex;
  gap: 16rpx;
}

.datetime-picker {
  flex: 1;
}

.input-wrapper--half {
  justify-content: space-between;
}

.picker-icon {
  font-size: 28rpx;
  flex-shrink: 0;
}

// ============================================================
// Stepper
// ============================================================
.stepper-row {
  display: flex;
  align-items: center;
  gap: 20rpx;
}

.stepper-btn {
  width: 64rpx;
  height: 64rpx;
  border-radius: 50%;
  background: #252525;
  border: 1rpx solid #333;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.stepper-btn-text {
  font-size: 36rpx;
  font-weight: 600;
  color: $green;
  line-height: 1;
}

.stepper-value {
  font-size: 36rpx;
  font-weight: 700;
  color: $textPrimary;
  min-width: 48rpx;
  text-align: center;
}

.stepper-preview {
  display: flex;
  gap: 8rpx;
  margin-left: 12rpx;
  flex-wrap: wrap;
}

.color-tag {
  font-size: 22rpx;
  color: $textSecondary;
  background: #333;
  padding: 4rpx 14rpx;
  border-radius: 10rpx;
}

.stepper-total {
  font-size: 24rpx;
  color: $textSecondary;
  margin-left: 12rpx;
}

// ============================================================
// Toggle (Team Mode)
// ============================================================
.toggle-row {
  display: flex;
  background: #252525;
  border-radius: 100rpx;
  border: 1rpx solid #333;
  padding: 6rpx;
}

.toggle-btn {
  flex: 1;
  height: 72rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 100rpx;
  transition: background 0.25s, color 0.25s;
}

.toggle-btn--active {
  background: $green;
}

.toggle-btn-text {
  font-size: 28rpx;
  font-weight: 500;
  color: $textMuted;
}

.toggle-btn--active .toggle-btn-text {
  color: $textPrimary;
}

// ============================================================
// Save as Template Checkbox
// ============================================================
.save-template-row {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-bottom: 24rpx;
}

.checkbox {
  width: 40rpx;
  height: 40rpx;
  border-radius: 10rpx;
  border: 2rpx solid #555;
  background: #252525;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.checkbox--checked {
  background: $green;
  border-color: $green;
}

.checkbox-icon {
  font-size: 24rpx;
  color: $textPrimary;
  font-weight: 700;
}

.save-template-text {
  font-size: 28rpx;
  color: $textSecondary;
}

// ============================================================
// Action Buttons
// ============================================================
.create-btn {
  background: linear-gradient(90deg, $green, $greenDark);
  border-radius: 100rpx;
  height: 96rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 24rpx rgba(7, 193, 96, 0.3);
}

.create-btn-text {
  font-size: 32rpx;
  font-weight: 500;
  color: $textPrimary;
}

.share-btn {
  margin-top: 16rpx;
  background: $cardBg;
  border-radius: 100rpx;
  height: 96rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
  border: $border;
}

.share-btn-svg {
  width: 32rpx;
  height: 32rpx;
}

.share-btn-text {
  font-size: 30rpx;
  font-weight: 500;
  color: #ccc;
}

// ============================================================
// Tips
// ============================================================
.tips-card {
  background: #1a2428;
  border-radius: 32rpx;
  padding: 28rpx 32rpx;
  border: 1rpx solid rgba(59, 130, 246, 0.2);
  box-shadow: 0 4rpx 16rpx rgba(0, 0, 0, 0.2);
}

.tips-text {
  font-size: 26rpx;
  color: #ccc;
  line-height: 1.5;
}

.tips-highlight {
  font-weight: 500;
  color: #60a5fa;
}
</style>
