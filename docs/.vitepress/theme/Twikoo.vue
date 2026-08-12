<script setup>
// Twikoo 评论区（腾讯云开发 CloudBase 版，国内可访问）。
// 使用方式：在 markdown 里写 <Twikoo />，每个页面 URL 对应独立讨论串。
// 部署后只需把下面的 TWIKOO_ENV_ID 换成你的 CloudBase 环境 ID。
import { ref, onMounted } from 'vue'

// 腾讯云 CloudBase 环境 HTTP 访问地址（Twikoo 云函数）
const TWIKOO_ENV_ID = 'https://harness-forum-d8gq5gty47c89c481.service.tcloudbase.com/twikoo'

const el = ref(null)

onMounted(() => {
  if (TWIKOO_ENV_ID === 'YOUR_TCB_ENV_ID') return
  const s = document.createElement('script')
  // npmmirror CDN（国内可达性优于 jsDelivr）
  s.src = 'https://registry.npmmirror.com/twikoo/latest/files/dist/twikoo.all.min.js'
  s.onload = () => {
    window.twikoo?.init({ envId: TWIKOO_ENV_ID, el: el.value })
  }
  document.head.appendChild(s)
})
</script>

<template>
  <div class="twikoo-wrap">
    <div v-if="TWIKOO_ENV_ID === 'YOUR_TCB_ENV_ID'" class="twikoo-pending">
      讨论区部署中，敬请期待。想先说话的，去<a href="/community/wishes">内容许愿池</a>旁边的
      <a href="https://github.com/yaoyaoxie/agent-harness-handbook/issues">仓库 Issue</a> 留言也行。
    </div>
    <div ref="el" id="twikoo-comment" />
  </div>
</template>

<style scoped>
.twikoo-wrap {
  margin-top: 32px;
}

.twikoo-pending {
  padding: 16px;
  border: 1px dashed var(--vp-c-divider);
  border-radius: 8px;
  color: var(--vp-c-text-2);
  font-size: 14px;
}
</style>
