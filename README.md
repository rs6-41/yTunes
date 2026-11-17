# yTunes

SafariからGUIでyt-dlpを実行するmacOSアプリケーションです。本体とSafari App Extensionで同じ設定画面を使用します。

動画・音声の形式、最大解像度、ファイル名、プレイリスト、メタデータ、サムネイル、保存場所をGUIで選択できます。保存場所はApp GroupのUserDefaultsで共有し、指定省略時は前回の値を使用します。

## 構成と実装

[doc/Architecture.md](doc/Architecture.md)に、ファイルの役割・処理の流れ・URLスキーム・保存先の永続化・確認方法をまとめています。

## URLスキーム

```text
ytunes://download?url=https%3A%2F%2Fexample.org%2Fvideo&destination=%2FUsers%2Fmain%2FDownloads
```

`url`は必須です。`destination`は保存先の絶対パスで、省略すると前回の保存場所を使用します。GUI設定は`settings`のJSONとして送信します。旧形式の`options`も受け付けますが、`settings`と同時には指定できません。

## ライセンス

yTunesは、Homebrewを使用してyt-dlpおよびFFmpegを別途インストールし、外部プロセスとして実行します。
これらのツールの実行ファイルやソースコードには、それぞれのライセンスが適用されます。

- Homebrew: https://brew.sh/
- yt-dlp: https://github.com/yt-dlp/yt-dlp
- FFmpeg: https://ffmpeg.org/