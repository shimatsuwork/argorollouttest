# Argo Rollouts Blue/Green Deployment Demo

このプロジェクトは、Argo RolloutsのBlue/Greenデプロイメント戦略とロールバック機能を実際に体験できるデモ環境です。

## 📋 前提条件

- Kubernetes クラスター (kind, minikube, GKE, EKS, AKS等)
- kubectl コマンドラインツール
- Helm 3.x
- curl (スクリプトのダウンロード用)

## 🚀 クイックスタート

### 1. Argo Rolloutsのインストール

```bash
# Argo Rolloutsコントローラーとkubectlプラグインをインストール
./scripts/install-argo-rollouts.sh
```

### 2. ダッシュボードのセットアップ

```bash
# Argo RolloutsダッシュボードをWebUIでアクセスできるように設定
./scripts/setup-dashboard.sh
```

ダッシュボードへのアクセス方法:
- **Local cluster (kind/minikube)**: http://localhost:31000
- **Remote cluster**: http://\<cluster-ip\>:31000  
- **Port-forward**: `kubectl port-forward -n argo-rollouts service/argo-rollouts-dashboard 3100:3100`

### 3. デモアプリケーションのデプロイ

```bash
# Helmチャートを使用してRolloutをデプロイ
./scripts/deploy.sh
```

### 4. Blue/Greenデプロイメントのテスト

```bash
# 新しいイメージバージョンにアップデート (例: nginx:1.26)
./scripts/update-image.sh 1.26
```

### 5. ロールバックのテスト

```bash
# 前のリビジョンにロールバック
./scripts/test-rollback.sh
```

## 📁 プロジェクト構成

```
argorollouttest/
├── helm-chart/
│   └── rollouts-demo/          # Helmチャート
│       ├── Chart.yaml          # チャート設定
│       ├── values.yaml         # デフォルト値
│       └── templates/          # Kubernetesマニフェストテンプレート
│           ├── rollout.yaml    # Rolloutリソース定義
│           ├── services.yaml   # Active/Previewサービス
│           ├── analysistemplate.yaml  # メトリクス分析
│           └── _helpers.tpl    # Helmヘルパーテンプレート
├── scripts/                    # 自動化スクリプト
│   ├── install-argo-rollouts.sh  # セットアップスクリプト
│   ├── setup-dashboard.sh      # ダッシュボード設定
│   ├── deploy.sh              # アプリケーションデプロイ
│   ├── update-image.sh        # イメージ更新
│   ├── test-rollback.sh       # ロールバックテスト
│   └── cleanup.sh             # クリーンアップ
└── README.md                  # このファイル
```

## 🎯 Blue/Greenデプロイメント戦略

このデモでは以下のBlue/Green戦略を使用しています:

- **Active Service**: `rollouts-demo-active` (本番環境トラフィック)
- **Preview Service**: `rollouts-demo-preview` (新バージョンのテスト用)
- **Auto Promotion**: 無効 (手動承認が必要)
- **Scale Down Delay**: 30秒 (古いバージョンの削除までの待機時間)

### デプロイメントフロー

1. 新しいバージョンがPreview環境にデプロイ
2. Analysis Template実行 (成功率チェック)
3. 手動でPromote実行
4. トラフィックがActiveサービスに切り替え
5. 30秒後に古いバージョンを削除

## 🔧 手動操作コマンド

### Rollout状態の確認
```bash
kubectl argo rollouts get rollout rollouts-demo
kubectl argo rollouts get rollout rollouts-demo --watch  # リアルタイム監視
```

### Rollout操作
```bash
# 手動でPromote (承認)
kubectl argo rollouts promote rollouts-demo

# Rolloutの中止
kubectl argo rollouts abort rollouts-demo

# リトライ実行
kubectl argo rollouts retry rollout rollouts-demo

# ロールバック実行
kubectl argo rollouts undo rollouts-demo

# 履歴表示
kubectl argo rollouts history rollout rollouts-demo
```

### サービステスト
```bash
# Activeサービスへの接続
kubectl port-forward svc/rollouts-demo-active 8080:80

# Previewサービスへの接続 (デプロイ中のみ)
kubectl port-forward svc/rollouts-demo-preview 8081:80
```

## 📊 ダッシュボードでの監視

Argo Rolloutsダッシュボードでは以下を確認できます:

- Rolloutの現在の状態とプログレス
- Blue/Greenデプロイメントのビジュアル表示
- レプリカセットの状態
- サービスとエンドポイントの状況
- 履歴とロールバック操作

## 🧪 テストシナリオ

### シナリオ 1: 成功デプロイメント
1. `./scripts/update-image.sh 1.26`でnginx:1.26に更新
2. ダッシュボードでPreview環境の確認
3. `kubectl argo rollouts promote rollouts-demo`で手動承認
4. Active環境の切り替え確認

### シナリオ 2: デプロイメント中止
1. 新バージョンをデプロイ開始
2. `kubectl argo rollouts abort rollouts-demo`で中止
3. 元の状態への復帰確認

### シナリオ 3: ロールバック
1. 複数回のバージョン更新実行
2. `./scripts/test-rollback.sh`でロールバック
3. 前バージョンへの復帰確認

## 🎨 カスタマイゼーション

### values.yamlの主要設定

```yaml
# レプリカ数の変更
replicaCount: 5

# イメージの変更
image:
  repository: httpd
  tag: "2.4"

# Blue/Green戦略の調整
rollout:
  strategy:
    blueGreen:
      autoPromotionEnabled: true  # 自動承認を有効化
      scaleDownDelaySeconds: 60   # 削除待機時間を60秒に変更
```

### Analysis Templateの追加

カスタムメトリクスを追加してより高度な分析を実装可能:

```yaml
# helm-chart/rollouts-demo/templates/analysistemplate.yaml
# Prometheusメトリクスを使用したカスタム分析テンプレート
```

## 🧹 クリーンアップ

```bash
# デモアプリケーションのみ削除
./scripts/cleanup.sh

# Argo Rollouts完全削除 (オプション)
kubectl delete namespace argo-rollouts
```

## 🔍 トラブルシューティング

### よくある問題

1. **Rolloutが進行しない**
   - `kubectl describe rollout rollouts-demo`で詳細確認
   - Analysis Templateのエラーをチェック

2. **ダッシュボードにアクセスできない**
   - ポート転送: `kubectl port-forward -n argo-rollouts service/argo-rollouts-dashboard 3100:3100`
   - サービス状態確認: `kubectl get svc -n argo-rollouts`

3. **kubectl pluginが動作しない**
   - プラグインの再インストール: `./scripts/install-argo-rollouts.sh`
   - パス確認: `which kubectl-argo-rollouts`

### ログ確認

```bash
# Argo Rolloutsコントローラーログ
kubectl logs -n argo-rollouts -l app.kubernetes.io/name=argo-rollouts

# Rollout状態の詳細
kubectl describe rollout rollouts-demo

# イベント確認
kubectl get events --sort-by='.lastTimestamp'
```

## 📚 参考リンク

- [Argo Rollouts公式ドキュメント](https://argoproj.github.io/argo-rollouts/)
- [Blue-Green Deployment Strategy](https://argoproj.github.io/argo-rollouts/features/bluegreen/)
- [kubectl plugin](https://argoproj.github.io/argo-rollouts/features/kubectl-plugin/)

---

このデモ環境を使用して、Argo RolloutsのBlue/Greenデプロイメントとロールバック機能を実際に体験してください！