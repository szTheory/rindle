defmodule Rindle.TwinReceiptTest do
  use ExUnit.Case, async: true
  @root Path.expand("../..", __DIR__)
  defp python(code) do
    System.cmd(
      "python3",
      [
        "-B",
        "-c",
        "import sys\nsys.path.insert(0,'test/install_smoke/support')\nsys.path.insert(0,'scripts/maintainer')\n" <>
          code
      ],
      cd: @root,
      stderr_to_stdout: true
    )
  end

  test "strict identities, types, empty inventories and forged verdicts fail" do
    code = """
    from twin_fixture import fixture
    from twin_receipt import verify_receipt, Refused, MAX_ID
    import copy
    inputs, receipt = fixture(); assert verify_receipt(inputs, receipt)
    mutations = [(['inputs','run_id'],'b'*32), (['inputs','lock_sha256'],'b'*64),
      (['inputs','fixture_sha256'],'b'*64), (['inputs','contract_sha256'],'b'*64),
      (['inputs','package_tar_sha256'],'b'*64), (['inputs','host_sha256'],'b'*64),
      (['independent_pilot_credit'],True), (['kind'],None), (['outcome'],'failed'),
      (['before','attempt'],2), (['before','attempt'],True), (['after','attempt'],2.0),
      (['before','stimuli','detach'],2), (['before','error_count'],0), (['after','job_id'],4),
      (['old_exited'],False), (['new_runtime','boot_id'],receipt['old_runtime']['boot_id']),
      (['inventory','objects'],1), (['inventory','complete'],False), (['inventory','domain'],{}),
      (['inventory','jobs'],[]), (['inventory','sequence'],2), (['before','sequence'],2),
      (['after','job_id'],MAX_ID+1), (['inputs','package_tar_sha256'],'a'*65),
      (['capabilities','av_exercised'],True)]
    for path,value in mutations:
        r=copy.deepcopy(receipt);target=r
        for key in path[:-1]: target=target[key]
        target[path[-1]]=value
        try:verify_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError(path)
    for key in receipt:
        r=copy.deepcopy(receipt);del r[key]
        try:verify_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError('missing '+key)
    r=copy.deepcopy(receipt);r['foreign']='secret'
    try:verify_receipt(inputs,r)
    except Refused:pass
    else:raise AssertionError('unknown key')
    r=copy.deepcopy(receipt)
    for location in [r['before'],r['after']]: location['job_id']=MAX_ID
    r['inventory']['jobs'][2]['id']=MAX_ID
    assert verify_receipt(inputs,r)
    """

    assert {_, 0} = python(code)
  end

  test "decoder rejects duplicates nonfinite values and one byte above its exact bound" do
    code = """
    from twin_receipt import decode, Refused, MAX_BYTES
    for raw in ['{"x":1,"x":2}', '{"x":{"a":1,"a":2}}','{"x":NaN}','{"x":Infinity}']:
        try:decode(raw)
        except Refused:pass
        else:raise AssertionError(raw)
    assert decode('{}'+' '*(MAX_BYTES-2))=={}
    try:decode('{}'+' '*(MAX_BYTES-1))
    except Refused:pass
    else:raise AssertionError('oversized')
    """

    assert {_, 0} = python(code)
  end

  @tag :tmp_dir
  test "signed URL body credential access-log and telemetry canaries stay private", %{
    tmp_dir: dir
  } do
    code = """
    from twin_receipt import safe_diagnostic, verify_receipt, Refused
    from twin_fixture import fixture
    from built_package_twin import Runner
    import contextlib,io,json,tempfile
    canaries=['https://storage.invalid/x?X-Amz-Signature=SIGNED_CANARY','SECRET_CANARY','BODY_CANARY','JOB_ERROR_CANARY']
    for channel in ['receipt','console','stderr','access_log','telemetry']:
        raw=dict(stage='services',reason='complete',dependency='none',channel=channel,body=canaries,access_log=canaries,telemetry=canaries)
        exported=json.dumps(safe_diagnostic(raw))
        assert all(c not in exported for c in canaries)
    capture=io.StringIO()
    with tempfile.TemporaryDirectory() as d, contextlib.redirect_stdout(capture), contextlib.redirect_stderr(capture):
        runner=Runner(d)
        import os
        os.environ['TWIN_PROJECT']='FOREIGN_PROJECT_CANARY'
        assert runner.command([sys.executable,'-c',"import os;print(os.environ.get('TWIN_PROJECT'))"]).strip()=='None'
        runner.command([sys.executable,'-c','print('+repr('|'.join(canaries))+')'])
        runner.progress('services')
    assert all(c not in capture.getvalue() for c in canaries)
    inputs,r=fixture();r['raw_job_error']=canaries
    try:verify_receipt(inputs,r)
    except Refused as e: assert all(c not in str(e) for c in canaries)
    else:raise AssertionError('secret-bearing record accepted')
    """

    assert {_, 0} = python(code)
    assert File.dir?(dir)
  end

  test "typed tus evidence requires a new client, exact original and derivative and bound inputs" do
    code = """
    import copy
    from twin_fixture import fixture
    from twin_receipt import verify_receipt, verify_case_receipt, Refused, TUS_SHA256, THUMB_KEY
    inputs, old = fixture()
    inputs.update(schema_version=2, scenario='tus-resume', fixture_sha256=TUS_SHA256)
    asset = old['before']['asset_id']
    source = 'elixir-twin-profile/'+asset+'/00000000-0000-4000-8000-000000000004'
    variant = 'Elixir.Twin.Profile/'+asset+'/'+THUMB_KEY
    first = dict(pid=100, create_status=201, patch_status=204, offset=32)
    second = dict(pid=200, head_status=204, head_offset=32, head_cache='no-store', wrong_status=409,
                  after_wrong_status=204, after_wrong_offset=32, patch_status=204, final_offset=69)
    result = dict(outcome='ready', session_id='00000000-0000-4000-8000-000000000005',
                  asset_id=asset, session_state='completed', asset_state='ready', source_key=source,
                  variant_keys=[variant], checksum_sha256=TUS_SHA256, sessions=1, assets=1,
                  upload_stimuli=1, offset=69, boot_id=old['old_runtime']['boot_id'])
    receipt = dict(schema_version=2, kind=old['kind'], independent_pilot_credit=False, inputs=copy.deepcopy(inputs),
                   case_id='tus-resume', outcome='complete', reason='complete', stage='complete', dependency='none',
                   clients=dict(first=first, second=second, first_exited=True, second_exited=True),
                   result=result, object_keys=sorted([source,variant]), runtime=old['old_runtime'],
                   isolation=old['isolation'],host_exited=True)
    assert verify_receipt(inputs,receipt)
    mutations=[(['inputs','run_id'],'b'*32),(['inputs','package_tar_sha256'],'b'*64),
      (['case_id'],'unknown'),(['schema_version'],1),(['clients','first_exited'],False),
      (['clients','second','pid'],100),(['clients','second','head_offset'],31),
      (['clients','second','head_status'],200),(['clients','second','wrong_status'],204),
      (['clients','second','after_wrong_offset'],33),(['clients','first','offset'],True),
      (['result','sessions'],2),(['result','assets'],2),(['result','upload_stimuli'],2),
      (['result','checksum_sha256'],'b'*64),(['result','asset_state'],'available'),
      (['result','offset'],68),(['result','source_key'],source+'extra'),
      (['result','variant_keys'],[]),(['object_keys'],[source]),(['object_keys'],[source,variant,'extra']),
      (['host_exited'],False),(['runtime','origin'],'checkout'),(['outcome'],'incomplete')]
    for path,value in mutations:
        r=copy.deepcopy(receipt); target=r
        for key in path[:-1]: target=target[key]
        target[path[-1]]=value
        try:verify_case_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError(path)
    for key in receipt:
        r=copy.deepcopy(receipt);del r[key]
        try:verify_case_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError('missing '+key)
    for field in ['raw_body','signature','job_error','pubsub','signed_url']:
        r=copy.deepcopy(receipt);r[field]='SECRET_CANARY'
        try:verify_receipt(inputs,r)
        except Refused as e: assert 'SECRET_CANARY' not in str(e)
        else:raise AssertionError(field)
    legacy_inputs, legacy = fixture()
    assert verify_receipt(legacy_inputs,legacy)
    try:verify_case_receipt(legacy_inputs,legacy)
    except Refused:pass
    else:raise AssertionError('legacy counted as matrix case')
    """

    assert {_, 0} = python(code)
  end

  test "purge case rejects denial, substituted job identity, repeated stimulus and residue" do
    code = """
    import copy
    from twin_fixture import fixture
    from twin_receipt import verify_receipt, Refused
    inputs,legacy=fixture(); inputs.update(schema_version=2,scenario='purge-absence')
    before,after,inventory = [copy.deepcopy(legacy[k]) for k in ['before','after','inventory']]
    after.update(boot_id=before['boot_id'], sequence=3); inventory['sequence']=4
    absence=dict(source_key=before['source_key'], asset_id=before['asset_id'], job_id=before['job_id'],
                 head='not_found', asset_retained=True, paused=True, running=0, state='retryable',
                 attempt=1,error_count=1,sequence=2)
    receipt=dict(schema_version=2,kind=legacy['kind'],independent_pilot_credit=False,inputs=copy.deepcopy(inputs),
                 case_id='purge-absence',outcome='complete',reason='complete',stage='complete',dependency='none',
                 before=before,absence=absence,after=after,inventory=inventory,runtime=legacy['old_runtime'],
                 isolation=legacy['isolation'],host_exited=True)
    assert verify_receipt(inputs,receipt)
    mutations=[(['before','error_count'],0),(['after','job_id'],9),(['after','attempt'],1),
      (['absence','head'],'denied'),(['absence','head'],'unknown'),(['absence','source_key'],'foreign'),
      (['absence','asset_id'],'00000000-0000-4000-8000-000000000009'),(['absence','job_id'],9),
      (['absence','paused'],False),(['absence','running'],1),(['absence','attempt'],2),
      (['absence','error_count'],0),(['absence','sequence'],1),(['before','stimuli','detach'],2),
      (['inventory','objects'],1),(['inventory','domain','media_assets'],1),(['inventory','listing_complete'],False),
      (['inventory','writers_paused'],False),(['inventory','jobs',2,'id'],9),(['inventory','temp_files'],1),
      (['inventory','multipart'],1),(['after','asset_absent'],False)]
    for path,value in mutations:
        r=copy.deepcopy(receipt);target=r
        for key in path[:-1]:target=target[key]
        target[path[-1]]=value
        try:verify_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError(path)
    for key in ['absence','before','after','inventory']:
        r=copy.deepcopy(receipt);del r[key]
        try:verify_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError(key)
    """

    assert {_, 0} = python(code)
  end

  test "AV repair requires five failures, a new committed repair and a fully decoded declared derivative" do
    code = """
    import copy
    from twin_fixture import fixture
    from twin_receipt import verify_receipt, Refused, AV_SHA256, AV_RECIPE
    inputs,old=fixture(); inputs.update(schema_version=2,scenario='av-repair',fixture_sha256=AV_SHA256)
    asset=old['before']['asset_id'];variant='00000000-0000-4000-8000-000000000005'
    source='elixir-twin-avprofile/'+asset+'/00000000-0000-4000-8000-000000000004.mp4'
    key='Elixir.Twin.AVProfile/'+asset+'/web_720p-'+AV_RECIPE+'.mp4'
    before=dict(asset_id=asset,session_id='00000000-0000-4000-8000-000000000006',source_key=source,
                job_id=2,variant_id=variant,variant_name='web_720p',recipe_digest=AV_RECIPE,max_attempts=5,
                source_video=True,source_audio=True,source_duration_ms=200,upload_stimuli=1,boot_id=old['old_runtime']['boot_id'])
    failed=dict(job_id=2,attempt=5,state='discarded',error_attempts=[1,2,3,4,5],variant_id=variant,
                variant_state='failed',diagnostic='failed_work',fault_downloads=5,processor_reason='unsupported_codec')
    trail=[dict(job_id=2,attempt=i,state='retryable' if i<5 else 'discarded',error_attempts=list(range(1,i+1)),fault_downloads=i) for i in range(1,6)]
    failure=dict(before=before,failed=failed,attempts=trail,elapsed_ms=100000,deadline_ms=600000,remaining_ms=500000,input_decoded=True)
    repair=dict(asset_id=asset,variant_id=variant,source_key=source,variant_key=key,source_sha256=AV_SHA256,
                output_sha256='b'*64,asset_state='ready',variant_state='ready',discarded_job_id=2,new_job_id=3,
                new_job_state='completed',new_job_attempt=1,selected=1,enqueued=1,skipped=0,errors=0,
                fault_restored=True,error_cleared=True)
    output=dict(video_codec='h264',audio_codec='aac',width=1280,height=720,duration_ms=200,fully_decoded=True)
    receipt=dict(schema_version=2,kind=old['kind'],independent_pilot_credit=False,inputs=copy.deepcopy(inputs),case_id='av-repair',
                 outcome='complete',reason='complete',stage='complete',dependency='none',runtime=old['old_runtime'],
                 isolation=old['isolation'],host_exited=True,failure=failure,repair=repair,output=output,
                 object_keys=sorted([source,key]),versions=dict(ffmpeg='7.1.1',ffprobe='7.1.1'))
    assert verify_receipt(inputs,receipt)
    mutations=[(['failure','failed','attempt'],4),(['failure','failed','error_attempts'],[1,2,3,4]),
      (['failure','failed','state'],'retryable'),(['failure','failed','diagnostic'],'pending'),
      (['failure','failed','fault_downloads'],4),(['failure','input_decoded'],False),
      (['failure','elapsed_ms'],600000),(['failure','remaining_ms'],0),
      (['repair','new_job_id'],2),(['repair','enqueued'],0),(['repair','skipped'],1),
      (['repair','variant_id'],'00000000-0000-4000-8000-000000000009'),(['repair','fault_restored'],False),
      (['repair','source_sha256'],'b'*64),(['repair','variant_key'],source),(['repair','asset_state'],'degraded'),
      (['repair','new_job_state'],'available'),(['repair','error_cleared'],False),
      (['output','fully_decoded'],False),(['output','audio_codec'],'none'),(['output','duration_ms'],0),
      (['versions','ffmpeg'],'5.1.1'),(['object_keys'],[source])]
    for path,value in mutations:
        r=copy.deepcopy(receipt);target=r
        for k in path[:-1]:target=target[k]
        target[path[-1]]=value
        try:verify_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError(path)
    """

    assert {_, 0} = python(code)
  end

  test "provider evidence binds queued replay, stale events, committed effects and the packaged SDK" do
    code = """
    import copy,hashlib
    from twin_fixture import fixture
    from twin_receipt import verify_receipt, Refused, AV_SHA256, AV_RECIPE
    inputs,old=fixture();inputs.update(schema_version=2,scenario='provider-events',fixture_sha256=AV_SHA256)
    sha=lambda value:hashlib.sha256(value.encode()).hexdigest()
    asset=old['before']['asset_id'];row='00000000-0000-4000-8000-000000000005'
    source='elixir-twin-providerprofile/'+asset+'/00000000-0000-4000-8000-000000000004.mp4'
    variant='Elixir.Twin.ProviderProfile/'+asset+'/web_720p-'+AV_RECIPE+'.mp4'
    provider_sha=sha('MUX_PROVIDER_CANARY_'+inputs['run_id']);ready_sha=sha('ready-'+inputs['run_id'])
    initial=dict(row_id=row,asset_id=asset,provider_sha256=provider_sha,state='processing',playback_ids=[],last_event_at=None,event_sha256=None)
    accepted=dict(initial,state='ready',playback_ids=['twin-playback'],last_event_at='2026-05-06T00:00:02.000001Z',event_sha256=ready_sha)
    jobs=[]
    for index,role in enumerate(['promotion','media','create','ready','replay','older_created','older_errored'],1):
        queue={'promotion':'rindle_promote','media':'rindle_media'}.get(role,'rindle_provider')
        event={'ready':ready_sha,'replay':ready_sha,'older_created':sha('older-created-'+inputs['run_id']),
               'older_errored':sha('older-error-'+inputs['run_id'])}.get(role)
        jobs.append(dict(id=index,role=role,queue=queue,state='completed',attempt=1,event_sha256=event))
    provider=dict(asset_id=asset,source_key=source,variant_key=variant,provider_row_id=row,provider_sha256=provider_sha,
      snapshots=[initial]+[copy.deepcopy(accepted) for _ in range(4)],
      pending=dict(paused=True,running=0,job_id=4,count=1,attempt=0,state='available'),
      http_statuses=[202,202,202,202,202,400],jobs=jobs,
      effects=[dict(state_changes=2,processed=0,ready_messages=0)]+
              [dict(state_changes=3,processed=1,ready_messages=2) for _ in range(4)],
      create_calls=1,input_path_sha256=sha('/twin-'+inputs['run_id']+'/'+variant),invalid_signatures=1,leaks=0,
      sdk_version='3.2.2',sdk_origin='/twin/_build/prod/lib/mux/ebin/Elixir.Mux.Video.Assets.beam')
    receipt=dict(schema_version=2,kind=old['kind'],independent_pilot_credit=False,inputs=copy.deepcopy(inputs),
      case_id='provider-events',outcome='complete',reason='complete',stage='complete',dependency='none',
      runtime=old['old_runtime'],isolation=old['isolation'],host_exited=True,provider=provider,
      object_keys=sorted([source,variant]))
    assert verify_receipt(inputs,receipt)
    mutations=[(['provider','asset_id'],row),(['provider','provider_row_id'],asset),
      (['provider','provider_sha256'],'b'*64),(['provider','source_key'],source+'extra'),
      (['provider','variant_key'],source),(['provider','input_path_sha256'],'b'*64),
      (['provider','sdk_version'],'3.2.1'),(['provider','sdk_origin'],'checkout/mux/ebin'),
      (['provider','snapshots'],provider['snapshots'][:4]),(['provider','snapshots',0,'state'],'ready'),
      (['provider','snapshots',0,'last_event_at'],'2026-05-06T00:00:01Z'),
      (['provider','snapshots',1,'row_id'],asset),(['provider','snapshots',1,'asset_id'],row),
      (['provider','snapshots',2,'provider_sha256'],'b'*64),(['provider','snapshots',2,'state'],'errored'),
      (['provider','snapshots',3,'playback_ids'],[]),(['provider','snapshots',3,'event_sha256'],'b'*64),
      (['provider','snapshots',4,'last_event_at'],'2026-05-06T00:00:01.999999Z'),
      (['provider','pending','paused'],False),(['provider','pending','running'],1),
      (['provider','pending','job_id'],5),(['provider','pending','count'],2),
      (['provider','pending','attempt'],1),(['provider','pending','state'],'executing'),
      (['provider','http_statuses'],[202]*6),(['provider','http_statuses',0],True),
      (['provider','jobs'],jobs[:-1]),(['provider','jobs',4,'id'],4),
      (['provider','jobs',5,'role'],'ready'),(['provider','jobs',2,'queue'],'rindle_media'),
      (['provider','jobs',6,'state'],'available'),(['provider','jobs',6,'attempt'],2),
      (['provider','jobs',0,'event_sha256'],ready_sha),(['provider','jobs',3,'event_sha256'],None),
      (['provider','jobs',5,'event_sha256'],sha('older-error-'+inputs['run_id'])),
      (['provider','effects'],provider['effects'][:4]),(['provider','effects',0,'processed'],1),
      (['provider','effects',1,'state_changes'],4),(['provider','effects',2,'processed'],2),
      (['provider','effects',3,'ready_messages'],4),(['provider','effects',4,'ready_messages'],True),
      (['provider','create_calls'],2),(['provider','invalid_signatures'],0),(['provider','leaks'],1),
      (['provider','leaks'],False),(['object_keys'],[source]),(['host_exited'],False)]
    for path,value in mutations:
        r=copy.deepcopy(receipt);target=r
        for key in path[:-1]:target=target[key]
        target[path[-1]]=value
        try:verify_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError(path)
    for path in [[],['provider'],['provider','pending'],['provider','snapshots',0],
                 ['provider','snapshots',4],['provider','jobs',0],['provider','effects',4]]:
        original=receipt
        for key in path:original=original[key]
        for field in original:
            r=copy.deepcopy(receipt);target=r
            for key in path:target=target[key]
            del target[field]
            try:verify_receipt(inputs,r)
            except Refused:pass
            else:raise AssertionError(('missing',path,field))
        for field in ['raw_body','signature','signed_url','provider_id','job_error','telemetry']:
            r=copy.deepcopy(receipt);target=r
            for key in path:target=target[key]
            target[field]='SECRET_CANARY'
            try:verify_receipt(inputs,r)
            except Refused as error:assert 'SECRET_CANARY' not in str(error)
            else:raise AssertionError(('secret',path,field))
    wrong_inputs=copy.deepcopy(inputs);wrong_inputs['fixture_sha256']='b'*64
    r=copy.deepcopy(receipt);r['inputs']=wrong_inputs
    try:verify_receipt(wrong_inputs,r)
    except Refused:pass
    else:raise AssertionError('unbound source fixture')
    """

    assert {_, 0} = python(code)
  end

  test "promotion restart requires the unchanged queued job, killed old runtime and one resumed promotion" do
    code = """
    import copy
    from twin_fixture import fixture
    from twin_receipt import verify_receipt, verify_case_receipt, Refused, TUS_SHA256, THUMB_KEY
    inputs,old=fixture();inputs.update(schema_version=2,scenario='promotion-restart',fixture_sha256=TUS_SHA256)
    asset=old['before']['asset_id'];session='00000000-0000-4000-8000-000000000005'
    source='elixir-twin-profile/'+asset+'/00000000-0000-4000-8000-000000000004.png'
    variant='Elixir.Twin.Profile/'+asset+'/'+THUMB_KEY
    before=dict(session_id=session,asset_id=asset,source_key=source,job_id=1,attempt=0,state='available',
      asset_state='validating',session_state='completed',paused=True,running=0,upload_stimuli=1,
      completion_stimuli=1,boot_id=old['old_runtime']['boot_id'])
    after=dict(session_id=session,asset_id=asset,source_key=source,job_id=1,attempt=1,state='completed',
      asset_state='ready',session_state='completed',upload_stimuli=1,completion_stimuli=1,
      boot_id=old['new_runtime']['boot_id'],checksum_sha256=TUS_SHA256,variant_key=variant)
    jobs=[dict(id=1,queue='rindle_promote',state='completed',attempt=1),
          dict(id=2,queue='rindle_process',state='completed',attempt=1)]
    restart=dict(before=before,cut=copy.deepcopy(before),after=after,old_runtime=old['old_runtime'],
      new_runtime=old['new_runtime'],old_container=old['old_container'],new_container=old['new_container'],
      signal='SIGKILL',exit_code=137,old_exited=True,elapsed_ms=1000,deadline_ms=180000,jobs=jobs)
    receipt=dict(schema_version=2,kind=old['kind'],independent_pilot_credit=False,inputs=copy.deepcopy(inputs),
      case_id='promotion-restart',outcome='complete',reason='complete',stage='complete',dependency='none',
      runtime=old['new_runtime'],isolation=old['isolation'],host_exited=True,restart=restart,
      object_keys=sorted([source,variant]))
    assert verify_receipt(inputs,receipt)
    mutations=[(['case_id'],'tus-resume'),(['schema_version'],1),(['outcome'],'incomplete'),(['stage'],'restart'),
      (['host_exited'],False),(['runtime'],old['old_runtime']),(['object_keys'],[source]),
      (['object_keys'],sorted([source,variant,'foreign'])),(['restart','before','paused'],False),
      (['restart','before','running'],1),(['restart','before','attempt'],1),
      (['restart','before','state'],'executing'),(['restart','before','asset_state'],'staged'),
      (['restart','before','session_state'],'signed'),(['restart','before','session_id'],asset),
      (['restart','before','asset_id'],session),(['restart','before','boot_id'],session),
      (['restart','before','source_key'],source+'extra'),(['restart','before','job_id'],True),
      (['restart','after','session_id'],'00000000-0000-4000-8000-000000000009'),
      (['restart','after','asset_id'],'00000000-0000-4000-8000-000000000009'),
      (['restart','after','source_key'],'elixir-twin-profile/'+asset+'/00000000-0000-4000-8000-000000000009.png'),
      (['restart','after','job_id'],3),(['restart','after','attempt'],2),
      (['restart','after','state'],'available'),(['restart','after','asset_state'],'validating'),
      (['restart','after','session_state'],'expired'),(['restart','after','boot_id'],before['boot_id']),
      (['restart','after','checksum_sha256'],'b'*64),(['restart','after','variant_key'],source),
      (['restart','old_runtime'],old['new_runtime']),(['restart','new_runtime'],old['old_runtime']),
      (['restart','old_runtime','origin'],'checkout'),(['restart','new_runtime','lock_sha256'],'b'*64),
      (['restart','new_container'],restart['old_container']),(['restart','old_container'],'foreign'),
      (['restart','signal'],'SIGTERM'),(['restart','exit_code'],0),(['restart','exit_code'],True),
      (['restart','old_exited'],False),(['restart','elapsed_ms'],0),(['restart','elapsed_ms'],180000),
      (['restart','elapsed_ms'],True),(['restart','deadline_ms'],180001),
      (['restart','jobs'],jobs[:1]),(['restart','jobs'],jobs+[dict(jobs[1],id=3)]),
      (['restart','jobs',0,'id'],3),(['restart','jobs',1,'id'],1),
      (['restart','jobs',0,'queue'],'rindle_process'),(['restart','jobs',1,'queue'],'rindle_promote'),
      (['restart','jobs',1,'attempt'],2),(['restart','jobs',0,'state'],'available')]
    for phase in ['before','cut','after']:
        for key in ['upload_stimuli','completion_stimuli']:
            mutations.extend([(['restart',phase,key],2),(['restart',phase,key],True)])
    substitutions=dict(before,session_id='00000000-0000-4000-8000-000000000009',
      asset_id='00000000-0000-4000-8000-000000000008',
      source_key='elixir-twin-profile/'+asset+'/00000000-0000-4000-8000-000000000009.png',
      job_id=3,attempt=1,state='executing',asset_state='ready',session_state='expired',paused=False,
      running=1,upload_stimuli=2,completion_stimuli=2,boot_id=after['boot_id'])
    for field,value in substitutions.items():mutations.append((['restart','cut',field],value))
    for path,value in mutations:
        r=copy.deepcopy(receipt);target=r
        for key in path[:-1]:target=target[key]
        target[path[-1]]=value
        try:verify_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError(path)
    for path in [[],['restart'],['restart','before'],['restart','cut'],['restart','after'],
                 ['restart','old_runtime'],['restart','new_runtime'],['restart','jobs',0],['restart','jobs',1]]:
        original=receipt
        for key in path:original=original[key]
        for field in original:
            r=copy.deepcopy(receipt);target=r
            for key in path:target=target[key]
            del target[field]
            try:verify_receipt(inputs,r)
            except Refused:pass
            else:raise AssertionError(('missing',path,field))
        r=copy.deepcopy(receipt);target=r
        for key in path:target=target[key]
        target['raw_job_error']='SECRET_CANARY'
        try:verify_receipt(inputs,r)
        except Refused as error:assert 'SECRET_CANARY' not in str(error)
        else:raise AssertionError(('unknown',path))
    for field in ['run_id','package_tar_sha256','fixture_sha256','lock_sha256']:
        r=copy.deepcopy(receipt);r['inputs'][field]='b'*(32 if field=='run_id' else 64)
        try:verify_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError(('input',field))
    legacy_inputs,legacy=fixture()
    try:verify_case_receipt(legacy_inputs,legacy)
    except Refused:pass
    else:raise AssertionError('legacy substituted for queued promotion recovery')
    """

    assert {_, 0} = python(code)
  end

  test "interrupted cleanup requires genuine expiry, a real part, the exact cut and two complete reruns" do
    code = """
    import copy
    from twin_fixture import fixture
    from twin_receipt import verify_receipt, Refused, TUS_SHA256
    inputs,old=fixture();inputs.update(schema_version=2,scenario='interrupted-cleanup',fixture_sha256=TUS_SHA256)
    multi_asset='00000000-0000-4000-8000-000000000001';orphan_asset='00000000-0000-4000-8000-000000000002'
    multi_session='00000000-0000-4000-8000-000000000003';orphan_session='00000000-0000-4000-8000-000000000004'
    multi_key='elixir-twin-profile/'+multi_asset+'/00000000-0000-4000-8000-000000000005.png'
    orphan_key='elixir-twin-profile/'+orphan_asset+'/00000000-0000-4000-8000-000000000006.png'
    part=dict(number=1,etag_sha256='b'*64,bytes=69)
    before=dict(multipart_session_id=multi_session,orphan_session_id=orphan_session,
      multipart_asset_id=multi_asset,orphan_asset_id=orphan_asset,multipart_key=multi_key,orphan_key=orphan_key,
      upload_sha256='a'*64,parts=[part],expiry_seconds=5,observed_at='2026-05-06T00:00:00.000001Z',
      expires_at=['2026-05-06T00:00:05.000001Z','2026-05-06T00:00:05.000002Z'],stimuli=dict(multipart=1,orphan=1))
    abort=dict(states=['expired','expired'],observed_at='2026-05-06T00:00:05.000002Z',task_exit=0,
      multipart_present=True,parts=[copy.deepcopy(part)],listing_complete=True)
    interrupted=dict(orphan_session_id=orphan_session,orphan_key=orphan_key,row_retained=True,row_state='expired',
      object_head='not_found',barrier='after_delete_before_row',maintenance_pid=100,main_pid=1,
      maintenance_exited=True,maintenance_exit=137,main_boot_id=old['old_runtime']['boot_id'],main_alive=True)
    rerun=dict(task_exit=0,sessions=0,objects=0,multipart=0,parts=0,listing_complete=True)
    jobs=[dict(id=1,queue='rindle_purge',state='completed',attempt=1),
          dict(id=2,queue='rindle_purge',state='completed',attempt=1)]
    converged=dict(asset_ids=sorted([multi_asset,orphan_asset]),purge_jobs=jobs,domain_empty=True)
    cleanup=dict(before=before,abort=abort,interrupted=interrupted,reruns=[copy.deepcopy(rerun) for _ in range(2)],converged=converged)
    receipt=dict(schema_version=2,kind=old['kind'],independent_pilot_credit=False,inputs=copy.deepcopy(inputs),
      case_id='interrupted-cleanup',outcome='complete',reason='complete',stage='complete',dependency='none',
      runtime=old['old_runtime'],isolation=old['isolation'],host_exited=True,cleanup=cleanup)
    assert verify_receipt(inputs,receipt)
    mutations=[(['cleanup','before','multipart_session_id'],orphan_session),
      (['cleanup','before','multipart_asset_id'],orphan_asset),(['cleanup','before','multipart_key'],orphan_key),
      (['cleanup','before','orphan_key'],orphan_key+'extra'),(['cleanup','before','upload_sha256'],'raw-upload-id'),
      (['cleanup','before','parts'],[]),(['cleanup','before','parts'],[part,part]),
      (['cleanup','before','parts',0,'number'],2),(['cleanup','before','parts',0,'number'],True),
      (['cleanup','before','parts',0,'bytes'],0),(['cleanup','before','parts',0,'etag_sha256'],'etag'),
      (['cleanup','before','expiry_seconds'],0),(['cleanup','before','expiry_seconds'],-5),
      (['cleanup','before','expiry_seconds'],True),
      (['cleanup','before','observed_at'],'2026-05-06T00:00:05.000001Z'),
      (['cleanup','before','observed_at'],'2026-05-06T00:00:00'),
      (['cleanup','before','observed_at'],'2026-02-31T00:00:00Z'),
      (['cleanup','before','expires_at'],['2026-05-05T23:59:59Z']*2),
      (['cleanup','before','expires_at'],list(reversed(before['expires_at']))),
      (['cleanup','before','expires_at'],before['expires_at'][:1]),
      (['cleanup','before','stimuli','multipart'],2),(['cleanup','before','stimuli','orphan'],2),
      (['cleanup','abort','states'],['signed','expired']),(['cleanup','abort','states'],['expired']),
      (['cleanup','abort','observed_at'],'2026-05-06T00:00:05.000001Z'),
      (['cleanup','abort','task_exit'],1),(['cleanup','abort','task_exit'],False),
      (['cleanup','abort','multipart_present'],False),(['cleanup','abort','parts'],[]),
      (['cleanup','abort','parts',0,'etag_sha256'],'c'*64),(['cleanup','abort','listing_complete'],False),
      (['cleanup','interrupted','orphan_session_id'],multi_session),(['cleanup','interrupted','orphan_key'],multi_key),
      (['cleanup','interrupted','row_retained'],False),(['cleanup','interrupted','row_state'],'signed'),
      (['cleanup','interrupted','object_head'],'denied'),(['cleanup','interrupted','object_head'],'unknown'),
      (['cleanup','interrupted','object_head'],'present'),(['cleanup','interrupted','barrier'],'before_delete'),
      (['cleanup','interrupted','maintenance_pid'],1),(['cleanup','interrupted','maintenance_pid'],True),
      (['cleanup','interrupted','main_pid'],100),(['cleanup','interrupted','main_alive'],False),
      (['cleanup','interrupted','maintenance_exited'],False),(['cleanup','interrupted','maintenance_exit'],0),
      (['cleanup','interrupted','main_boot_id'],old['new_runtime']['boot_id']),
      (['cleanup','reruns'],[rerun]),(['cleanup','reruns'],[rerun,rerun,rerun]),
      (['cleanup','converged','asset_ids'],[multi_asset]),
      (['cleanup','converged','asset_ids'],[multi_asset,'00000000-0000-4000-8000-000000000009']),
      (['cleanup','converged','domain_empty'],False),(['cleanup','converged','purge_jobs'],jobs[:1]),
      (['cleanup','converged','purge_jobs'],list(reversed(jobs))),
      (['cleanup','converged','purge_jobs',1,'id'],1),(['cleanup','converged','purge_jobs',0,'id'],True),
      (['cleanup','converged','purge_jobs',0,'queue'],'foreign'),
      (['cleanup','converged','purge_jobs',0,'state'],'available'),
      (['cleanup','converged','purge_jobs',1,'attempt'],2)]
    for index in range(2):
        for key in ['task_exit','sessions','objects','multipart','parts']:
            mutations.extend([(['cleanup','reruns',index,key],1),(['cleanup','reruns',index,key],False)])
        mutations.append((['cleanup','reruns',index,'listing_complete'],False))
    for path,value in mutations:
        r=copy.deepcopy(receipt);target=r
        for key in path[:-1]:target=target[key]
        target[path[-1]]=value
        try:verify_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError(path)
    for path in [[],['cleanup'],['cleanup','before'],['cleanup','before','parts',0],['cleanup','before','stimuli'],
                 ['cleanup','abort'],['cleanup','abort','parts',0],['cleanup','interrupted'],
                 ['cleanup','reruns',0],['cleanup','reruns',1],['cleanup','converged'],['cleanup','converged','purge_jobs',0]]:
        original=receipt
        for key in path:original=original[key]
        for field in original:
            r=copy.deepcopy(receipt);target=r
            for key in path:target=target[key]
            del target[field]
            try:verify_receipt(inputs,r)
            except Refused:pass
            else:raise AssertionError(('missing',path,field))
        for field in ['upload_id','signed_url','raw_job_error']:
            r=copy.deepcopy(receipt);target=r
            for key in path:target=target[key]
            target[field]='SECRET_CANARY'
            try:verify_receipt(inputs,r)
            except Refused as error:assert 'SECRET_CANARY' not in str(error)
            else:raise AssertionError(('unknown',path,field))
    bad_inputs=copy.deepcopy(inputs);bad_inputs['fixture_sha256']='b'*64
    r=copy.deepcopy(receipt);r['inputs']=bad_inputs
    try:verify_receipt(bad_inputs,r)
    except Refused:pass
    else:raise AssertionError('wrong fixture')
    r=copy.deepcopy(receipt)
    r['cleanup']['before']['observed_at']='2026-05-05T20:00:00.000001-04:00'
    r['cleanup']['abort']['observed_at']='2026-05-06T01:00:05.000002+01:00'
    assert verify_receipt(inputs,r)
    """

    assert {_, 0} = python(code)
  end

  test "full matrix binds all six cases to one archive and exact frozen inventories" do
    code = """
    import copy,hashlib,json,re,textwrap
    from pathlib import Path
    import twin_fixture
    from twin_receipt import (verify_receipt, verify_matrix_receipt, validate_inputs, decode, Refused,
      CASES, DOMAIN, MATRIX_SCENARIO, FIXTURE_MATRIX_SHA256, TUS_SHA256, MAX_BYTES)
    # Reuse only the six positive builder prefixes above, before their first assertion.
    # Each executes with a fresh run identity; their negative controls are not executed here.
    source=Path('test/install_smoke/twin_receipt_test.exs').read_text()
    builders={}
    for block in source.split('code = '+chr(34)*3)[1:]:
        match=re.search(r"scenario\\s*=\\s*'([^']+)'",block)
        if match and match.group(1) in CASES:
            builders[match.group(1)]=textwrap.dedent(block.split('assert verify_receipt(inputs,receipt)',1)[0])
    assert set(builders)==set(CASES)
    original_fixture=twin_fixture.fixture
    children={};receipts={}
    for index,case in enumerate(CASES,1):
        def seeded_fixture():
            inputs,receipt=original_fixture();inputs.update(run_id=format(index,'032x'),fixture_sha256=TUS_SHA256)
            return inputs,receipt
        twin_fixture.fixture=seeded_fixture
        namespace={};exec(builders[case],namespace)
        children[case]=namespace['inputs'];receipts[case]=namespace['receipt']
        assert verify_receipt(children[case],receipts[case])
    twin_fixture.fixture=original_fixture
    root_inputs=copy.deepcopy(children[CASES[0]])
    root_inputs.update(schema_version=3,scenario=MATRIX_SCENARIO,run_id='f'*32,
      fixture_sha256=FIXTURE_MATRIX_SHA256,case_inputs=copy.deepcopy(children))
    sha=lambda value:hashlib.sha256(value.encode()).hexdigest()
    def job(job_id,queue,asset,attempt=1,state='completed',errors=None,event=None):
        return dict(id=job_id,queue=queue,asset_id=asset,attempt=attempt,state=state,
                    error_attempts=[] if errors is None else errors,event_sha256=event)
    def audit_for(case,receipt):
        if case=='tus-resume':asset=receipt['result']['asset_id']
        elif case=='purge-absence':asset=receipt['before']['asset_id']
        elif case=='av-repair':asset=receipt['failure']['before']['asset_id']
        elif case=='provider-events':asset=receipt['provider']['asset_id']
        elif case=='promotion-restart':asset=receipt['restart']['before']['asset_id']
        else:asset=None
        assets=[asset] if asset else sorted(receipt['cleanup']['before'][k] for k in ['multipart_asset_id','orphan_asset_id'])
        rows=[];fixture_rows=[]
        def fixture(operation,value,claims):
            fixture_rows.append(dict(run_id=children[case]['run_id'],operation=operation,source_sha256=sha(value),claims=claims))
        if case=='tus-resume':
            rows=[job(1,'rindle_promote',asset),job(2,'rindle_process',asset),job(3,'rindle_purge',asset)]
            fixture('tus','one-upload',1)
        elif case=='purge-absence':
            for original in receipt['inventory']['jobs']:
                rows.append(job(original['id'],original['queue'],asset,attempt=original['attempt'],
                                errors=[1] if original['queue']=='rindle_purge' else []))
            fixture('stimulus',receipt['before']['source_key'],1);fixture('delete',receipt['before']['source_key'],1)
        elif case=='av-repair':
            rows=[job(1,'rindle_promote',asset),job(receipt['failure']['before']['job_id'],'rindle_media',asset,
                  attempt=5,state='discarded',errors=[1,2,3,4,5]),
                  job(receipt['repair']['new_job_id'],'rindle_media',asset),job(4,'rindle_purge',asset)]
            fixture('av-stimulus','one-upload',1);fixture('av-enabled',receipt['failure']['before']['source_key'],0)
            fixture('av-download',receipt['failure']['before']['source_key'],5)
        elif case=='provider-events':
            rows=[job(j['id'],j['queue'],asset,event=j['event_sha256']) for j in receipt['provider']['jobs']]
            rows.append(job(8,'rindle_purge',asset))
            fixture('provider-create',receipt['provider']['input_path_sha256'],1)
            for operation,count in [('provider-delete',1),('provider-state',3),('provider-processed',1),
                                    ('provider-ready',2),('provider-leak',0),('provider-invalid',1)]:
                fixture(operation,'local-mux',count)
        elif case=='promotion-restart':
            rows=[job(j['id'],j['queue'],asset) for j in receipt['restart']['jobs']]+[job(3,'rindle_purge',asset)]
            fixture('promotion-upload','one-upload',1)
            fixture('promotion-completion',receipt['restart']['before']['session_id'],1)
        else:
            rows=[job(j['id'],'rindle_purge',a) for j,a in zip(receipt['cleanup']['converged']['purge_jobs'],assets)]
            before=receipt['cleanup']['before']
            fixture('cleanup-multipart',before['multipart_key'],1);fixture('cleanup-orphan',before['orphan_key'],1)
            fixture('cleanup-arm',before['orphan_key'],0)
            fixture('cleanup-barrier',before['orphan_key'],receipt['cleanup']['interrupted']['maintenance_pid'])
        container=receipt['restart']['new_container'] if case=='promotion-restart' else sha('host-'+case)
        return dict(asset_ids=assets,purge_job_ids=sorted(j['id'] for j in rows if j['queue']=='rindle_purge'),
          domain={k:[1] if k=='rindle_migration_versions' else [] for k in DOMAIN},
          relations=dict(public=['oban_jobs','oban_peers','schema_migrations','twin_fault_counters'],rindle=sorted(DOMAIN)),
          jobs=sorted(rows,key=lambda j:j['id']),fixtures=sorted(fixture_rows,key=lambda f:f['operation']),
          schema_migrations=[20261021000000],peers=[],objects=[],multipart=[],parts=[],temp_files=[],processes=[],
          host_container=container,host_exited=True,writers_stopped=True,listing_complete=True,
          versioning_disabled=True,frozen_before_disposal=True)
    items=[dict(case_id=case,receipt=receipts[case],audit=audit_for(case,receipts[case])) for case in CASES]
    receipt=dict(schema_version=3,kind=root_inputs['kind'],independent_pilot_credit=False,inputs=copy.deepcopy(root_inputs),
      outcome='complete',reason='complete',stage='complete',dependency='none',cases=items,elapsed_ms=100000,
      all_hosts_exited=True,domain_verdict_frozen=True)
    assert verify_receipt(root_inputs,receipt)
    assert verify_matrix_receipt(root_inputs,decode(json.dumps(receipt,indent=2)))
    assert len(json.dumps(receipt,indent=2).encode())<=MAX_BYTES
    def rejected(inputs,record,label):
        try:verify_receipt(inputs,record)
        except Refused:pass
        else:raise AssertionError(label)
    mutations=[(['cases'],items[:-1]),(['cases'],items+[items[0]]),(['cases',1],items[0]),
      (['cases',0,'case_id'],'unknown'),(['cases'],list(reversed(items))),
      (['cases',0,'receipt'],None),(['cases',0,'receipt','case_id'],[]),
      (['cases',0,'receipt'],items[1]['receipt']),(['cases',0,'receipt','outcome'],'skipped'),
      (['cases',0,'receipt','inputs','package_tar_sha256'],'b'*64),
      (['cases',1,'receipt','inputs','run_id'],children[CASES[0]]['run_id']),
      (['cases',2,'receipt','inputs','host_sha256'],'b'*64),
      (['cases',3,'receipt','inputs','config_sha256'],'b'*64),
      (['cases',4,'receipt','inputs','lock_sha256'],'b'*64),
      (['cases',5,'receipt','inputs','contract_sha256'],'b'*64),
      (['cases',0,'audit','asset_ids'],['00000000-0000-4000-8000-000000000009']),
      (['cases',0,'audit','purge_job_ids'],[99]),(['cases',1,'audit','purge_job_ids'],[99]),
      (['cases',5,'audit','purge_job_ids'],[1,3]),(['cases',0,'audit','jobs'],items[0]['audit']['jobs'][:-1]),
      (['cases',0,'audit','jobs',0,'asset_id'],'00000000-0000-4000-8000-000000000009'),
      (['cases',0,'audit','jobs',0,'queue'],'foreign'),(['cases',0,'audit','jobs',0,'id'],True),
      (['cases',0,'audit','jobs',0,'state'],'executing'),(['cases',0,'audit','jobs',1,'id'],1),
      (['cases',0,'audit','jobs'],list(reversed(items[0]['audit']['jobs']))),
      (['cases',1,'audit','jobs',2,'attempt'],1),(['cases',1,'audit','jobs',2,'error_attempts'],[]),
      (['cases',2,'audit','jobs',1,'error_attempts'],[1,2,3,4]),(['cases',2,'audit','jobs',1,'id'],99),
      (['cases',2,'audit','jobs',2,'id'],99),(['cases',3,'audit','jobs',3,'event_sha256'],'b'*64),
      (['cases',3,'audit','jobs',3,'id'],99),(['cases',4,'audit','jobs',0,'id'],99),
      (['cases',4,'audit','host_container'],items[4]['receipt']['restart']['old_container']),
      (['cases',1,'audit','host_container'],items[0]['audit']['host_container']),
      (['cases',0,'audit','fixtures'],[]),(['cases',0,'audit','fixtures',0,'operation'],'foreign'),
      (['cases',0,'audit','fixtures',0,'source_sha256'],'b'*64),
      (['cases',0,'audit','fixtures',0,'run_id'],root_inputs['run_id']),
      (['cases',0,'audit','fixtures',0,'claims'],2),(['cases',0,'audit','fixtures',0,'claims'],True),
      (['cases',0,'audit','domain','media_assets'],['foreign']),
      (['cases',0,'audit','domain','rindle_migration_versions'],[True]),
      (['cases',0,'audit','domain','rindle_migration_versions'],[1,2]),
      (['cases',0,'audit','relations','public'],['oban_jobs']),
      (['cases',0,'audit','schema_migrations'],[20261021000001]),
      (['all_hosts_exited'],False),(['domain_verdict_frozen'],False),(['elapsed_ms'],0),
      (['elapsed_ms'],7200001),(['elapsed_ms'],True),(['outcome'],'incomplete'),(['stage'],'disposal')]
    for index in range(len(CASES)):
        for field in ['host_exited','writers_stopped','listing_complete','versioning_disabled','frozen_before_disposal']:
            mutations.extend([(['cases',index,'audit',field],False),(['cases',index,'audit',field],1)])
        for field in ['peers','objects','multipart','parts','temp_files','processes']:
            mutations.append((['cases',index,'audit',field],['residue']))
    for path,value in mutations:
        r=copy.deepcopy(receipt);target=r
        for key in path[:-1]:target=target[key]
        target[path[-1]]=value
        rejected(root_inputs,r,path)
    for case in CASES:
        for field in ['source_sha','package_tar_sha256','package_metadata_sha256','package_tree_sha256',
                      'host_sha256','lock_sha256','config_sha256','contract_sha256','build_sha256','fixture_sha256']:
            i=copy.deepcopy(root_inputs);i['case_inputs'][case][field]='b'*(40 if field=='source_sha' else 64)
            r=copy.deepcopy(receipt);r['inputs']=copy.deepcopy(i)
            rejected(i,r,('shared input',case,field))
        for duplicate in [root_inputs['run_id'],children[CASES[(CASES.index(case)+1)%len(CASES)]]['run_id']]:
            i=copy.deepcopy(root_inputs);i['case_inputs'][case]['run_id']=duplicate
            r=copy.deepcopy(receipt);r['inputs']=copy.deepcopy(i)
            rejected(i,r,('duplicate run',case))
    for path in [[],['cases',0],['cases',0,'audit'],['cases',0,'audit','jobs',0],['cases',0,'audit','fixtures',0]]:
        original=receipt
        for key in path:original=original[key]
        for field in original:
            r=copy.deepcopy(receipt);target=r
            for key in path:target=target[key]
            del target[field]
            rejected(root_inputs,r,('missing',path,field))
        r=copy.deepcopy(receipt);target=r
        for key in path:target=target[key]
        target['raw_body']='SECRET_CANARY'
        rejected(root_inputs,r,('unknown secret',path))
    for field in ['case_inputs','run_id','fixture_sha256']:
        i=copy.deepcopy(root_inputs);del i[field]
        rejected(i,receipt,('missing input',field))
    i=copy.deepcopy(root_inputs);i['fixture_sha256']='b'*64
    rejected(i,receipt,'wrong aggregate fixture')
    i=copy.deepcopy(root_inputs);i['case_inputs'][CASES[0]],i['case_inputs'][CASES[1]]=i['case_inputs'][CASES[1]],i['case_inputs'][CASES[0]]
    rejected(i,receipt,'swapped case authorities')
    for case in CASES:
        try:verify_matrix_receipt(children[case],receipts[case])
        except Refused:pass
        else:raise AssertionError('focused receipt counted as full matrix')
    """

    assert {output, 0} = python(code)
    refute output =~ "SECRET_CANARY"
  end
end
