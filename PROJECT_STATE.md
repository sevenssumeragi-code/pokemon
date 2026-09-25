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

## バランス調整の経過
- Round 1（reports/balance_r1_3v3.md, balance_r1_1v1.md）: 3v3 合格帯外 13種、60ターン超 3.7%。1v1 全型固定の種族ペアは 6/171（合格）。
  → 上位7種の習得技を削減、ムニ系4種を440・マルタン530・ネオ420に引き上げ（BALANCE_LOG Round 1）。
- Round 2〜7（3v3）: 上位種の習得技削減→種族値再配分（BST下限500を維持し余剰を特攻/特殊側へ）→速度-5〜-10、下位種の種族値を上限（ムニ系440・ネオ420・その他540）まで引き上げ、型の入れ替え（膠着型の削除）。3v3 では上位5種が58〜60で境界に並ぶ構造的限界。
- Round 8（**6v6**、正式判定形式）: 19種中18種が 42.9〜57.4% で合格。なまずお 58.6% のみ超過 → 攻撃-5。
- Round 9: 確認用 6v6 12000戦 → 1v1 各型100戦 を実行中（tools/simulator/chain_r9.sh）。

## 次の具体的タスク3つ
1. `reports/balance_r9_6v6.md` で全19種が 42〜58% に収まることを確認（外れていれば再調整→再実行）
2. `reports/balance_r9_1v1.md` で全型固定の種族ペアが少ないことを確認し、Phase 2 完了報告（表）をまとめる
3. Phase 3（2D対戦UI）着手: タイトル → チームビルダー → 対CPUバトル画面（LogFormatter で日本語ログ）

## 既知の不具合
- なし（テスト101件全通過）。Battle の参照循環によるメモリ増加は `Battle.dispose()` で解消済み（長時間シミュレーション用）。
