# PROJECT_STATE

## 現在フェーズ
Phase 0 完了 → Phase 1（戦闘コア）着手

## 環境
- Godot 4.3 stable（`/usr/local/bin/godot`、ヘッドレス動作確認済み）
- テスト実行: `./run_tests.sh [filter]`（`--import` でクラスキャッシュ再生成 → `tests/test_runner.gd`）
- 新しい `class_name` を追加した後は `./run_tests.sh` 経由（内部で `--import`）で実行すること

## 完了した項目
- [x] Phase 0: プロジェクト作成、フォルダ構成、テストランナー、管理ファイル

## 次の具体的タスク3つ
1. データスキーマ（species/moves/abilities/items/types/natures/localization）と DataLoader
2. StatCalc + DamageCalc（本編式・4096倍率チェーン）＋ 既知計算例との照合テスト
3. Battle ターン進行（行動選択→優先度→素早さ→実行→残留処理）とイベントフック機構

## 既知の不具合
- なし
