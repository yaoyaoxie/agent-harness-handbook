// Twikoo / 腾讯云开发 CloudBase 共享配置与兼容补丁。

// CloudBase 环境 ID（不是环境名称，也不是 HTTP 访问地址）。
// 注意：不要用 https://xxx.service.tcloudbase.com/twikoo 这种 HTTP 触发地址——
// CloudBase HTTP 网关会把请求包装成 { body, httpMethod, ... } 再传给函数，
// 而 Twikoo 云函数只认 SDK 直传的 event 格式，会导致所有请求都返回
// 「Twikoo 云函数运行正常，请参考…完成前端的配置」。
export const TWIKOO_ENV_ID = 'harness-forum-d8gq5gty47c89c481'
export const TWIKOO_SRC = 'https://registry.npmmirror.com/twikoo/latest/files/dist/twikoo.all.min.js'

// twikoo 1.7.x 仍调用旧版 @cloudbase/js-sdk 的 auth.anonymousAuthProvider().signIn()，
// 但其打包的 SDK v4 已改名为 auth.signInAnonymously()。这里给 auth 对象桥接回旧 API，
// 否则 twikoo.init 直接抛 "anonymousAuthProvider is not a function"。
export function patchCloudbaseAuth() {
  const cb = window.cloudbase
  if (!cb || cb.__twikooAuthPatched || typeof cb.init !== 'function') return
  const rawInit = cb.init.bind(cb)
  cb.init = (options) => {
    const app = rawInit(options)
    const rawAuth = app.auth.bind(app)
    app.auth = (authOptions) => {
      const auth = rawAuth(authOptions)
      if (
        typeof auth.anonymousAuthProvider !== 'function' &&
        typeof auth.signInAnonymously === 'function'
      ) {
        auth.anonymousAuthProvider = () => ({ signIn: () => auth.signInAnonymously() })
      }
      return auth
    }
    return app
  }
  cb.__twikooAuthPatched = true
}
