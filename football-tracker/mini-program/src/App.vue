<template>
  <view />
</template>

<script setup lang="ts">
import { onLaunch } from '@dcloudio/uni-app'
import { ensureLogin } from './utils/api'

onLaunch(() => {
  ensureLogin()
})
</script>

<style>
page {
  background-color: #0a0a0a;
  color: #FFFFFF;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}
</style>
