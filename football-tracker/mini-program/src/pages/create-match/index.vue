<template>
  <view class="page">
    <view class="nav-bar">
      <text class="back" @tap="goBack">‹</text>
      <text class="nav-title">新建比赛</text>
    </view>

    <view class="form">
      <text class="label">比赛标题</text>
      <input class="input" v-model="title" placeholder="例如：周末友谊赛" placeholder-class="placeholder" />

      <text class="label">地点</text>
      <input class="input" v-model="location" placeholder="球场名称" placeholder-class="placeholder" />

      <text class="label">比赛时间</text>
      <picker mode="date" @change="onDateChange">
        <view class="input picker">{{ dateStr || '选择日期' }}</view>
      </picker>
      <picker mode="time" @change="onTimeChange">
        <view class="input picker">{{ timeStr || '选择时间' }}</view>
      </picker>

      <text class="label">分组数</text>
      <view class="num-row">
        <view class="num-btn" @tap="groups = Math.max(2, groups - 1)">-</view>
        <text class="num-value">{{ groups }}</text>
        <view class="num-btn" @tap="groups++">+</view>
      </view>

      <text class="label">每组人数</text>
      <view class="num-row">
        <view class="num-btn" @tap="playersPerGroup = Math.max(1, playersPerGroup - 1)">-</view>
        <text class="num-value">{{ playersPerGroup }}</text>
        <view class="num-btn" @tap="playersPerGroup++">+</view>
      </view>

      <view class="submit-btn" @tap="handleSubmit">
        <text>创建比赛</text>
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
.page { min-height: 100vh; background: #0D1117; }
.nav-bar {
  padding: 100rpx 28rpx 28rpx; display: flex; align-items: center;
  .back { font-size: 52rpx; color: #00E676; margin-right: 12rpx; font-weight: 300; }
  .nav-title { font-size: 36rpx; font-weight: 600; color: #fff; }
}
.form { padding: 0 28rpx; }
.label { font-size: 26rpx; color: #8B949E; display: block; margin: 20rpx 0 8rpx; }
.input {
  background: #1C2333; border-radius: 20rpx; padding: 24rpx 28rpx;
  font-size: 28rpx; color: #fff; border: 1rpx solid #30363D;
  &.picker { color: #8B949E; }
}
.placeholder { color: #545d68; }
.num-row {
  display: flex; align-items: center; gap: 24rpx;
  .num-btn {
    width: 64rpx; height: 64rpx; border-radius: 50%;
    background: #1C2333; color: #00E676;
    display: flex; align-items: center; justify-content: center;
    font-size: 36rpx; font-weight: 600;
    border: 1rpx solid #30363D;
  }
  .num-value { font-size: 36rpx; font-weight: 700; color: #fff; }
}
.submit-btn {
  background: #00E676; color: #0D1117;
  text-align: center; padding: 24rpx;
  border-radius: 44rpx; font-size: 30rpx; font-weight: 600;
  margin-top: 40rpx;
}
</style>
