defmodule Rindle.Contracts.BehaviourContractTest do
  use ExUnit.Case, async: true

  import Mox

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "storage callback contract returns tagged tuple payloads" do
    key = "assets/a1/original.jpg"
    source_path = "/tmp/original.jpg"
    opts = [content_type: "image/jpeg"]

    expect(Rindle.StorageMock, :store, fn ^key, ^source_path, ^opts ->
      {:ok, %{key: key, state: :stored}}
    end)

    expect(Rindle.StorageMock, :capabilities, fn ->
      [:local, :presigned_put]
    end)

    assert {:ok, %{key: ^key, state: :stored}} =
             Rindle.StorageMock.store(key, source_path, opts)

    assert [:local, :presigned_put] = Rindle.StorageMock.capabilities()
  end

  test "processor callback contract returns destination path in ok tuple" do
    source_path = "/tmp/original.jpg"
    destination_path = "/tmp/variants/thumb.jpg"
    variant_spec = %{name: :thumb, width: 300, height: 300, mode: :fit}

    expect(Rindle.ProcessorMock, :process, fn ^source_path, ^variant_spec, ^destination_path ->
      {:ok, destination_path}
    end)

    assert {:ok, ^destination_path} =
             Rindle.ProcessorMock.process(source_path, variant_spec, destination_path)
  end

  test "analyzer callback contract returns metadata map payload" do
    source_path = "/tmp/original.jpg"
    metadata = %{width: 1600, height: 900, mime: "image/jpeg"}

    expect(Rindle.AnalyzerMock, :analyze, fn ^source_path ->
      {:ok, metadata}
    end)

    assert {:ok, ^metadata} = Rindle.AnalyzerMock.analyze(source_path)
  end

  test "scanner callback contract supports quarantine and ok outcomes" do
    quarantined_path = "/tmp/suspicious.svg"
    clean_path = "/tmp/clean.jpg"

    expect(Rindle.ScannerMock, :scan, fn ^quarantined_path ->
      {:quarantine, :mime_mismatch}
    end)

    expect(Rindle.ScannerMock, :scan, fn ^clean_path ->
      :ok
    end)

    assert {:quarantine, :mime_mismatch} = Rindle.ScannerMock.scan(quarantined_path)
    assert :ok = Rindle.ScannerMock.scan(clean_path)
  end

  test "authorizer callback contract supports allow and deny responses" do
    actor = %{id: "user-1", role: :member}
    action = :read
    subject = %{asset_id: "asset-1"}

    expect(Rindle.AuthorizerMock, :authorize, fn ^actor, ^action, ^subject ->
      :ok
    end)

    unauthorized_actor = %{id: "user-2", role: :guest}

    expect(Rindle.AuthorizerMock, :authorize, fn ^unauthorized_actor, ^action, ^subject ->
      {:error, :unauthorized}
    end)

    assert :ok = Rindle.AuthorizerMock.authorize(actor, action, subject)

    assert {:error, :unauthorized} =
             Rindle.AuthorizerMock.authorize(unauthorized_actor, action, subject)
  end
end
