<template>
  <view class="page">
    <!-- Header -->
    <view class="header" :style="{ paddingTop: statusBarHeight + 'px' }">
      <view class="header-inner" :style="{ height: navBarHeight + 'px' }">
        <view class="header-back" @tap="goBack">
          <text class="header-back-icon">&#x2039;</text>
        </view>
        <text class="header-title">打赏支持</text>
      </view>
    </view>

    <scroll-view scroll-y class="scroll-area" :style="{ height: 'calc(100vh - ' + (statusBarHeight + navBarHeight) + 'px)' }">
      <!-- Header -->
      <view class="hero">
        <text class="hero-emoji">&#x2615;</text>
        <text class="hero-title">请开发者喝杯咖啡</text>
        <text class="hero-sub">你的支持是我持续更新的动力</text>
      </view>

      <!-- Amount Grid -->
      <view class="section">
        <view class="amount-grid">
          <view
            v-for="item in amounts"
            :key="item.cents"
            class="amount-card"
            :class="{ active: selected === item.cents }"
            @tap="selected = item.cents"
          >
            <text class="amount-value">{{ item.label }}</text>
            <text class="amount-unit">元</text>
          </view>
        </view>
      </view>

      <!-- Pay Button -->
      <view class="section">
        <view class="pay-btn" :class="{ disabled: paying }" @tap="handlePay">
          <text class="pay-btn-text">{{ paying ? '支付中...' : '确认打赏' }}</text>
        </view>
      </view>

      <view class="footer">
        <text class="footer-text">感谢你的支持 :)</text>
      </view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { createDonation } from '../../utils/api'

const menuBtn = uni.getMenuButtonBoundingClientRect()
const sysInfo = uni.getSystemInfoSync()
const statusBarHeight = sysInfo.statusBarHeight || 44
const navBarHeight = (menuBtn.top - statusBarHeight) * 2 + menuBtn.height

const amounts = [
  { cents: 100, label: '1' },
  { cents: 200, label: '2' },
  { cents: 500, label: '5' },
  { cents: 1000, label: '10' },
  { cents: 2000, label: '20' },
  { cents: 5000, label: '50' },
]

const selected = ref(500)
const paying = ref(false)

function goBack() {
  uni.navigateBack()
}

async function handlePay() {
  if (paying.value) return
  paying.value = true

  try {
    const params = await createDonation(selected.value)

    await new Promise<void>((resolve, reject) => {
      uni.requestPayment({
        provider: 'wxpay',
        timeStamp: params.timeStamp,
        nonceStr: params.nonceStr,
        package: params.package,
        signType: params.signType as 'RSA',
        paySign: params.paySign,
        success: () => resolve(),
        fail: (err) => reject(err),
      })
    })

    uni.showToast({ title: '感谢你的打赏!', icon: 'success' })
    setTimeout(() => uni.navigateBack(), 1500)
  } catch (err: any) {
    if (err?.errMsg?.includes('cancel')) {
      uni.showToast({ title: '已取消支付', icon: 'none' })
    } else {
      uni.showToast({ title: err?.message || '支付失败', icon: 'none' })
    }
  } finally {
    paying.value = false
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

.header {
  background: $cardBg;
  padding-left: 32rpx;
  padding-right: 32rpx;
  border-bottom: $border;
}

.header-inner {
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
}

.header-back {
  position: absolute;
  left: 0;
  width: 64rpx;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.header-back-icon {
  font-size: 48rpx;
  color: $textPrimary;
  font-weight: 300;
}

.header-title {
  font-size: 34rpx;
  font-weight: 700;
  color: $textPrimary;
}

.hero {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 60rpx 32rpx 40rpx;
}

.hero-emoji {
  font-size: 80rpx;
  margin-bottom: 20rpx;
}

.hero-title {
  font-size: 36rpx;
  font-weight: 700;
  color: $textPrimary;
  margin-bottom: 12rpx;
}

.hero-sub {
  font-size: 26rpx;
  color: $textSecondary;
}

.section {
  padding: 0 32rpx 32rpx;
}

.amount-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 20rpx;
}

.amount-card {
  background: $cardBg;
  border: 2rpx solid #2a2a2a;
  border-radius: 24rpx;
  padding: 36rpx 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4rpx;
  transition: all 0.2s;

  &.active {
    border-color: $green;
    background: rgba(7, 193, 96, 0.08);
    box-shadow: 0 0 24rpx rgba(7, 193, 96, 0.15);
  }
}

.amount-value {
  font-size: 44rpx;
  font-weight: 700;
  color: $textPrimary;
}

.amount-unit {
  font-size: 24rpx;
  color: $textMuted;
}

.amount-card.active .amount-value {
  color: $green;
}

.pay-btn {
  background: linear-gradient(135deg, $green, $greenDark);
  border-radius: 100rpx;
  padding: 28rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 24rpx rgba(7, 193, 96, 0.3);

  &.disabled {
    opacity: 0.6;
  }
}

.pay-btn-text {
  font-size: 32rpx;
  font-weight: 600;
  color: #FFFFFF;
}

.footer {
  text-align: center;
  padding: 40rpx 0 120rpx;
}

.footer-text {
  font-size: 24rpx;
  color: $textMuted;
}
</style>
