# PROJECT_STATE

## 現在フェーズ
Phase 2（ロースター実装とバランス調整）— 初回シミュレーション実行中

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
- [ ] Phase 2: バランス調整（進行中）
  - [x] 推奨型 57（各種族2〜3型） data/sets/sets.json
  - [x] シミュレーター（1v1 / 3v3 / 6v6、並列実行、レポート生成）
  - [ ] 初回レポート → 合格基準判定 → 調整ループ

## 次の具体的タスク3つ
1. `reports/balance_r1_3v3.md` と `reports/balance_r1_1v1.md` を読み、合格基準（勝率42〜58%、固定相性、平均ターン）を判定する
2. 外れた種族について原因を特定し、優先順位（習得技 → 種族値 → もちもの/技効果 → 特性倍率）に従って調整、BALANCE_LOG.md に記録
3. 再シミュレーション → 差分表 → 合格まで繰り返す（重点検証リスト10項目もレポートから確認）

## 既知の不具合
- なし（テスト全通過）。ログ表示名の日本語化（UI層）は Phase 3 で実装。
