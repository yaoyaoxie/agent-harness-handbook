import DefaultTheme from 'vitepress/theme'
import Layout from './Layout.vue'
import Twikoo from './Twikoo.vue'
import ResourceHome from './ResourceHome.vue'
import ForumFeed from './ForumFeed.vue'
import './custom.css'

// 手风琴效果：展开一个一级模块时，自动收起其他已展开的模块。
// VitePress 无内置支持，通过事件委托在 caret 点击后同步其他组的折叠状态。
function setupSidebarAccordion() {
  if (typeof document === 'undefined') return
  document.addEventListener('click', (e) => {
    const caret = (e.target as HTMLElement).closest(
      '.VPSidebarItem.level-0 > .item .caret'
    )
    if (!caret) return
    const group = caret.closest('.VPSidebarItem.level-0')
    // 点击时带 collapsed 类 = 这次点击是“展开”动作，才需要收起其他组
    if (!group?.classList.contains('collapsed')) return
    setTimeout(() => {
      document
        .querySelectorAll('.VPSidebarItem.level-0.collapsible:not(.collapsed)')
        .forEach((other) => {
          if (other === group) return
          const otherCaret = other.querySelector<HTMLElement>(':scope > .item .caret')
          otherCaret?.click()
        })
    }, 50)
  })
}

setupSidebarAccordion()

export default {
  extends: DefaultTheme,
  Layout,
  enhanceApp({ app }) {
    app.component('Twikoo', Twikoo)
    app.component('ResourceHome', ResourceHome)
    app.component('ForumFeed', ForumFeed)
  }
}
