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
end
