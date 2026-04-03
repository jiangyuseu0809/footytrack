<template>
  <view class="page">
    <!-- Header -->
    <view class="header">
      <view class="header-nav">
        <view class="back-row" @tap="goBack">
          <text class="back-arrow">‹</text>
          <text class="back-text">返回</text>
        </view>
        <text class="nav-title">绑定 Apple Watch</text>
        <view class="nav-right" />
      </view>
    </view>

    <scroll-view scroll-y class="scroll-area">
      <!-- Instruction -->
      <view class="section">
        <view class="hero-card">
          <view class="hero-icon-row">
            <text class="hero-icon">⌚</text>
          </view>
          <text class="hero-title">绑定你的 Apple Watch</text>
          <text class="hero-subtitle">在 Apple Watch 上输入下方绑定码，即可将手表与你的账号关联</text>
        </view>
      </view>

      <!-- Steps -->
      <view class="section">
        <view class="steps">
          <view class="step-row">
            <view class="step-num"><text class="step-num-text">1</text></view>
            <text class="step-text">点击下方按钮生成绑定码</text>
          </view>
          <view class="step-row">
            <view class="step-num"><text class="step-num-text">2</text></view>
            <text class="step-text">在 Apple Watch 上打开野球记 App</text>
          </view>
          <view class="step-row">
            <view class="step-num"><text class="step-num-text">3</text></view>
            <text class="step-text">点击"输入绑定码登录"，输入 6 位数字</text>
          </view>
        </view>
      </view>

      <!-- Code Display -->
      <view v-if="bindCode" class="section">
        <view class="code-card">
          <text class="code-label">绑定码</text>
          <text class="code-value">{{ bindCode }}</text>
          <text class="code-expire">{{ countdown > 0 ? `${countdown}秒后过期` : '已过期' }}</text>
        </view>
      </view>

      <!-- Generate Button -->
      <view class="section section--last">
        <view class="btn-generate" @tap="handleGenerate">
          <text class="btn-generate-text">{{ bindCode ? '重新生成' : '生成绑定码' }}</text>
        </view>
      </view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { ref, onUnmounted } from 'vue'
import { generateBindCode } from '../../utils/api'

const bindCode = ref('')
const countdown = ref(0)
let timer: ReturnType<typeof setInterval> | null = null

function startCountdown(seconds: number) {
  if (timer) clearInterval(timer)
  countdown.value = seconds
  timer = setInterval(() => {
    countdown.value--
    if (countdown.value <= 0) {
      if (timer) clearInterval(timer)
      timer = null
      bindCode.value = ''
    }
  }, 1000)
}

async function handleGenerate() {
  try {
    uni.showLoading({ title: '生成中...' })
    const res = await generateBindCode()
    bindCode.value = res.code
    startCountdown(res.expiresInSeconds)
    uni.hideLoading()
  } catch (e: any) {
    uni.hideLoading()
    uni.showToast({ title: e.message || '生成失败', icon: 'none' })
  }
}

function goBack() {
  uni.navigateBack()
}

onUnmounted(() => {
  if (timer) clearInterval(timer)
})
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
  height: calc(100vh - 240rpx);
}

// ============================================================
// Header
// ============================================================
.header {
  background: linear-gradient(135deg, $green, $greenDark);
  padding: 100rpx 32rpx 36rpx;
  box-shadow: 0 8rpx 32rpx rgba(7, 193, 96, 0.2);
}

.header-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.back-row {
  display: flex;
  align-items: center;
  min-width: 120rpx;
}

.back-arrow {
  font-size: 48rpx;
  color: $textPrimary;
  margin-right: 4rpx;
  font-weight: 300;
  line-height: 1;
}

.back-text {
  font-size: 28rpx;
  color: $textPrimary;
}

.nav-title {
  font-size: 36rpx;
  font-weight: 700;
  color: $textPrimary;
  text-align: center;
  flex: 1;
}

.nav-right {
  min-width: 120rpx;
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
// Hero Card
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
  font-size: 64rpx;
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
// Steps
// ============================================================
.steps {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.step-row {
  display: flex;
  align-items: center;
  gap: 20rpx;
  background: $cardBg;
  border-radius: 32rpx;
  padding: 24rpx;
  border: $border;
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.step-num {
  width: 48rpx;
  height: 48rpx;
  border-radius: 50%;
  background: rgba(7, 193, 96, 0.16);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.step-num-text {
  font-size: 24rpx;
  font-weight: 700;
  color: $green;
}

.step-text {
  font-size: 26rpx;
  color: $textPrimary;
  flex: 1;
}

// ============================================================
// Code Card
// ============================================================
.code-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 40rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  border: 2rpx solid rgba(7, 193, 96, 0.3);
  box-shadow: 0 4rpx 24rpx rgba(0, 0, 0, 0.3);
}

.code-label {
  font-size: 24rpx;
  color: $textSecondary;
  display: block;
  margin-bottom: 16rpx;
}

.code-value {
  font-size: 72rpx;
  font-weight: 700;
  color: $green;
  letter-spacing: 16rpx;
  display: block;
  margin-bottom: 16rpx;
}

.code-expire {
  font-size: 24rpx;
  color: $textSecondary;
  display: block;
}

// ============================================================
// Button
// ============================================================
.btn-generate {
  background: linear-gradient(90deg, $green, $greenDark);
  border-radius: 100rpx;
  height: 96rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 24rpx rgba(7, 193, 96, 0.3);
}

.btn-generate-text {
  font-size: 30rpx;
  font-weight: 600;
  color: $textPrimary;
}
</style>
