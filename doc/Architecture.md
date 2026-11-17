# ファイル構成と責務

## 全体の分担

| ディレクトリ | 役割 | ビルド対象 |
| --- | --- | --- |
| `Shared/Models` | フォームの設定、ダウンロード要求、共有保存先 | 本体・拡張 |
| `Shared/Integration` | URLスキームの生成・解析、旧オプションの分割 | 本体・拡張 |
| `Shared/Views` | 共通のSwiftUI設定フォーム | 本体・拡張 |
| `yTunes/Views` | 本体画面 | 本体 |
| `yTunes/Downloads` | 画面状態と実行待ちキュー | 本体 |
| `yTunes/Command` | ツール準備、外部プロセス実行 | 本体 |
| `extension/Models` | Safariのページ取得、画面状態、本体への送信 | 拡張 |
| `extension/Views` | 拡張のSwiftUI画面、AppKitとの橋渡し | 拡張 |
| `Tests` | 外部通信なしで実行できる回帰チェック | Xcodeターゲットには含めない |

## ファイル一覧

| ファイル | 責務 |
| --- | --- |
| `yTunes/yTunesApp.swift` | アプリ全体のDownloadModelを生成し、onOpenURLで受信を渡す |
| `yTunes/Views/ContentView.swift` | URL・共通設定フォーム・実行状態の表示とユーザー操作 |
| `yTunes/Downloads/DownloadModel.swift` | 準備状態と画面状態の更新、受信要求のキュー登録、1件ずつの実行 |
| `Shared/Models/DownloadFolderStore.swift` | App GroupのUserDefaultsに保存先パスとブックマークを保存・復元・更新 |
| `yTunes/Command/ToolSetup.swift` | Homebrew、yt-dlp、ffmpeg、ffprobeの確認・導入と実行パスの取得 |
| `yTunes/Command/YTDLPExecutor.swift` | Processの設定、引数・PATHの受け渡し、出力の収集、終了コードの返却 |
| `Shared/Models/DownloadSettings.swift` | Codableなフォーム設定とyt-dlp引数への変換 |
| `Shared/Models/DownloadRequest.swift` | 検証済みページURLと実行引数のスナップショット |
| `Shared/Integration/DownloadLink.swift` | ytunes://downloadの生成・検証、設定や旧引数の復元 |
| `Shared/Integration/YTDLPOptions.swift` | 旧optionsパラメーターの空白・引用符・エスケープ解析 |
| `Shared/Views/DownloadOptionsForm.swift` | 保存場所の選択、標準Picker・Toggleを持つ共通設定画面 |
| `Shared/Views/DividedVStack.swift` | 表示される子ビューの間だけにDividerを自動挿入 |
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
ytunes://download?url=<ページURL>&settings=<JSON設定>&destination=<保存先の絶対パス>
```

| パラメーター | 内容 |
| --- | --- |
| `url` | 必須。HTTPまたはHTTPSのページURL。重複不可 |
| `settings` | DownloadSettingsのJSON。GUIからの送信で使用。重複不可 |
| `destination` | 任意。保存先の絶対パス。重複不可。省略時は前回の保存先 |
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

## 保存場所

保存場所は共通のDownloadOptionsFormで選択します。App GroupのUserDefaultsにパスとセキュリティスコープ付きブックマークを保存し、本体とSafari拡張で共有します。フォームの表示はAppStorageで更新します。

URLスキームの`destination`に絶対パスを指定できます。例：`ytunes://download?url=https%3A%2F%2Fexample.org%2Fvideo&destination=%2FUsers%2Fmain%2FDownloads`。値はURLQueryItemでエンコードしてください。存在しないディレクトリは受け付けません。指定された保存場所は次回の既定値として保存します。省略時は前回の保存場所を使い、未設定の場合はフォルダ選択を待ちます。キューへ登録済みの保存場所は後のフォーム変更で変わりません。


## 共通設定画面のレイアウト

