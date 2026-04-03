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

      <!-- Step 1: WeChat Login -->
      <view v-if="!showProfileSetup" class="form-area">
        <button class="login-btn" @tap="handleWxLogin">
          <text class="login-btn-text">微信一键登录</text>
        </button>
        <text v-if="errMsg" class="error">{{ errMsg }}</text>
      </view>

      <!-- Step 2: Avatar & Nickname -->
      <view v-else class="form-area">
        <text class="setup-title">设置头像和昵称</text>

        <view class="avatar-pick-area">
          <button class="avatar-pick-btn" open-type="chooseAvatar" @chooseavatar="onChooseAvatar">
            <image v-if="avatarTempPath" :src="avatarTempPath" class="avatar-preview" mode="aspectFill" />
            <view v-else class="avatar-placeholder">
              <text class="avatar-placeholder-text">👤</text>
            </view>
            <text class="avatar-pick-hint">点击选择头像</text>
          </button>
        </view>

        <view class="nickname-area">
          <input
            type="nickname"
            class="nickname-input"
            v-model="nicknameValue"
            placeholder="请输入昵称"
            placeholder-class="placeholder"
            @blur="onNicknameBlur"
          />
        </view>

        <view class="setup-btn" @tap="handleSaveProfile">
          <text class="setup-btn-text">完成</text>
        </view>

        <view class="skip-btn" @tap="handleSkip">
          <text class="skip-btn-text">跳过</text>
        </view>
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
import { wxLogin, setToken, setUid, updateProfile, uploadAvatar } from '../../utils/api'

const errMsg = ref('')
const showProfileSetup = ref(false)
const avatarTempPath = ref('')
const nicknameValue = ref('')

async function handleWxLogin() {
  errMsg.value = ''
  try {
    const res = await wxLogin()
    setToken(res.token)
    setUid(res.uid)
    if (res.isNewUser) {
      showProfileSetup.value = true
    } else {
      goNext()
    }
  } catch (e: any) {
    errMsg.value = e.message || '微信登录失败'
  }
}

function onChooseAvatar(e: any) {
  avatarTempPath.value = e.detail.avatarUrl
}

function onNicknameBlur(e: any) {
  if (e.detail.value) nicknameValue.value = e.detail.value
}

async function handleSaveProfile() {
  try {
    uni.showLoading({ title: '保存中...' })
    if (avatarTempPath.value) {
      await uploadAvatar(avatarTempPath.value)
    }
    if (nicknameValue.value) {
      await updateProfile({ nickname: nicknameValue.value })
    }
    uni.hideLoading()
    goNext()
  } catch (e: any) {
    uni.hideLoading()
    uni.showToast({ title: e.message || '保存失败', icon: 'none' })
  }
}

function handleSkip() {
  goNext()
}

function goNext() {
  const pages = getCurrentPages()
  if (pages.length > 1) {
    uni.navigateBack()
  } else {
    uni.reLaunch({ url: '/pages/home/index' })
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
  padding-bottom: 80rpx;
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
  display: flex;
  flex-direction: column;
  align-items: center;
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

// ============================================================
// Profile Setup Step
// ============================================================
.setup-title {
  font-size: 36rpx;
  font-weight: 600;
  color: $textPrimary;
  display: block;
  margin-bottom: 48rpx;
}

.avatar-pick-area {
  margin-bottom: 40rpx;
}

.avatar-pick-btn {
  background: transparent !important;
  border: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  align-items: center;

  &::after {
    border: none;
  }
}

.avatar-preview {
  width: 160rpx;
  height: 160rpx;
  border-radius: 50%;
  border: 4rpx solid $green;
}

.avatar-placeholder {
  width: 160rpx;
  height: 160rpx;
  border-radius: 50%;
  background: #252525;
  border: 4rpx dashed $textMuted;
  display: flex;
  align-items: center;
  justify-content: center;
}

.avatar-placeholder-text {
  font-size: 64rpx;
}

.avatar-pick-hint {
  font-size: 24rpx;
  color: $textSecondary;
  margin-top: 16rpx;
}

.nickname-area {
  width: 100%;
  margin-bottom: 40rpx;
}

.nickname-input {
  width: 100%;
  height: 88rpx;
  background: #252525;
  border-radius: 20rpx;
  padding: 0 24rpx;
  font-size: 30rpx;
  color: $textPrimary;
  border: 1rpx solid #333;
}

.placeholder {
  color: $textMuted;
}

.setup-btn {
  width: 100%;
  height: 100rpx;
  background: linear-gradient(90deg, $green, $greenDark);
  border-radius: 100rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 24rpx rgba(7, 193, 96, 0.3);
}

.setup-btn-text {
  font-size: 32rpx;
  font-weight: 700;
  color: $textPrimary;
}

.skip-btn {
  margin-top: 24rpx;
  padding: 16rpx 32rpx;
}

.skip-btn-text {
  font-size: 28rpx;
  color: $textSecondary;
}

// ============================================================
// Footer
// ============================================================
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
