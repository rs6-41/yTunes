# ファイル構成と責務

## 全体の分担

| ディレクトリ | 役割 | ビルド対象 |
| --- | --- | --- |
| `Shared/Models` | フォームの設定、変更されないダウンロード要求 | 本体・拡張 |
| `Shared/Integration` | URLスキームの生成・解析、旧オプションの分割 | 本体・拡張 |
| `Shared/Views` | 共通のSwiftUI設定フォーム | 本体・拡張 |
| `yTunes/Views` | 本体画面 | 本体 |
| `yTunes/Downloads` | 画面状態、キュー、保存先の永続化 | 本体 |
| `yTunes/Command` | ツール準備、外部プロセス実行 | 本体 |
| `extension/Models` | Safariのページ取得、画面状態、本体への送信 | 拡張 |
| `extension/Views` | 拡張のSwiftUI画面、AppKitとの橋渡し | 拡張 |
| `Tests` | 外部通信なしで実行できる回帰チェック | Xcodeターゲットには含めない |

## ファイル一覧

| ファイル | 責務 |
| --- | --- |
| `yTunes/yTunesApp.swift` | アプリ全体のDownloadModelを生成し、onOpenURLで受信を渡す |
| `yTunes/Views/ContentView.swift` | URL・保存先・フォーム・実行状態の表示とユーザー操作 |
| `yTunes/Downloads/DownloadModel.swift` | 準備状態と画面状態の更新、受信要求のキュー登録、1件ずつの実行 |
| `yTunes/Downloads/DownloadFolderStore.swift` | セキュリティスコープ付きブックマークの保存・復元・更新 |
| `yTunes/Command/ToolSetup.swift` | Homebrew、yt-dlp、ffmpeg、ffprobeの確認・導入と実行パスの取得 |
| `yTunes/Command/YTDLPExecutor.swift` | Processの設定、引数・PATHの受け渡し、出力の収集、終了コードの返却 |
| `Shared/Models/DownloadSettings.swift` | Codableなフォーム設定とyt-dlp引数への変換 |
| `Shared/Models/DownloadRequest.swift` | 検証済みページURLと実行引数のスナップショット |
| `Shared/Integration/DownloadLink.swift` | ytunes://downloadの生成・検証、設定や旧引数の復元 |
| `Shared/Integration/YTDLPOptions.swift` | 旧optionsパラメーターの空白・引用符・エスケープ解析 |
| `Shared/Views/DownloadOptionsForm.swift` | 本体と拡張で共通のPicker・Toggle |
| `extension/SafariExtensionHandler.swift` | Safariからのコールバックをポップアップに渡す |
| `extension/Views/SafariPopoverViewController.swift` | NSHostingViewでSwiftUIを表示し、ポップアップのサイズを設定 |
| `extension/Models/SafariPopoverModel.swift` | アクティブページURLの取得、URLスキームで本体を起動 |
| `extension/Views/SafariPopoverView.swift` | ページURL・状態・設定フォーム・送信ボタンの表示 |
| `yTunes/Info.plist` | ytunes URLスキームの登録 |
| `extension/Info.plist` | Safari App Extensionの登録、ツールバーボタン、サイトアクセス範囲 |
| `extension/ToolbarIcon.pdf` | Safariが要求するPDF形式のツールバー画像 |
| 各ターゲットの`Localizable.xcstrings` | SwiftUIの表示文言とエラーメッセージ |
| `extension/ja.lproj/InfoPlist.strings` | 拡張の名前・説明の日本語表示 |
| 各ターゲットの`*.entitlements` | 署名に使用する権限 |
| `yTunes.xcodeproj/project.xcproj` | ターゲット、共有フォルダの所属、ビルド設定 |
| `Tests/CoreTests.swift` | URL連携・設定・引数・外部プロセス実行の回帰チェック |

## 処理の流れ

### 本体からダウンロード

ContentViewのフォームはDownloadSettingsを更新します。開始ボタンでDownloadModelがURLを検証し、DownloadRequestを生成してキューに追加します。DownloadRequestはその時点の設定と引数を保持するため、待機中にフォームを変更しても実行内容は変わりません。

ツールと保存先が揃うと、DownloadModelは先頭の1件をYTDLPExecutorへ渡します。実行完了後に画面のログ・結果を更新し、次の1件へ進みます。保存先のアクセス権は実行期間中保持します。

### Safariからダウンロード

SafariExtensionHandlerが、表示するSafariPopoverViewControllerと表示前後の通知をSafariに提供します。コントローラーはSwiftUIの画面をNSHostingViewで表示し、SafariPopoverModelにページ取得を依頼します。

モデルはアクティブウインドウのタブ、ページ、ページのプロパティの順に取得します。取得は非同期なので、表示ごとの識別子を照合し、前回表示時や閉じた後の応答を破棄します。

送信時はDownloadLinkがフォーム設定を含むURLを生成し、NSWorkspaceが本体を開きます。本体のonOpenURLからDownloadModel.receiveへ渡り、DownloadLink.parseによってDownloadRequestへ変換されます。その後は本体からのダウンロードと同じキュー・実行経路を使います。

拡張側の「送信しました」はOSに本体の起動を依頼できたことを表します。ダウンロード完了は本体で確認します。

## URLスキーム

```text
ytunes://download?url=<ページURL>&settings=<JSON設定>
```

| パラメーター | 内容 |
| --- | --- |
| `url` | 必須。HTTPまたはHTTPSのページURL。重複不可 |
| `settings` | DownloadSettingsのJSON。GUIからの送信で使用。重複不可 |
| `options` | 旧形式との互換性のための引数テキスト。重複不可。settingsとの併用不可 |

値はURLQueryItemを使用してエンコードします。ページURLに含まれる`&`・`#`・日本語を手作業で連結しないでください。settings内のフィールドはDownloadSettingsのプロパティ名・enumのrawValueに対応します。現在は全フィールドを含むJSONを受け付けます。

settingsもoptionsも省略した場合、従来のURLスキームと同じく追加引数なしで実行します。旧optionsは引用符とバックスラッシュによる引数分割に対応しますが、シェルの変数展開やコマンド置換はしません。

## フォームと引数の対応

| 設定 | 生成する主な引数 |
| --- | --- |
| 動画＋音声 | yt-dlpの既定の映像・音声選択 |
| 最大解像度 | `--format bv*[height<=N]+ba/b[height<=N]` |
| 動画形式 | `--merge-output-format`と`--remux-video` |
| 音声のみ | `--extract-audio`、`--audio-format`、`--audio-quality 0` |
| ファイル名 | `--output`と選択したテンプレート |
| プレイリスト | `--yes-playlist`または`--no-playlist` |
| メタデータ | 有効時に`--embed-metadata` |
| サムネイル | 有効時に`--embed-thumbnail` |

動画形式はコンテナーの指定で、映像の再エンコードは行いません。元のコーデックによっては指定コンテナーへ格納できず失敗する場合があります。音声・サムネイル処理も配信形式によって利用可能な組み合わせが異なります。

## 実行とスレッド

本体の画面状態とキューはMainActor上で管理します。YTDLPExecutorはバックグラウンドキュー上でProcessを実行し、標準出力・標準エラーを同じPipeへ収集します。終了待ちより先にPipeを読み、満杯によるデッドロックを防ぎます。現在は終了後にまとめてログを返す構成です。

シェル経由ではなくProcess.argumentsで引数を渡します。最後に`--`とページURLを置いて、ページURLがオプションとして解釈されないようにします。