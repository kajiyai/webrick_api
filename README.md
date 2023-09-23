# Simple RESTful API with WEBrick and PostgreSQL

## 概要

このプロジェクトは、Rubyで作成されたシンプルなRESTful APIです。WEBrick WebサーバとPostgreSQLデータベースを用いています。ユーザーのアカウント作成、認証、および情報の取得・更新が可能です。

## 機能

- 新規ユーザー登録 (`/signup` エンドポイント)
- アカウント削除 (`/close` エンドポイント)
- ユーザー情報の取得・更新 (`/users` エンドポイント)

## セットアップ

1. `.env` ファイルにデータベースの設定を記述します。
    ```
    DB_NAME=your_database_name
    USER_NAME=your_username
    PASSWORD=your_password
    HOST=your_host
    ```

2. パッケージのインストール
    ```bash
    bundle install
    ```

3. サーバーの起動
    ```bash
    ruby your_script_name.rb
    ```

## 技術スタック

- Ruby
- WEBrick
- PostgreSQL
- bcrypt（パスワードハッシュ化）
- Base64（HTTP Basic認証）

## コードの特徴

- パスワードはbcryptを用いてハッシュ化しています。
- 環境変数を用いて機密情報を管理しています。

## プロジェクトで学んだこと

Ruby on RailsやSinatraなどのフレームワークは非常に便利で、多くの機能が短時間で実装できます。しかし、その便利さゆえに、フレームワークが内部でどのような処理を行っているのか理解しきれない場合があります。このプロジェクトでは、そのような「黒魔術」に頼らず、RubyとWEBrick、そしてPostgreSQLを用いて低レベルな実装を行いました。

- HTTPプロトコルについて: WEBrickを用いてHTTPリクエストとレスポンスを直接扱うことで、HTTPプロトコルについて深く理解することができました。
- 認証とセキュリティ: HTTP Basic認証とパスワードのハッシュ化を手動で行いました。これによって、セキュリティの基礎について実感で学ぶことができました。
- エラーハンドリング: 低レベルな状態でのエラーハンドリングを経験し、エラーメッセージやステータスコードがどのようにクライアントに返されるべきかを理解しました。
