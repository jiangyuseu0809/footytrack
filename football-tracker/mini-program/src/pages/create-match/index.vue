<template>
  <view class="page">
    <!-- Nav Bar -->
    <view class="nav-bar">
      <text class="back" @tap="goBack">‹</text>
      <text class="nav-title">新建比赛</text>
    </view>

    <view class="form">
      <!-- Title -->
      <text class="label">比赛标题</text>
      <view class="input-wrapper">
        <text class="input-icon">⚽</text>
        <input class="input-field" v-model="title" placeholder="例如：周末友谊赛" placeholder-class="placeholder" />
      </view>

      <!-- Location -->
      <text class="label">地点</text>
      <view class="input-wrapper">
        <text class="input-icon">📍</text>
        <input class="input-field" v-model="location" placeholder="球场名称" placeholder-class="placeholder" />
      </view>

      <!-- Date -->
      <text class="label">比赛日期</text>
      <picker mode="date" @change="onDateChange">
        <view class="input-wrapper">
          <text class="input-icon">📅</text>
          <text :class="['picker-text', { 'picker-placeholder': !dateStr }]">{{ dateStr || '选择日期' }}</text>
        </view>
      </picker>

      <!-- Time -->
      <text class="label">开始时间</text>
      <picker mode="time" @change="onTimeChange">
        <view class="input-wrapper">
          <text class="input-icon">🕐</text>
          <text :class="['picker-text', { 'picker-placeholder': !timeStr }]">{{ timeStr || '选择时间' }}</text>
        </view>
      </picker>

      <!-- Groups -->
      <text class="label">分组数</text>
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

      <!-- Players per group -->
      <text class="label">每组人数</text>
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

      <!-- Submit -->
      <view class="submit-btn" @tap="handleSubmit">
        <text class="submit-btn-text">创建比赛</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { createMatch } from '../../utils/api'

const title = ref('')
const location = ref('')
const dateStr = ref('')
const timeStr = ref('')
const groups = ref(2)
const playersPerGroup = ref(5)

const defaultColors = ['红', '蓝', '绿', '黄', '白', '黑']

function goBack() { uni.navigateBack() }

function onDateChange(e: any) { dateStr.value = e.detail.value }
function onTimeChange(e: any) { timeStr.value = e.detail.value }

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
    })
    uni.showToast({ title: '创建成功', icon: 'success' })
    setTimeout(() => uni.navigateBack(), 1000)
  } catch (e: any) {
    uni.showToast({ title: e.message, icon: 'none' })
  }
}
</script>

<style lang="scss" scoped>
.page {
  min-height: 100vh;
  background: #0D1117;
}

.nav-bar {
  padding: 100rpx 32rpx 28rpx;
  display: flex;
  align-items: center;

  .back {
    font-size: 52rpx;
    color: #00E676;
    margin-right: 12rpx;
    font-weight: 300;
    line-height: 1;
  }

  .nav-title {
    font-size: 36rpx;
    font-weight: 600;
    color: #FFFFFF;
  }
}

.form {
  padding: 0 32rpx 60rpx;
}

/* ---- Labels ---- */
.label {
  font-size: 26rpx;
  color: #8B949E;
  display: block;
  margin-top: 28rpx;
  margin-bottom: 12rpx;
}

/* ---- Input Fields ---- */
.input-wrapper {
  background: #1C2333;
  border-radius: 24rpx;
  padding: 0 28rpx;
  height: 96rpx;
  display: flex;
  align-items: center;
  gap: 16rpx;
  border: 1rpx solid rgba(255, 255, 255, 0.08);
}

.input-icon {
  font-size: 28rpx;
  flex-shrink: 0;
}

.input-field {
  flex: 1;
  font-size: 28rpx;
  color: #FFFFFF;
  background: transparent;
}

.picker-text {
  flex: 1;
  font-size: 28rpx;
  color: #FFFFFF;
}

.picker-placeholder {
  color: #545d68;
}

.placeholder {
  color: #545d68;
}

/* ---- Stepper ---- */
.stepper-row {
  display: flex;
  align-items: center;
  gap: 20rpx;
}

.stepper-btn {
  width: 64rpx;
  height: 64rpx;
  border-radius: 50%;
  background: #1C2333;
  border: 1rpx solid #30363D;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.stepper-btn-text {
  font-size: 36rpx;
  font-weight: 600;
  color: #00E676;
  line-height: 1;
}

.stepper-value {
  font-size: 36rpx;
  font-weight: 700;
  color: #FFFFFF;
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
  color: #8B949E;
  background: #242D3D;
  padding: 4rpx 14rpx;
  border-radius: 10rpx;
}

.stepper-total {
  font-size: 24rpx;
  color: #8B949E;
  margin-left: 12rpx;
}

/* ---- Submit Button ---- */
.submit-btn {
  margin-top: 48rpx;
  background: linear-gradient(135deg, #00E676, #00BFA5);
  border-radius: 24rpx;
  height: 100rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.submit-btn-text {
  font-size: 32rpx;
  font-weight: 600;
  color: #0D1117;
}
</style>
