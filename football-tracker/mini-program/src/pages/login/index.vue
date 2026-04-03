<template>
  <view class="page">
    <view class="login-container">
      <!-- Logo & Branding -->
      <view class="logo-area">
        <view class="logo-icon-container">
          <text class="logo-emoji">⚽</text>
        </view>
        <text class="app-name">野球记</text>
        <text class="app-desc">记录每一场球，追踪每一步成长</text>
      </view>

      <!-- Login Button -->
      <view class="form-area">
        <button class="login-btn" @tap="handleWxLogin">
          <text class="login-btn-text">微信一键登录</text>
        </button>
        <text v-if="errMsg" class="error">{{ errMsg }}</text>
      </view>

      <!-- Footer -->
      <view class="footer">
        <text class="footer-text">登录即表示同意</text>
        <text class="footer-link">用户协议</text>
        <text class="footer-text">与</text>
        <text class="footer-link">隐私政策</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { wxLogin, setToken, setUid } from '../../utils/api'

const errMsg = ref('')

async function handleWxLogin() {
  errMsg.value = ''
  try {
    const res = await wxLogin()
    setToken(res.token)
    setUid(res.uid)
    const pages = getCurrentPages()
    if (pages.length > 1) {
      uni.navigateBack()
    } else {
      uni.reLaunch({ url: '/pages/home/index' })
    }
  } catch (e: any) {
    errMsg.value = e.message || '微信登录失败'
  }
}
</script>

<style lang="scss" scoped>
$pageBg: #0a0a0a;
$cardBg: #1a1a1a;
$green: #07c160;
$greenDark: #05a850;
$textPrimary: #FFFFFF;
$textSecondary: #999;
$textMuted: #666;

.page {
  min-height: 100vh;
  background: $pageBg;
  display: flex;
  align-items: center;
  justify-content: center;
}

.login-container {
  width: 100%;
  padding: 0 48rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.logo-area {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding-bottom: 100rpx;
}

.logo-icon-container {
  width: 160rpx;
  height: 160rpx;
  border-radius: 40rpx;
  background: linear-gradient(135deg, $green, $greenDark);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 32rpx;
  box-shadow: 0 8rpx 32rpx rgba(7, 193, 96, 0.3);
}

.logo-emoji {
  font-size: 120rpx;
  line-height: 1;
}

.app-name {
  font-size: 64rpx;
  font-weight: 700;
  color: $textPrimary;
  display: block;
  margin-bottom: 16rpx;
}

.app-desc {
  font-size: 28rpx;
  color: $textSecondary;
  display: block;
}

.form-area {
  width: 100%;
}

.login-btn {
  width: 100%;
  height: 100rpx;
  background: linear-gradient(90deg, $green, $greenDark) !important;
  border: none;
  border-radius: 100rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  margin: 0;
  line-height: 100rpx;
  box-shadow: 0 8rpx 24rpx rgba(7, 193, 96, 0.3);

  &::after {
    border: none;
  }
}

.login-btn-text {
  font-size: 32rpx;
  font-weight: 700;
  color: $textPrimary;
}

.error {
  display: block;
  text-align: center;
  color: #FF4757;
  font-size: 24rpx;
  margin-top: 32rpx;
}

.footer {
  display: flex;
  align-items: center;
  justify-content: center;
  margin-top: 80rpx;
  flex-wrap: wrap;
}

.footer-text {
  font-size: 22rpx;
  color: $textSecondary;
}

.footer-link {
  font-size: 22rpx;
  color: $green;
  margin: 0 4rpx;
}
</style>
