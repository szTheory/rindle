import Config

config :twin, Twin.Repo,
  hostname: "postgres",
  username: "postgres",
  password: System.fetch_env!("TWIN_SECRET"),
  database: System.fetch_env!("TWIN_DATABASE"),
  pool_size: 10,
  log: false

config :rindle, Rindle.Storage.S3, bucket: System.fetch_env!("TWIN_BUCKET")

config :ex_aws, :s3,
  scheme: "http://",
  host: "minio",
  port: 9000,
  region: "us-east-1",
  access_key_id: "twinlocal",
  secret_access_key: System.fetch_env!("TWIN_SECRET")
