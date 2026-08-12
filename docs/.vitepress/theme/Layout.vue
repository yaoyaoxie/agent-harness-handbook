<script setup>
import DefaultTheme from 'vitepress/theme'
import { useData } from 'vitepress'
import SidebarOutline from './SidebarOutline.vue'

const { frontmatter } = useData()
</script>

<template>
  <DefaultTheme.Layout>
    <template #sidebar-nav-after>
      <SidebarOutline />
    </template>
    <template #doc-before>
      <div v-if="frontmatter.dataAsOf" class="data-asof">
        本页含时效性内容，数据截止于 <strong>{{ frontmatter.dataAsOf }}</strong
        >；JD、价格、产品功能等信息可能已变化，引用前请核对原始出处。
      </div>
    </template>
  </DefaultTheme.Layout>
</template>

<style scoped>
.data-asof {
  margin-bottom: 24px;
  padding: 10px 16px;
  border: 1px solid var(--vp-c-warning-2, #e2c08d);
  border-radius: 8px;
  background-color: var(--vp-c-warning-soft, rgba(226, 192, 141, 0.14));
  color: var(--vp-c-text-1);
  font-size: 14px;
  line-height: 1.6;
}
</style>