DownloadOptionsFormはSwiftUIのFormを使わず、DividedVStackと各行のHStackで構成します。これによりgrouped Formが自動付加する上下余白を避けています。背景は角丸、左右余白は12ポイント、各行の上下余白は10ポイントです。

DividedVStackはGroup(subviews:)で条件分岐後の子ビューを取り出し、先頭以外の行の直前にDividerを挿入します。動画／音声の切り替え時も、各項目にDividerを手書きする必要はありません。

選択項目は標準Pickerです。行のSpacerで右端へ配置しますが、Picker内部の文字配置は標準コントロールに任せています。独自のPicker用Viewは使いません。

保存場所はfileImporterで選択します。成功時にDownloadFolderStoreへ保存し、本体ではonFolderSelectedからDownloadModel.selectFolderを呼び、未設定で待機している要求の実行を再開します。選択失敗時はフォーム内にエラーを表示します。

## 保存先の永続化と既定値

| 項目 | 現在の実装 |
| --- | --- |
| 共有UserDefaults | `group.com.rs6apps.yTunes` |
| パスのキー | `downloadFolderPath`。フォームではAppStorageで参照 |
| ブックマークのキー | `downloadFolderBookmark` |
| 復元順序 | 共有ブックマーク → 旧standardブックマーク → 共有パス → 旧standardのselectedURL |
| 古いブックマーク | 解決時にstaleなら再保存を試みる |
| Safariからの送信 | 共有保存先を復元できた場合はdestinationへ含める |
| destination指定時 | 本体でディレクトリの存在を確認し、保存して次回の既定値にする |
| destination省略時 | キュー登録時に前回の保存先を復元する |
| 保存先未設定時 | 本体でフォルダ選択を待つ |

パスの共有とファイルアクセス権の取得は別です。永続アクセスにはブックマークを使い、実行期間中のstartAccessingSecurityScopedResource／stopAccessingSecurityScopedResourceはDownloadModelが管理します。パスだけの指定・復元ではOSのアクセス制限を解除できません。

DownloadRequest.destinationURLはURL解析時には省略可能です。本体がキューへ追加するときに既定値を補い、保存先が決まった要求は後の設定変更に影響されません。未設定で追加された要求は、実行時の選択済みフォルダを使用します。

## 設定JSONのフィールド

| フィールド | 値 | 初期値 |
| --- | --- | --- |
| media | video / audio | video |
| videoFormat | automatic / mp4 / mkv / webm | automatic |
| audioFormat | best / mp3 / m4a / flac / wav / opus | mp3 |
| resolution | best / p2160 / p1440 / p1080 / p720 / p480 | best |
| filename | titleAndID / title / dateAndTitle | titleAndID |
| downloadPlaylist | Bool | false |
| embedMetadata | Bool | false |
| embedThumbnail | Bool | false |

保存先はこのJSONには含めず、独立したdestinationパラメーターで渡します。保存先以外のフォーム設定は現在UserDefaultsへ永続化していません。

## 確認方法

リポジトリのルートで次を実行します。

```sh
swiftc -module-cache-path /tmp/ytunes-swift-cache Shared/Models/*.swift Shared/Integration/*.swift yTunes/Command/YTDLPExecutor.swift Tests/CoreTests.swift -o /tmp/ytunes-core-tests
/tmp/ytunes-core-tests
```

現在のCoreTestsは、動画・音声設定からの引数生成、設定JSON、URLスキームの設定・保存先の往復、日本語や特殊文字を含むパス、空・相対パスの拒否、echoを用いたProcess引数を確認します。実際の動画取得や共有UserDefaultsの永続化、ブックマークのアクセス権、SafariのUIは検証しません。

実動作では、本体と拡張のビルド後、双方からのフォルダ選択、再起動後の復元、destination省略時の既定値、明示指定時の保存先変更を確認してください。フォームの動画／音声切り替えによる区切り線表示も確認対象です。
