# PROJECT_STATE

## 現在フェーズ
Phase 2 合格（6v6 Round 9）→ Phase 3（2D対戦UI）実装中。1v1 最終確認（各型100戦）を並行実行中。

## 環境
- Godot 4.3 stable（`/usr/local/bin/godot`、ヘッドレス動作確認済み）
- テスト実行: `./run_tests.sh [filter]`（内部で `--import` → `tests/test_runner.gd`、SCRIPT ERROR も失敗扱い）
- シミュレーション: `tools/simulator/run_sim.sh <1v1|3v3|6v6> <battles> [procs] [ai] [tag]` → `reports/balance_<tag>_<mode>.md`
- 一括: `tools/simulator/run_all.sh <tag>`（3v3 20000戦 → 1v1 各型100戦）
- 1試合ログ確認: `godot --headless --path . -s tools/simulator/replay.gd -- a=renny sa=rest_talk b=gel sb=specs seed=3`
- データ再生成: `python3 tools/data_gen/gen_moves.py && python3 tools/data_gen/gen_misc.py && python3 tools/data_gen/gen_species.py && python3 tools/data_gen/gen_sets.py`

## 完了した項目
- [x] Phase 0: プロジェクト作成、フォルダ構成、テストランナー、管理ファイル
- [x] Phase 1: 戦闘コア
  - データスキーマ（species/moves/abilities/items/types/natures/weather/terrain/localization）+ GameData ローダ
  - 実数値計算、ダメージ計算（4096倍率チェーン・Showdown準拠丸め、Bulbapedia既知例と一致）
  - イベントフック機構（on/onSource/onAlly/onFoe/onAny 接頭辞、order/priority/speed 順）
  - ターン進行（優先度・素早さ・同速ランダム・動的速度、交代→技→残留処理、途中交代要求、ひんし交代）
  - 状態異常6種＋揮発性状態（こんらん/ひるみ/メロメロ/やどりぎ/みがわり/まもる系/アンコール/ちょうはつ/かなしばり/あくび/のろい/バインド/みちづれ/ほろびのうた 等）
  - 天候4種（延長アイテム）、フィールド4種（延長アイテム、接地判定）、壁3種、まきびし/ステロ/どくびし/ねばねばネット、トリックルーム、追い風、しんぴのまもり、しろいきり
  - 特性26（オリジナル5含む）、もちもの92、技465、種族19
  - AI: ランダムAI、評価関数AI（HeuristicAI）
  - テスト100件全通過（タイプ相性324、必須テスト一式、データ整合性、固定仕様チェック）
- [x] Phase 2: バランス調整（Round 1〜9、BALANCE_LOG.md）
  - [x] 推奨型 59（各種族3〜5型） data/sets/sets.json
  - [x] シミュレーター（1v1 / 3v3 / 6v6、並列実行、レポート生成、膠着検出）
  - [x] 6v6 12000戦で全19種 43.2〜57.7%（合格）。オリジナル特性の倍率変更なし
- [ ] Phase 3: 2D対戦UI（実装済み・調整中）
  - [x] タイトル / チームビルダー（種族・型・特性・もちもの・性格・技・努力値、検証、user://teams.json 保存）/ 対CPUバトル画面
  - [x] 戦闘画面: 敵情報・敵スプライト・自分スプライト・自分情報（HPバー）・天候/フィールド/壁表示・日本語ログ（LogFormatter）・コマンド（たたかう/モンスター/アイテム/にげる）
  - [x] 画像は assets/monsters/{id}_front.png / _back.png を外部参照、無ければタイプ色の仮画像を自動生成
  - [x] ヘッドレスUIスモーク（自動操作で6v6完走）、Xvfb スクリーンショット（reports/screenshots/）
  - [ ] 人間プレイの最終確認（ユーザー環境）

## バランス調整の経過
- Round 1（reports/balance_r1_3v3.md, balance_r1_1v1.md）: 3v3 合格帯外 13種、60ターン超 3.7%。1v1 全型固定の種族ペアは 6/171（合格）。
  → 上位7種の習得技を削減、ムニ系4種を440・マルタン530・ネオ420に引き上げ（BALANCE_LOG Round 1）。
- Round 2〜7（3v3）: 上位種の習得技削減→種族値再配分（BST下限500を維持し余剰を特攻/特殊側へ）→速度-5〜-10、下位種の種族値を上限（ムニ系440・ネオ420・その他540）まで引き上げ、型の入れ替え（膠着型の削除）。3v3 では上位5種が58〜60で境界に並ぶ構造的限界。
- Round 8（**6v6**、正式判定形式）: 19種中18種が 42.9〜57.4% で合格。なまずお 58.6% のみ超過 → 攻撃-5。
- Round 9（6v6 12000戦）: **合格**。全19種 43.2〜57.7%。続けて 1v1 各型100戦を実行中。

## 起動方法
- ゲーム本体: `godot --path .`（メインシーン scenes/main.tscn）
- スクリーンショット（表示なし環境）: `xvfb-run -a -s "-screen 0 960x540x24" godot --path . --rendering-driver opengl3 -s tools/screenshot.gd`

## 次の具体的タスク3つ
1. `reports/balance_r9_1v1.md` を確認し Phase 2 完了報告をまとめる
2. Phase 3 仕上げ: キーボード操作（矢印/決定/キャンセル）、メッセージ送りの調整、CPUチームの選択肢（ランダム／固定）
3. Phase 4（RPG層）設計: マップ・イベント・NPC のデータ形式（data/maps, data/events）と探索シーン

## 既知の不具合
- なし（テスト101件全通過）。Battle の参照循環によるメモリ増加は `Battle.dispose()` で解消済み（長時間シミュレーション用）。
