<template>
  <view class="page">
    <view class="nav-bar">
      <view class="back-btn" @tap="goBack">
        <text class="back-icon">‹</text>
      </view>
      <text class="nav-title">绑定 Apple Watch</text>
    </view>

    <view class="content">
      <!-- Instruction -->
      <view class="hero-card">
        <view class="hero-icon-row">
          <text class="hero-icon">⌚</text>
        </view>
        <text class="hero-title">绑定你的 Apple Watch</text>
        <text class="hero-subtitle">在 Apple Watch 上输入下方绑定码，即可将手表与你的账号关联</text>
      </view>

      <!-- Steps -->
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

      <!-- Code Display -->
      <view v-if="bindCode" class="code-card">
        <text class="code-label">绑定码</text>
        <text class="code-value">{{ bindCode }}</text>
        <text class="code-expire">{{ countdown > 0 ? `${countdown}秒后过期` : '已过期' }}</text>
      </view>

      <!-- Generate Button -->
      <view class="btn-generate" @tap="handleGenerate">
        <text class="btn-generate-text">{{ bindCode ? '重新生成' : '生成绑定码' }}</text>
      </view>
    </view>
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
$pageBg: #0D1117;
$cardBg: #1C2333;
$textPrimary: #FFFFFF;
$textSecondary: #8B949E;
$neonGreen: #00E676;

.page {
  min-height: 100vh;
  background: $pageBg;
}

.nav-bar {
  padding: 100rpx 32rpx 28rpx;
  display: flex;
  align-items: center;
  gap: 12rpx;
}
.back-btn {
  width: 52rpx;
  height: 52rpx;
  border-radius: 16rpx;
  background: #1C2333;
  display: flex;
  align-items: center;
  justify-content: center;
}
.back-icon {
  font-size: 36rpx;
  color: $textPrimary;
  font-weight: 300;
}
.nav-title {
  font-size: 36rpx;
  font-weight: 700;
  color: $textPrimary;
}

.content {
  padding: 0 32rpx;
}

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
  color: rgba(255, 255, 255, 0.75);
  line-height: 1.5;
}

/* Steps */
.steps {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
  margin-bottom: 40rpx;
}
.step-row {
  display: flex;
  align-items: center;
  gap: 20rpx;
  background: $cardBg;
  border-radius: 24rpx;
  padding: 20rpx 24rpx;
  border: 1rpx solid rgba(255, 255, 255, 0.08);
}
.step-num {
  width: 48rpx;
  height: 48rpx;
  border-radius: 50%;
  background: rgba(0, 230, 118, 0.16);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.step-num-text {
  font-size: 24rpx;
  font-weight: 700;
  color: $neonGreen;
}
.step-text {
  font-size: 26rpx;
  color: $textPrimary;
  flex: 1;
}

/* Code Card */
.code-card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 40rpx;
  margin-bottom: 32rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  border: 2rpx solid rgba(0, 230, 118, 0.3);
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
  color: $neonGreen;
  letter-spacing: 16rpx;
  display: block;
  margin-bottom: 16rpx;
}
.code-expire {
  font-size: 24rpx;
  color: $textSecondary;
  display: block;
}

/* Button */
.btn-generate {
  background: linear-gradient(135deg, $neonGreen, #00BFA5);
  border-radius: 24rpx;
  height: 96rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}
.btn-generate-text {
  font-size: 30rpx;
  font-weight: 600;
  color: #0D1117;
}
</style>
