# windowcat 首发建议

建议先发小范围测试版，收集真实菜单栏拖动、不同 Mac 与显示器的反馈，再扩大推广。当前 v0.1.0 尚未 Apple 公证，不要宣传成已通过全部兼容性测试。

## 推荐顺序

1. **V2EX「分享创造」**：首批开发者和 Mac 用户反馈。帖子附 GitHub、安装说明和一段 10–15 秒演示，直接说明 macOS 13+、Apple Silicon 与未公证状态。节点：https://www.v2ex.com/go/create ，官方节点说明：https://www.v2ex.com/help/node 。
2. **小红书 / B 站**：适合展示猫趴在浏览器或编辑器边缘的视觉效果。建议标题「我给 Mac 窗口养了一只猫」。这是一项受众与形式判断，不保证流量；发布前查看对应平台最新规则。
3. **X（日语与英语）**：分别发短文和演示，重点展示从顶部菜单栏拖放、跟随窗口、打盹。不要堆标签或刷相同内容。
4. **r/macapps**：用户匹配，但有明确自荐限制。2026 年 10 月的 App Pile 要求未取得主版资格的应用发在集中帖，采用 Problem / Comparison / Pricing 格式，不能直接放 ZIP/DMG 下载链接，而且计入 30 天推广频率限制。先读当月集中帖和社区规则：https://www.reddit.com/r/macapps/comments/1wuoav5/megathread_the_app_pile_october_2026/ 。对比竞品须实际体验，别编造“更省电”等结论。
5. **Show HN**：放在后面。需要可直接试用、由发布者亲自投入且愿意讨论的作品，不适合只发宣传落地页或快速生成的一次性项目。准备解释窗口跟踪、原生 AppKit 的选择和限制；不要找人刷票。规则：https://news.ycombinator.com/showhn.html 。

## 演示脚本（待录制）

- 0–4 秒：从菜单栏猫图标拖到 Finder 或浏览器，展示绿色目标框。
- 4–8 秒：移动或缩放窗口，小猫仍在窗口边缘。
- 8–12 秒：从菜单切换打盹或小球。
- 12–15 秒：显示名称 windowcat、macOS 13+ 和 GitHub 地址。

请用没有私人信息的真实窗口录制。当前仓库没有声称已录制的演示视频。

## 可修改后发布的文案

### 中文

我做了一个 Mac 小工具 windowcat：从顶部菜单栏拖一只像素猫到窗口，它就会沿着窗口边缘走路、打盹，还能玩小球和逗猫棒。

原生 Swift + AppKit，支持中英日，基础跟踪无需辅助功能或屏幕录制权限。目前是 macOS 13+ / Apple Silicon 测试版，尚未 Apple 公证。想找一些不同机型和多显示器用户试用，欢迎反馈拖放、跟随与遮挡问题。

下载和安装：https://github.com/kokoro-ele/window-cat
猫素材：Elthen。

### English

I made windowcat, a small native Mac companion. Drag a pixel cat from the menu bar onto an app window; it can walk around the edges, nap, or play with a ball or teaser.

English, Japanese and Simplified Chinese. Basic tracking needs no Accessibility or Screen Recording permission. Early release for macOS 13+ and Apple Silicon; not Apple-notarized yet. Feedback on window dragging and multi-display behavior is welcome.

https://github.com/kokoro-ele/window-cat
Cat artwork by Elthen.

### 日本語

Mac のウインドウに小さな猫を置ける「windowcat」を作りました。メニューバーからウインドウへドラッグすると、ふちを歩いたり、お昼寝したり、ボールや猫じゃらしで遊んだりします。

日本語・英語・簡体字中国語に対応。基本操作にアクセシビリティ・画面収録の許可は不要です。macOS 13 以降 / Apple Silicon 向けの初期版で、Apple の公証はまだ受けていません。複数ディスプレイや追従動作のフィードバックを歓迎します。

https://github.com/kokoro-ele/window-cat
猫の素材：Elthen。
