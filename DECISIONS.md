# DECISIONS（自分で決めた仕様とその理由）

## 2026-09-25
- **Godot 4.3 stable** を採用（4.x系で安定、ヘッドレスバイナリが取得できたため）。
- **テストフレームワーク自作**（`tests/test_case.gd` + `tests/test_runner.gd`）。GUT 等の外部アドオン依存を避け、`--headless -s` だけで完結させる。
- **`class_name` を使用**し、テスト実行前に `godot --headless --import` でクラスキャッシュを再生成する運用にする（ヘッドレスで class_name を解決するために必要と確認）。
- **内部IDは英数字 snake_case**（例: `renny`, `flame_domain`, `swords_dance`）。表示名は `data/localization/ja.json` のみ。
- **倍率の丸めは Pokémon Showdown 準拠の 4096 基準チェーン**（`modify(value, mod) = floor((value*mod + 2047) / 4096)`、半分以下切り捨て）を採用。本編第5世代以降の実測と一致することが知られているため。
- **効果ハンドラは Dictionary of Callable**（効果ID → {イベント名: Callable}）で実装。クラス爆発を避けつつフック追加を容易にする。
- **技の特殊効果はJSONの `effect`/`handlers` フィールドで汎用ハンドラIDを参照**する（コードに技名を書かない）。

## 2026-09-25（Phase 1〜2）
- **効果ハンドラは名前付きメソッド**（`Conditions`/`Abilities`/`Items`/`MoveEffects` の各インスタンスメソッドを Callable として登録）。ラムダの多行構文に依存せず、デバッグしやすい。
- **もちものの汎用処理はデータ駆動**：`handler` フィールド（choice / type_boost / resist_berry / status_berry / hp_berry / pinch_berry / terrain_seed / passive）＋ `params`、および `flags`（hazard_immune, prevents_trapping, powder_immune, weather_immune, screen_extender, no_contact, airborne 等）。コードにアイテムIDを書かない。
- **天候・フィールドもデータ駆動**：`data/weather/weather.json`（boost/nerf/damage/immune_types/spd_boost_type/def_boost_type/prevents_status）、`data/terrain/terrain.json`（boost_type/heal/weakens_*/blocks_status/blocks_priority）。
- **技の特殊効果は `effect` フィールドで汎用ハンドラIDを参照**（protect, substitute, rest, sleep_talk, knock_off, trick, charge_move …）。`base_power_callback` / `damage_callback` も汎用ID（weight, speed_ratio, low_hp, hex, facade …）。
- **技数は465**（目安150〜200を超過）。ロースターの個性付けとサブウェポンの選択肢を確保するため。使われない技は学習リストに入れないだけで害はない。
- **すべての持続時間は Showdown 準拠**：残留処理の先頭で duration を減らし 0 で終了（天候5ターン＝使用ターン＋4、リフレクター5、追い風4、あくび2、ちょうはつ3、アンコール3、かなしばり4）。
- **せいなるひかりは「受ける威力」補正として onSourceBasePower（威力×0.7）で実装**（ダメージ補正ではなく威力補正、ユーザー文言の「威力」に合わせた）。
- **めざめるししの発動判定**：`StatusCure` イベント（自然回復・ねむる後・きのみ・いやしのすず等すべての回復経路）で `woke_turn = 現在ターン` を記録し、`onModifyAtk` で `woke_turn == 現在ターン` のとき攻撃×2。カゴのみ＋ねむるは同ターン内に技を使い終えているため実質恩恵なし（本仕様の自然な帰結として許容）。
- **ミニマムボディは命中補正**（onModifyAccuracy で ×1/1.5 = 2730/4096 → 命中100の技が67%）。回避ランクとは乗算で重複する。
- **AIは相手の技構成を参照できる**（シミュレーション用。人間対CPUでも「見えている」前提でよいと判断。強すぎれば Phase 3 で制限）。
- **AIはねむり残りターン（status_state.time）を参照する**。ねむる後の起床ターンは既知情報なので攻撃技を選ぶ。
- **シミュレーション形式**：(b) は「ランダム3体チーム、3対3（交代あり）」と解釈して実装（`mode=3v3`）。`mode=6v6` も実装済み。
- **1v1 の試行数**：調整ループ中は各型対戦100戦（約35分/4並列）、最終確認で1000戦（約6時間）を実施する。
- **セーブ→ロード一致テストは Phase 4（RPG層）で実装**（戦闘スナップショット API `Battle.snapshot()` は用意済み）。
- **進化条件**：ネオ → トランス は Lv34。リージョンフォームは特定エリアの野生出現＋専用進化アイテム（Phase 4 で確定）。
- **2026-09-25 合格判定は 6v6（ランダム6体チーム、ヘッドレス評価関数AI同士）で行う**。初回プロンプトの合格基準は「6対6で」と明記されているため。3v3 は調整中の高速な補助指標として併用（Round 1〜7 は 3v3 で実施）。
- **2026-09-25 Phase 5 コンテンツ**: ボス撃破後にはじまりの町の東門が開き「うみべのみち」→「みなとまち」→「バトルホール」へ。うみおとこ（3体）とホールマスター（4体）は `format: "doubles"` のダブルバトル、ライバル戦はシングル。手持ちが1体でもダブル戦は成立する（空きスロットのまま）—ガイドNPCが2体以上を推奨する文言のみ。
- **2026-09-25 リージョンフォームの入手**: リージョンのほら穴（ムニR竜／R虫／Rノ、ヒュウR、ゲルR毒、ジンパチR、レニィR）とうみべのみち（トランスR、ゲルR悪）の野生出現。ネオ→トランスR は「しんぴのいし」（ハイカーから入手／未実装のショップ販売なし）。
- **2026-09-25 PP は戦闘間で持ち越さない**（PokemonSet に PP を保存しない）。RPGの短さを考慮した簡略化。TODO に記録。
