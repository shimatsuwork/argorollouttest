# Argo Rollouts Abort コマンドの使用パターン

## 🚨 `kubectl argo rollouts abort` の使用場面

### **結論：両方の場合で使用可能、但し目的とタイミングが異なる**

---

## 📋 1. **手動Promote時のAbort**

### 1.1 使用場面
- **手動Promote待ち状態** で問題を発見した場合
- **Preview環境での検証中** に不具合を発見
- **Promote前** に新バージョンの問題を確認

### 1.2 実行タイミング
```bash
# 1. 新バージョンデプロイ
helm upgrade rollouts-demo ./chart --set image.tag=1.30

# 2. 状態確認：Paused (手動Promote待ち)
kubectl argo rollouts get rollout rollouts-demo
# Status: Paused, Message: BlueGreenPause

# 3. Preview環境で問題発見
kubectl port-forward svc/rollouts-demo-preview 8081:80
curl http://localhost:8081  # エラー発生！

# 4. Abort実行（Promote前に中止）
kubectl argo rollouts abort rollouts-demo
```

### 1.3 効果
- ✅ **Active環境**: 安全（旧バージョンのまま継続）
- ✅ **Preview環境**: 新バージョンは削除される
- ✅ **本番への影響**: なし（まだPromoteされていないため）

---

## 📋 2. **自動Promote時のAbort**

### 2.1 使用場面
- **自動切り替え後** に本番で問題を発見した場合
- **Analysis Template** が失敗を検出した場合
- **緊急停止** が必要な本番障害発生時

### 2.2 実行タイミング
```bash
# 1. 自動Promoteが有効な新バージョンデプロイ
helm upgrade rollouts-demo ./chart --set autoPromotionEnabled=true --set image.tag=1.30

# 2. 自動的にActive環境に切り替え済み
kubectl argo rollouts get rollout rollouts-demo
# nginx:1.30がActiveになっている

# 3. 本番で問題発生を検知
# - エラー率上昇
# - レスポンス時間悪化
# - 外部監視システムからアラート

# 4. 緊急Abort実行
kubectl argo rollouts abort rollouts-demo
```

### 2.3 効果
- ⚠️ **Active環境**: 既に新バージョンが稼働中
- ⚠️ **即座の復旧**: 追加でundoが必要
- ⚠️ **本番への影響**: 既に発生している可能性

---

## 🎯 3. **具体的な使用パターン比較**

### パターンA: 手動Promote時のAbort（推奨）
```bash
# シナリオ：Preview環境で問題発見
kubectl argo rollouts get rollout app
# Status: Paused (手動Promote待ち)

# Preview環境テスト
kubectl port-forward svc/app-preview 8081:80
# → 問題発見！

# 安全にAbort（本番への影響なし）
kubectl argo rollouts abort app

# 結果：旧バージョンで本番継続、問題なし
```

### パターンB: 自動Promote後のAbort（緊急時）
```bash
# シナリオ：自動切り替え後に本番で問題発生
kubectl argo rollouts get rollout app
# nginx:1.30が既にActiveで稼働中

# 本番で問題発生を検知
curl http://production-app.com/health
# → エラー！

# 緊急Abort + Undo
kubectl argo rollouts abort app
kubectl argo rollouts undo app

# 結果：本番復旧、但し一時的な影響は発生済み
```

---

## 🔧 4. **Analysis Template併用時のAbort**

### 4.1 Pre-Promotion Analysis（Promote前分析）
```yaml
rollout:
  strategy:
    blueGreen:
      autoPromotionEnabled: false
      prePromotionAnalysis:
        templates:
        - templateName: success-rate
```

**動作：**
- Analysis失敗 → 自動的にAbort
- 手動Abort → Analysis停止 + Rollout停止

### 4.2 Post-Promotion Analysis（Promote後分析）
```yaml
rollout:
  strategy:
    blueGreen:
      autoPromotionEnabled: true
      postPromotionAnalysis:
        templates:
        - templateName: success-rate
```

**動作：**
- Analysis失敗 → 自動的にAbort + Undo
- 手動Abort → 即座に停止（緊急時用）

---

## ⚙️ 5. **実用的なAbort戦略**

### 5.1 安全重視戦略（推奨）
```yaml
# 手動Promote + Pre-Analysis
autoPromotionEnabled: false
prePromotionAnalysis: 有効
```

**Abortの使用：**
- Preview環境での検証中に問題発見時
- 本番影響前の安全な停止

### 5.2 効率重視戦略
```yaml
# 自動Promote + Post-Analysis
autoPromotionEnabled: true
postPromotionAnalysis: 有効
```

**Abortの使用：**
- 本番で問題発生時の緊急停止
- Analysis Templateの自動Abort

### 5.3 ハイブリッド戦略
```yaml
# 段階的自動化
autoPromotionEnabled: false
prePromotionAnalysis: 有効
# 成功時のみ自動Promote
```

---

## 🚨 6. **Abort後の復旧手順**

### 6.1 手動Promote時のAbort後
```bash
# 1. Abort実行済み
kubectl argo rollouts abort app

# 2. 状態確認
kubectl argo rollouts get rollout app
# Status: Degraded (Aborted)

# 3. 修正版で再デプロイ
helm upgrade app ./chart --set image.tag=1.30-fixed

# 4. 正常なPromote実行
kubectl argo rollouts promote app
```

### 6.2 自動Promote後のAbort + Undo
```bash
# 1. 緊急Abort
kubectl argo rollouts abort app

# 2. 前バージョンに復旧
kubectl argo rollouts undo app

# 3. 復旧確認
kubectl argo rollouts get rollout app

# 4. 修正版で再デプロイ
helm upgrade app ./chart --set image.tag=1.30-fixed
```

---

## 📊 7. **まとめ：Abort使用判断フロー**

```
新バージョンデプロイ
         ↓
┌─────────────────────┬─────────────────────┐
│   手動Promote時     │    自動Promote時     │
├─────────────────────┼─────────────────────┤
│ Preview環境で待機    │ 即座にActive切替    │
│        ↓            │        ↓            │
│ Preview環境で検証    │ 本番環境で稼働      │
│        ↓            │        ↓            │
│ 問題発見？          │ 問題発生？          │
│   Yes ↓             │   Yes ↓             │
│ ✅ Abort実行        │ ⚠️ Abort + Undo    │
│ (安全、影響なし)     │ (緊急時、影響済み)   │
└─────────────────────┴─────────────────────┘
```

**推奨：手動Promote設定での安全なAbort運用**