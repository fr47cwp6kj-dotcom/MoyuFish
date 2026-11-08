# 摸鱼鱼

**「摸鱼鱼」是原创项目。**

MoyuFish 是 macOS 14+ 菜单栏时间助手，只记录前台软件的使用时长。Safari、Chrome 等浏览器作为普通软件计时，不读取网页或标签页，不需要安装浏览器扩展。

菜单栏鱼保持静态；点击展开面板后，小鱼根据当前应用分类游动。摸鱼分类会累计提醒进度，专注与未分类只计入使用时长，忽略分类不计时。设置中可添加应用分类、调整空闲与提醒阈值、恢复方式和记录保留周期。

## 检查和构建

需要完整 Xcode 的 Swift 工具链。

```sh
swift test
swift run MoyuFishCoreChecks
bash Scripts/package.sh
```

打包脚本只生成 `build-artifacts/MoyuFish.app`，拒绝覆盖已有应用。重新打包可指定 `OUTPUT_DIR=/其他输出目录 bash Scripts/package.sh`。构建不会安装应用、设置登录启动或更改浏览器设置。

## 数据与隐私

记录仅保存在 `~/Library/Application Support/MoyuFish/usage.json`，不上传或同步。新记录仅包含应用名称、日期、分类和时长。应用不启动本地通讯服务，不读取网站域名、完整 URL、网页标题或页面内容。

升级保留原设置、分类和历史记录。为兼容旧版本，旧网站记录和规则仍可从文件读取及原样保存，但不参与当前统计、排行或分类；清空历史会删除所有活动记录，保留规则、设置和当前进度。

## 本机试用

打开 `build-artifacts/MoyuFish.app` 后，点击菜单栏鱼查看面板。分类规则按当前活动显示的应用名称填写；首次启动规则为空。

当前包使用本机 ad-hoc 签名，未做 Developer ID 签名或公证。未安装到 `/Applications`，未添加登录启动。本次仅更新已授权运行的本机试用版。
