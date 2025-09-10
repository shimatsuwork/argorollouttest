# Argo Rollouts 新規リリースプロセス

## 🚀 新規リリースの基本フロー

### 1. **新規リリースの実行方法**

#### 1.1 Helmチャートによるリリース
```bash
# 新しいイメージタグでリリース
helm upgrade rollouts-demo ./helm-chart/rollouts-demo --set image.tag=1.29

# または専用スクリプト使用
./scripts/update-image.sh 1.29
```

#### 1.2 直接的なRolloutマニフェスト更新
```bash
# Rolloutリソースを直接更新
kubectl patch rollout rollouts-demo -p '{"spec":{"template":{"spec":{"containers":[{"name":"rollouts-demo","image":"nginx:1.29"}]}}}}'
```

### 2. **Blue/Green デプロイメント動作**

#### 2.1 現在の設定（手動Promote）
```yaml
# values.yaml
rollout:
  strategy:
    blueGreen:
      activeService: rollouts-demo-active
      previewService: rollouts-demo-preview
      autoPromotionEnabled: false  # 🔑 手動Promote必須
      scaleDownDelaySeconds: 30
```

**動作フロー：**
1. **新バージョンデプロイ** → Preview環境に新バージョン起動
2. **Pause状態** → 手動Promote待ち（自動切り替えなし）
3. **手動Promote** → Active環境に新バージョン切り替え
4. **Scale Down** → 30秒後に旧バージョン削除

#### 2.2 自動Promote設定の場合
```yaml
# 自動切り替え設定
rollout:
  strategy:
    blueGreen:
      autoPromotionEnabled: true  # 🔑 自動切り替え有効
      scaleDownDelaySeconds: 30
```

**動作フロー：**
1. **新バージョンデプロイ** → Preview環境に新バージョン起動
2. **自動切り替え** → Readiness Probe成功後、即座にActive環境に切り替え
3. **Scale Down** → 30秒後に旧バージョン削除

### 3. **リリース後のPromote動作**

#### 3.1 手動Promote（現在の設定）
```bash
# ✅ 正しい認識: 手動Promoteが必要
kubectl argo rollouts promote rollouts-demo

# Preview環境のテスト
kubectl port-forward svc/rollouts-demo-preview 8081:80
curl http://localhost:8081

# 確認後にPromote実行
kubectl argo rollouts promote rollouts-demo
```

#### 3.2 自動Promote設定の場合
```bash
# 設定変更で自動切り替え有効化
helm upgrade rollouts-demo ./helm-chart/rollouts-demo --set rollout.strategy.blueGreen.autoPromotionEnabled=true

# この場合、新バージョンは自動でActive環境に切り替わる
```

### 4. **Analysis Template併用の場合**

#### 4.1 Pre-Promotion Analysis（Promote前分析）
```yaml
rollout:
  strategy:
    blueGreen:
      autoPromotionEnabled: false
      prePromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: rollouts-demo-preview
```

**動作：**
1. Preview環境で新バージョン起動
2. **Analysis実行** → メトリクス分析（成功率等）
3. **Analysis成功** → 手動Promote待ち状態
4. **Analysis失敗** → 自動的にロールバック

#### 4.2 Post-Promotion Analysis（Promote後分析）
```yaml
rollout:
  strategy:
    blueGreen:
      autoPromotionEnabled: true  # 自動Promote
      postPromotionAnalysis:
        templates:
        - templateName: success-rate
```

**動作：**
1. 新バージョンが自動でActive環境に切り替え
2. **Analysis実行** → 本番環境でのメトリクス分析
3. **Analysis失敗** → 自動的にロールバック

### 5. **実用的なリリースパターン**

#### パターン1: 安全重視（手動検証）
```yaml
autoPromotionEnabled: false
prePromotionAnalysis: 有効
```
→ Preview環境で十分検証してからPromote

#### パターン2: 効率重視（自動化）
```yaml
autoPromotionEnabled: true
postPromotionAnalysis: 有効
```
→ 自動切り替え後、問題があれば自動ロールバック

#### パターン3: ハイブリッド（段階的自動化）
```yaml
autoPromotionEnabled: false
prePromotionAnalysis: 有効
# 成功時のみ自動Promote
```

### 6. **リリース手順の実例**

#### 手順1: 新バージョンリリース
```bash
# 新バージョンのデプロイ開始
./scripts/update-image.sh 1.29

# 状態確認
kubectl argo rollouts get rollout rollouts-demo --watch
```

#### 手順2: Preview環境での検証
```bash
# Preview環境への接続
kubectl port-forward svc/rollouts-demo-preview 8081:80

# 動作確認
curl http://localhost:8081
# またはブラウザでテスト
```

#### 手順3: 本番環境への切り替え
```bash
# 検証OK後にPromote実行
kubectl argo rollouts promote rollouts-demo

# 切り替え完了確認
kubectl argo rollouts get rollout rollouts-demo
```

#### 手順4: 問題発生時の対応
```bash
# 緊急ロールバック
kubectl argo rollouts abort rollouts-demo
kubectl argo rollouts undo rollouts-demo
```

### 7. **CI/CDパイプライン統合**

#### GitOps統合例
```yaml
# GitHub Actions例
- name: Deploy to Preview
  run: |
    helm upgrade rollouts-demo ./helm-chart/rollouts-demo --set image.tag=${{ github.sha }}
    
- name: Wait for Preview Ready
  run: |
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=rollouts-demo --timeout=300s
    
- name: Run Tests
  run: |
    # Preview環境でのテスト実行
    
- name: Promote to Production
  if: success()
  run: |
    kubectl argo rollouts promote rollouts-demo
```

## 🎯 まとめ

### ✅ **あなたの認識は正しいです：**

1. **新規リリース後、autoPromotionEnabled=falseの場合は手動Promoteが必要**
2. **自動では切り替わらない（Preview環境で待機状態）**
3. **手動でPromoteしない限り、本番トラフィックは旧バージョンのまま**

### 🔧 **推奨設定：**

- **開発・ステージング**: `autoPromotionEnabled: true` で高速リリース
- **本番環境**: `autoPromotionEnabled: false` で安全な手動検証
- **Analysis Template**: メトリクス監視による自動判定併用

この設定により、安全で確実なリリースプロセスを実現できます。