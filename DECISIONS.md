# DECISIONS（自分で決めた仕様とその理由）

## 2026-09-25
- **Godot 4.3 stable** を採用（4.x系で安定、ヘッドレスバイナリが取得できたため）。
- **テストフレームワーク自作**（`tests/test_case.gd` + `tests/test_runner.gd`）。GUT 等の外部アドオン依存を避け、`--headless -s` だけで完結させる。
- **`class_name` を使用**し、テスト実行前に `godot --headless --import` でクラスキャッシュを再生成する運用にする（ヘッドレスで class_name を解決するために必要と確認）。
- **内部IDは英数字 snake_case**（例: `renny`, `flame_domain`, `swords_dance`）。表示名は `data/localization/ja.json` のみ。
- **倍率の丸めは Pokémon Showdown 準拠の 4096 基準チェーン**（`modify(value, mod) = floor((value*mod + 2047) / 4096)`、半分以下切り捨て）を採用。本編第5世代以降の実測と一致することが知られているため。
- **効果ハンドラは Dictionary of Callable**（効果ID → {イベント名: Callable}）で実装。クラス爆発を避けつつフック追加を容易にする。
- **技の特殊効果はJSONの `effect`/`handlers` フィールドで汎用ハンドラIDを参照**する（コードに技名を書かない）。
