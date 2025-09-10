# Argo Rollouts 切り戻し（ロールバック）パターン

## 🔄 切り戻し条件の選択パターン

Argo Rolloutsでは以下の切り戻し条件・パターンを選択できます：

### 1. **前のリビジョンへの自動切り戻し**
```bash
# 直前のリビジョンに戻る（最も一般的）
kubectl argo rollouts undo rollouts-demo
```

### 2. **特定のリビジョンへの指定切り戻し**
```bash
# 特定のリビジョン番号を指定して切り戻し
kubectl argo rollouts undo rollouts-demo --to-revision=3

# 例：nginx:1.25（リビジョン1）に戻したい場合
kubectl argo rollouts undo rollouts-demo --to-revision=1
```

### 3. **手動トリガーによる切り戻し**
- **手動コマンド実行**: 運用者が明示的に実行
- **ダッシュボードUI**: Web UIから手動で実行
- **CI/CDパイプライン**: 自動化スクリプトから実行

### 4. **Analysis-based 自動切り戻し**

#### 4.1 Analysis Template での自動切り戻し
```yaml
# メトリクス分析に基づく自動切り戻し
spec:
  strategy:
    blueGreen:
      prePromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: rollouts-demo-preview
      # 失敗時の自動切り戻し設定
      abortScaleDownDelaySeconds: 60
```

#### 4.2 成功率ベースの切り戻し
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  metrics:
  - name: success-rate
    # 成功率95%以下で失敗と判定
    successCondition: result[0] >= 0.95
    # 連続3回失敗で切り戻し
    failureLimit: 3
    provider:
      prometheus:
        query: |
          sum(rate(http_requests_total{status!~"5.."}[5m])) / 
          sum(rate(http_requests_total[5m]))
```

#### 4.3 レスポンス時間ベースの切り戻し
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: response-time
spec:
  metrics:
  - name: avg-response-time
    # 平均レスポンス時間500ms以下で成功
    successCondition: result[0] < 500
    failureLimit: 2
    provider:
      prometheus:
        query: |
          histogram_quantile(0.95, 
            sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
          ) * 1000
```

### 5. **時間ベースの自動切り戻し**

#### 5.1 タイムアウトベース
```yaml
spec:
  strategy:
    blueGreen:
      # 30分経過後、手動Promoteがない場合は自動切り戻し
      scaleDownDelaySeconds: 1800
      autoPromotionEnabled: false
```

#### 5.2 定期実行での切り戻し
```yaml
# CronJobで定期的にヘルスチェック
apiVersion: batch/v1
kind: CronJob
metadata:
  name: rollout-health-check
spec:
  schedule: "*/5 * * * *"  # 5分毎
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: health-check
            image: curlimages/curl
            command:
            - /bin/sh
            - -c
            - |
              if ! curl -f http://rollouts-demo-active/health; then
                kubectl argo rollouts abort rollouts-demo
              fi
```

### 6. **条件ベースの切り戻しトリガー**

#### 6.1 エラー率しきい値
```yaml
# エラー率5%超過で切り戻し
successCondition: result[0] <= 0.05
query: |
  sum(rate(http_requests_total{status=~"5.."}[5m])) / 
  sum(rate(http_requests_total[5m]))
```

#### 6.2 CPU/メモリ使用率
```yaml
# CPU使用率80%超過で切り戻し
successCondition: result[0] <= 80
query: |
  avg(rate(container_cpu_usage_seconds_total{pod=~"rollouts-demo-.*"}[5m])) * 100
```

#### 6.3 外部システム依存
```yaml
# 外部APIの応答ベース
successCondition: result[0] == 1
query: |
  up{job="external-api"}
```

### 7. **段階的切り戻し戦略**

#### 7.1 カナリアロールバック
```yaml
spec:
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 5m}
      - analysis:
          templates:
          - templateName: success-rate
      # 失敗時は段階的に重みを戻す
```

#### 7.2 Blue/Green段階切り戻し
```yaml
spec:
  strategy:
    blueGreen:
      prePromotionAnalysis:
        templates:
        - templateName: multi-metric-analysis
      # 複数メトリクスでの段階的評価
```

## 🎯 実用的な切り戻しパターン例

### パターン1: 即座の手動切り戻し
```bash
# 問題発見時の緊急切り戻し
kubectl argo rollouts abort rollouts-demo
kubectl argo rollouts undo rollouts-demo
```

### パターン2: 特定バージョンへの切り戻し
```bash
# 安定していた特定バージョンに戻す
kubectl argo rollouts undo rollouts-demo --to-revision=2
```

### パターン3: 段階的検証切り戻し
```bash
# 1. 新バージョンを一時停止
kubectl argo rollouts abort rollouts-demo

# 2. 検証後、前バージョンに切り戻し
kubectl argo rollouts undo rollouts-demo

# 3. 新バージョンでの段階的再展開
./scripts/update-image.sh 1.28
kubectl argo rollouts promote rollouts-demo --full
```

## ⚠️ 切り戻し時の注意点

1. **データベースマイグレーション**: スキーマ変更がある場合の考慮
2. **セッション継続性**: ユーザーセッションへの影響
3. **外部システム依存**: 連携システムとの整合性
4. **ログ・監視**: 切り戻し実行の記録と追跡
5. **通知システム**: 関係者への切り戻し通知

## 📊 切り戻し判定メトリクス例

- **成功率**: HTTP 2xx/3xx レスポンス率
- **エラー率**: HTTP 4xx/5xx レスポンス率  
- **レスポンス時間**: P95, P99レスポンス時間
- **CPU/メモリ使用率**: リソース消費量
- **外部依存**: 外部API/DB可用性
- **ビジネスメトリクス**: 変換率、売上等

各環境・アプリケーションの特性に応じて、適切な切り戻し条件とパターンを選択することが重要です。