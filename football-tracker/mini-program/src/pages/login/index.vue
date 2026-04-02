<template>
  <view class="page">
    <view class="login-container">
      <view class="logo-area">
        <text class="logo">⚽</text>
        <text class="app-name">野球记</text>
        <text class="app-desc">记录每一场球，追踪每一步成长</text>
      </view>

      <button class="wx-btn" @tap="handleWxLogin">
        微信一键登录
      </button>

      <text v-if="errMsg" class="error">{{ errMsg }}</text>
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
    uni.reLaunch({ url: '/pages/home/index' })
  } catch (e: any) {
    errMsg.value = e.message || '微信登录失败'
  }
}
</script>

<style lang="scss" scoped>
.page {
  min-height: 100vh;
  background: #0D1117;
  display: flex;
  align-items: center;
  justify-content: center;
}
.login-container {
  padding: 0 48rpx;
  width: 100%;
}
.logo-area {
  text-align: center;
  padding: 0 0 80rpx;
  .logo { font-size: 96rpx; display: block; }
  .app-name { font-size: 44rpx; font-weight: 700; color: #fff; display: block; margin-top: 16rpx; }
  .app-desc { font-size: 24rpx; color: #8B949E; display: block; margin-top: 8rpx; }
}
.wx-btn {
  background: #07C160 !important;
  color: #fff !important;
  font-size: 30rpx;
  font-weight: 600;
  border-radius: 44rpx;
  height: 88rpx;
  line-height: 88rpx;
  border: none;
  width: 100%;
}
.error {
  display: block;
  text-align: center;
  color: #FF4757;
  font-size: 24rpx;
  margin-top: 32rpx;
}
</style>
