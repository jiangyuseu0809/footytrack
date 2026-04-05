<template>
  <view class="page">
    <!-- Header -->
    <view class="header">
      <view class="header-back" @tap="goBack">
        <text class="header-back-icon">‹</text>
      </view>
      <text class="header-title">意见反馈</text>
    </view>

    <scroll-view scroll-y class="scroll-area">
      <view class="section">
        <!-- Content Input -->
        <view class="card">
          <text class="card-label">问题描述</text>
          <textarea
            v-model="content"
            class="feedback-textarea"
            placeholder="请详细描述你遇到的问题或建议..."
            placeholder-class="textarea-placeholder"
            :maxlength="500"
            auto-height
          />
          <text class="char-count">{{ content.length }}/500</text>
        </view>
      </view>

      <!-- Image Attachment -->
      <view class="section">
        <view class="card">
          <text class="card-label">截图（可选，最多3张）</text>
          <view class="image-grid">
            <view
              v-for="(img, idx) in images"
              :key="idx"
              class="image-item"
            >
              <image :src="img" class="image-preview" mode="aspectFill" @tap="previewImage(idx)" />
              <view class="image-remove" @tap="removeImage(idx)">
                <text class="image-remove-icon">✕</text>
              </view>
            </view>
            <view v-if="images.length < 3" class="image-add" @tap="chooseImage">
              <text class="image-add-icon">+</text>
              <text class="image-add-text">添加截图</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Submit -->
      <view class="section section--last">
        <view
          class="submit-btn"
          :class="{ 'submit-btn--disabled': !canSubmit || submitting }"
          @tap="handleSubmit"
        >
          <text class="submit-btn-text">{{ submitting ? '提交中...' : '提交反馈' }}</text>
        </view>
      </view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { submitFeedback } from '../../utils/api'

const content = ref('')
const images = ref<string[]>([])
const submitting = ref(false)

const canSubmit = computed(() => content.value.trim().length > 0)

function goBack() {
  uni.navigateBack()
}

function chooseImage() {
  const remain = 3 - images.value.length
  if (remain <= 0) return
  uni.chooseImage({
    count: remain,
    sizeType: ['compressed'],
    sourceType: ['album', 'camera'],
    success: (res) => {
      images.value.push(...res.tempFilePaths)
    },
  })
}

function removeImage(idx: number) {
  images.value.splice(idx, 1)
}

function previewImage(idx: number) {
  uni.previewImage({
    urls: images.value,
    current: images.value[idx],
  })
}

async function uploadImages(): Promise<string[]> {
  const urls: string[] = []
  for (const filePath of images.value) {
    try {
      const url = await new Promise<string>((resolve, reject) => {
        uni.uploadFile({
          url: 'https://footytrack.cn/api/feedback/upload',
          filePath,
          name: 'file',
          header: {
            Authorization: `Bearer ${uni.getStorageSync('auth_token') || ''}`,
          },
          success: (res) => {
            if (res.statusCode >= 200 && res.statusCode < 300) {
              const data = JSON.parse(res.data)
              resolve(data.url)
            } else {
              reject(new Error('上传失败'))
            }
          },
          fail: () => reject(new Error('上传失败')),
        })
      })
      urls.push(url)
    } catch {
      // Skip failed uploads, still submit text feedback
    }
  }
  return urls
}

async function handleSubmit() {
  if (!canSubmit.value || submitting.value) return
  submitting.value = true
  try {
    let imageUrls: string[] | undefined
    if (images.value.length > 0) {
      imageUrls = await uploadImages()
    }
    await submitFeedback(content.value.trim(), imageUrls)
    uni.showToast({ title: '感谢你的反馈', icon: 'success' })
    setTimeout(() => uni.navigateBack(), 1500)
  } catch (e) {
    uni.showToast({ title: '提交失败，请重试', icon: 'none' })
  } finally {
    submitting.value = false
  }
}
</script>

<style lang="scss" scoped>
$pageBg: #0a0a0a;
$cardBg: #1a1a1a;
$cardBgLight: #252525;
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
  height: calc(100vh - 200rpx);
}

// ============================================================
// Header
// ============================================================
.header {
  background: $cardBg;
  padding: 120rpx 32rpx 28rpx;
  border-bottom: $border;
  display: flex;
  align-items: center;
  position: relative;
}

.header-back {
  position: absolute;
  left: 20rpx;
  bottom: 20rpx;
  width: 64rpx;
  height: 64rpx;
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
  display: block;
  text-align: center;
  flex: 1;
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
// Card
// ============================================================
.card {
  background: $cardBg;
  border-radius: 32rpx;
  padding: 28rpx;
  border: $border;
}

.card-label {
  font-size: 28rpx;
  font-weight: 600;
  color: $textPrimary;
  display: block;
  margin-bottom: 20rpx;
}

// ============================================================
// Textarea
// ============================================================
.feedback-textarea {
  width: 100%;
  min-height: 240rpx;
  font-size: 28rpx;
  color: $textPrimary;
  background: $cardBgLight;
  border-radius: 16rpx;
  padding: 20rpx;
  box-sizing: border-box;
  line-height: 1.6;
}

.textarea-placeholder {
  color: $textMuted;
  font-size: 28rpx;
}

.char-count {
  font-size: 22rpx;
  color: $textMuted;
  display: block;
  text-align: right;
  margin-top: 12rpx;
}

// ============================================================
// Image Grid
// ============================================================
.image-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 16rpx;
}

.image-item {
  position: relative;
  width: 180rpx;
  height: 180rpx;
  border-radius: 16rpx;
  overflow: hidden;
}

.image-preview {
  width: 100%;
  height: 100%;
}

.image-remove {
  position: absolute;
  top: 0;
  right: 0;
  width: 44rpx;
  height: 44rpx;
  background: rgba(0, 0, 0, 0.6);
  border-radius: 0 16rpx 0 16rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.image-remove-icon {
  font-size: 22rpx;
  color: #FFFFFF;
}

.image-add {
  width: 180rpx;
  height: 180rpx;
  border-radius: 16rpx;
  background: $cardBgLight;
  border: 2rpx dashed #3a3a3a;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8rpx;
}

.image-add-icon {
  font-size: 48rpx;
  color: $textMuted;
  line-height: 1;
}

.image-add-text {
  font-size: 22rpx;
  color: $textMuted;
}

// ============================================================
// Submit Button
// ============================================================
.submit-btn {
  background: linear-gradient(135deg, $green, $greenDark);
  border-radius: 100rpx;
  padding: 28rpx 0;
  text-align: center;
  box-shadow: 0 8rpx 32rpx rgba(7, 193, 96, 0.3);
}

.submit-btn--disabled {
  opacity: 0.4;
  box-shadow: none;
}

.submit-btn-text {
  font-size: 30rpx;
  font-weight: 600;
  color: #FFFFFF;
}
</style>
