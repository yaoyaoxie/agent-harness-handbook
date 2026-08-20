<script setup>
// Twikoo 评论区（腾讯云开发 CloudBase 版，国内可访问）。
// 使用方式：在 markdown 里写 <Twikoo />，每个页面 URL 对应独立讨论串。
import { ref, onMounted } from 'vue'
import { TWIKOO_ENV_ID, TWIKOO_SRC, patchCloudbaseAuth } from './twikoo-env'

const el = ref(null)

onMounted(() => {
  const s = document.createElement('script')
  // npmmirror CDN（国内可达性优于 jsDelivr）
  s.src = TWIKOO_SRC
  s.onload = () => {
    patchCloudbaseAuth()
    window.twikoo?.init({ envId: TWIKOO_ENV_ID, el: el.value })
  }
  document.head.appendChild(s)
})
</script>

<template>
  <div class="twikoo-wrap">
    <div ref="el" id="twikoo-comment" />
  </div>
</template>

<style scoped>
.twikoo-wrap {
  margin-top: 32px;
}
</style>
