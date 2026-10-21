"""Fast synthetic contract fixture; never real runtime acceptance."""
import copy
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "scripts/maintainer"))
from twin_receipt import HASHES, DOMAIN, KIND, SCENARIO


def fixture():
    inputs = {k: "a" * 64 for k in HASHES}
    inputs.update(schema_version=1, kind=KIND, independent_pilot_credit=False, scenario=SCENARIO,
                  run_id="a" * 32, source_sha="a" * 40,
                  toolchain={"elixir": "1.17.3", "otp": "27.3.4.15", "oban": "2.21.1", "phoenix": "1.8.12"})
    asset, old, new, key = ["00000000-0000-4000-8000-00000000000" + str(i) for i in range(1, 5)]
    before = dict(asset_id=asset, source_key="elixir-twin-profile/" + asset + "/" + key + ".png",
                  job_id=3, attempt=1, state="retryable", outcome="paused", error_count=1,
                  asset_retained=True, source_present=True, ready_variant_count=1,
                  variant_deletes_before_failure=1, paused=True, running=0,
                  stimuli=dict(upload=1, attach=1, detach=1), boot_id=old, sequence=1)
    after = dict(outcome="completed", job_id=3, attempt=2, state="completed", asset_absent=True,
                 error_count=1, boot_id=new, fault_claims=1, sequence=2)
    health = dict(inputs["toolchain"], origin="/twin/_build/prod/lib/rindle/ebin/Elixir.Rindle.beam", lock_sha256=inputs["lock_sha256"])
    inventory = dict(domain={k: int(k == "rindle_migration_versions") for k in DOMAIN},
                     jobs=[dict(id=i, queue=q, state="completed", attempt=2 if i == 3 else 1)
                           for i, q in enumerate(["rindle_promote", "rindle_process", "rindle_purge"], 1)],
                     temp_files=0, fault_claims=1, writers_paused=True, objects=0, multipart=0,
                     versioning_disabled=True, processes=0, complete=True, sequence=3)
    inventory.update(relations={"public": ["oban_jobs", "oban_peers", "schema_migrations", "twin_fault_counters"], "rindle": sorted(DOMAIN)},
                     fixture_rows=2, schema_migration_rows=1, peer_rows=1, listing_complete=True)
    receipt = dict(schema_version=1, kind=KIND, independent_pilot_credit=False, inputs=copy.deepcopy(inputs),
                   outcome="complete", reason="complete", stage="complete", dependency="none",
                   before=before, after=after, old_runtime=dict(health, boot_id=old), new_runtime=dict(health, boot_id=new),
                   old_container="b" * 64, new_container="c" * 64, old_exited=True, new_exited=True,
                   isolation=dict(image_id="sha256:" + "d" * 64, mounts_verified=True),
                   capabilities=dict(ffmpeg_major=7, ffprobe_major=7, database_schema=True, image_exercised=True,
                                     storage_exercised=True, av_exercised=False, doctor_status="not_used_known_migration_ledger_issue"),
                   inventory=inventory)
    return inputs, receipt
