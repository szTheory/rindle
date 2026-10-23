# Runs the existing generated host proof against the run-built unpacked archive.
Code.require_file("test/install_smoke/support/generated_app_helper.ex")
alias Rindle.InstallSmoke.GeneratedAppHelper

report = GeneratedAppHelper.prove_package_install!(:image)

unless report.install_mode == :package and report.package_root_provenance.unpacked? and
         not report.package_root_provenance.repository_path_fallback? and
         report.compile_exit_code == 0 and report.boot_exit_code == 0 and
         report.smoke_exit_code == 0 and report.lifecycle_proved? and
         report.host_migration_ran? and report.host_oban_migration_ran? and
         report.rindle_migration_ran? and report.migration_resolution == :host_migrations do
  raise "generated consumer did not establish the supported package boundary"
end

context = Map.put(report.package_evidence_context, :workspace_root, report.workspace_root)

File.write!(
  System.fetch_env!("RINDLE_READINESS_CONSUMER_CONTEXT"),
  Jason.encode!(context),
  [:exclusive]
)

File.write!(
  System.fetch_env!("RINDLE_READINESS_CONSUMER_RECEIPT"),
  Jason.encode!(report.package_evidence_receipt),
  [:exclusive]
)

IO.puts("generated consumer: compiled unpacked package, booted host, proved real lifecycle")
# The parent inventories and removes this exact run-owned temporary root after Doctor.
