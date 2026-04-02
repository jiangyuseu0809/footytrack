<script setup lang="ts">
import { onLaunch } from '@dcloudio/uni-app'
import { isLoggedIn } from './utils/api'

onLaunch(() => {
  if (!isLoggedIn()) {
    uni.reLaunch({ url: '/pages/login/index' })
  }
})
</script>

<style>
page {
  background-color: #0D1117;
  color: #FFFFFF;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}
</style>
