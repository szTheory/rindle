# Changelog

0.1.0-0.1.3 were release-pipeline shakedown iterations; treat 0.1.4 as the first recommended pin.

## [0.1.5](https://github.com/szTheory/rindle/compare/rindle-v0.1.4...rindle-v0.1.5) (2026-05-07)


### Features

* **17-03:** hide domain invariant modules ([9652c45](https://github.com/szTheory/rindle/commit/9652c4547af905db29856a42278262b259413ab2))
* **17-04:** add preferred verification facade alias ([9cc690f](https://github.com/szTheory/rindle/commit/9cc690fb7ab943a064537782dfa3b80bb1d074b5))
* **18-01:** add :doctor 0.22.0 + baseline .doctor.exs config ([382c800](https://github.com/szTheory/rindle/commit/382c800356c0d7cbdba827991ef620d0e8de55c1))
* **18-02:** add 7 named result types to Rindle.Storage behaviour ([fc5e173](https://github.com/szTheory/rindle/commit/fc5e1733644024424ebe243b8b118eb0efef35e4))
* **18-02:** tighten Rindle facade [@specs](https://github.com/specs) to schema struct types ([2e3a4a5](https://github.com/szTheory/rindle/commit/2e3a4a54a98ad1fca8ad58301d8bb967c9c1db27))
* **18-03:** add [@doc](https://github.com/doc) to behaviour callbacks + behaviour_docs_test backstop ([3929f25](https://github.com/szTheory/rindle/commit/3929f259a8efb120ca35ecd74d68cb83d9a8d92a))
* **18-03:** add 6 Broker [@specs](https://github.com/specs) + promote Rindle.Processor.Image to public adapter ([f4fefbd](https://github.com/szTheory/rindle/commit/f4fefbd63b5333a3f887d3d95d48f672c9902b26))
* **18-04:** add [@deprecated](https://github.com/deprecated) to facade shim, repoint internal caller, add README convention note ([ff9de1b](https://github.com/szTheory/rindle/commit/ff9de1b4f93f5b3786167eca7fd1f3d7ee30e193))
* **18-04:** add @doc/[@spec](https://github.com/spec) to Profile macro and HTML helper, narrow worker [@specs](https://github.com/specs) ([5ae771a](https://github.com/szTheory/rindle/commit/5ae771ad61e3a6976520db4660938128589a513f))
* **18-05:** ratchet .doctor.exs to D-07 target; close remaining doc gaps ([d203f99](https://github.com/szTheory/rindle/commit/d203f997d7ce5f33767bc0896e4875dad7c11266))
* **19-02:** add attachment_for/2,3 and ready_variants_for/1 read helpers ([6a4d4c5](https://github.com/szTheory/rindle/commit/6a4d4c5c87569fd3adcf228478884021d9344f27))
* **19-02:** add bang variants attach!/4, detach!/3, upload!/3, url!/3, variant_url!/4 ([c034f99](https://github.com/szTheory/rindle/commit/c034f99e09e569f793f5c2f36f0f8f05080ed79c))
* **19-02:** add Rindle.Error exception module ([5b1e080](https://github.com/szTheory/rindle/commit/5b1e0809189c337c5a07acf88e266da02c007845))
* **21-01:** add HexDocs reachability probe ([44b8aa2](https://github.com/szTheory/rindle/commit/44b8aa247797ec7d071a7c960eac98b41a0a2fde))
* **21-01:** lock HexDocs probe workflow contract ([f6008ea](https://github.com/szTheory/rindle/commit/f6008ea0b9a4dba5f09be95e883ddd4f81eb9d7c))
* **23-01:** implement Capability Vocabulary and Security Argv Hygiene ([6eb2bf6](https://github.com/szTheory/rindle/commit/6eb2bf6333da559f4dee0efdab9281053360f038))
* **23-02:** implement MuonTrap Subprocess Discipline and 4-Cap Enforcement ([9a80624](https://github.com/szTheory/rindle/commit/9a806245029e0e35cd9eff6daa3dc8d3cc390a1b))
* **23-04:** implement ffmpeg processor adapter ([7eafba4](https://github.com/szTheory/rindle/commit/7eafba48a248fe6e804e5da2703a7539733c35d0))
* **23-05:** implement FFprobe metadata extractor shim ([d45d099](https://github.com/szTheory/rindle/commit/d45d099f2ed1ac325e5c8b5af24f4edb35374927))
* **23-05:** implement Rindle.tmp/ scheduled orphan reaper ([e1af427](https://github.com/szTheory/rindle/commit/e1af427b7400639722a2425e06e134402dc4fe39))
* **23-av-foundations-03:** implement Boot Probe ([dbb7c62](https://github.com/szTheory/rindle/commit/dbb7c627d2432c761eff0e87ef39920a8e20fc94))
* **23-av-foundations-03:** implement rindle.doctor Mix Task ([73e4104](https://github.com/szTheory/rindle/commit/73e4104ee4c5081a5811a9082043b18afcb424a1))
* **24-01:** add AV metadata sanitizer ([c32e5b6](https://github.com/szTheory/rindle/commit/c32e5b645aa8b5439994900c29388a11eec3419f))
* **24-01:** add probe behaviour scaffold ([8a368a6](https://github.com/szTheory/rindle/commit/8a368a667a133c0f3ab30279d49f4b71e6bb82cb))
* **24-02:** add av domain migration ([e49852f](https://github.com/szTheory/rindle/commit/e49852ff9e2272b760f7dc6fa1af5609381be86a))
* **24-02:** enforce media asset av schema rules ([8448055](https://github.com/szTheory/rindle/commit/8448055422538ff236e46b9a9e710d15a70ccd19))
* **24-02:** extend media variant av schema ([a06d779](https://github.com/szTheory/rindle/commit/a06d7794e3163279162c4fcb5f6cb8196859bd64))
* **24-03:** extend asset FSM for AV transcoding lifecycle ([a42e444](https://github.com/szTheory/rindle/commit/a42e444f61c3df41fa1477bf14c326993168b4a0))
* **24-03:** extend variant FSM with cancelled terminal state ([7f7c313](https://github.com/szTheory/rindle/commit/7f7c31309335c7eb72529dda3a2c65be3b4e8944))
* **24-04:** add per-kind profile validator dispatch ([d2a415c](https://github.com/szTheory/rindle/commit/d2a415c2fca2f3275a763ccc752aeceaea711868))
* **24-05:** implement probe adapters ([783aeec](https://github.com/szTheory/rindle/commit/783aeecb609b7e3d755eb3efc855793f043e5e0a))
* **24-05:** probe assets during promotion ([698f1a1](https://github.com/szTheory/rindle/commit/698f1a1391fb1fd0c6ad97dc8780a25fa999fda1))
* **25-01:** add av processor boundary ([84f2dbe](https://github.com/szTheory/rindle/commit/84f2dbecac0ddee6e08db237e73e294490fec842))
* **25-01:** normalize av recipes in validator and digest path ([773c039](https://github.com/szTheory/rindle/commit/773c03985f23abec3e719c3c1cadbe19da2f97b7))
* **25-02:** harden variant worker execution ([3a477ca](https://github.com/szTheory/rindle/commit/3a477ca79c0ca04ec037aa6ca7bdefd18eb72c9d))
* **25-03:** implement preset-led mp4 transcode ([7554c05](https://github.com/szTheory/rindle/commit/7554c054b1ba3f7be5f85d244149b0dfddedb530))
* **25-04:** freeze waveform contract ([6f95723](https://github.com/szTheory/rindle/commit/6f95723b088d310f298fdec0a065d416666918f8))
* **25-04:** implement preset audio transcodes ([ff32c65](https://github.com/szTheory/rindle/commit/ff32c651c893925e8beaf2ec40f7586f861ce777))
* **25-05:** add dedicated AV temp sweeper ([eed280f](https://github.com/szTheory/rindle/commit/eed280f2607f104c0652414ea0fc75272052051c))
* **25-05:** harden AV runtime admission and output verification ([0f45fd5](https://github.com/szTheory/rindle/commit/0f45fd52e54f87627580c37cda0b039d0be4021a))
* **25-rindle-processor-av-06:** freeze AV telemetry and progress contract ([4d02ade](https://github.com/szTheory/rindle/commit/4d02ade90921e003ad835b6d7da7156299d8b314))
* **25-rindle-processor-av-06:** ship stock web preset and adopter proof ([76b8dcb](https://github.com/szTheory/rindle/commit/76b8dcb6f7c3908c70ebfe58117ad0ecb10e51ec))
* **26-01:** add streaming delivery surface ([7971323](https://github.com/szTheory/rindle/commit/7971323f26b97d92c4fe0df7d294d5c16f5a10ca))
* **26-01:** normalize delivery content disposition ([a01b0b5](https://github.com/szTheory/rindle/commit/a01b0b59b87d642e0cc26b455a7c5cb8071bc148))
* **26-02:** add local playback plug ([a712cb0](https://github.com/szTheory/rindle/commit/a712cb06d70f3646ba092d75080257875396d62f))
* **26-02:** add local playback url seam ([de9f79c](https://github.com/szTheory/rindle/commit/de9f79c6d5be01775aafadeb121e771fb6417f92))
* **26-03:** freeze delivery telemetry contract and docs ([fc6ffb5](https://github.com/szTheory/rindle/commit/fc6ffb53cecb3389b94c048b08e03ee7cbf99642))
* **27-01:** add AV HTML helpers ([8608bc9](https://github.com/szTheory/rindle/commit/8608bc97856cca0d2f9787ef8f4ba78637bdd1cf))
* **27-02:** add liveview subscription helpers ([09ed7b4](https://github.com/szTheory/rindle/commit/09ed7b47b355049f2817630b8cf08001f1ef209c))
* **27-02:** publish liveview worker events ([4d115bf](https://github.com/szTheory/rindle/commit/4d115bff800155fde9d796dac7af5210593d592f))
* **27-03:** add asset-scoped cancel facade ([86e13d9](https://github.com/szTheory/rindle/commit/86e13d9939c2405a25196472bff212abb5d327a1))
* **27-04:** lock av error vocabulary ([e8c8331](https://github.com/szTheory/rindle/commit/e8c83313e7f6ebb313332248277da623fff87bf3))
* **28-01:** lock AV onboarding docs surface ([0e44f6c](https://github.com/szTheory/rindle/commit/0e44f6c25a728108f820361509f4ad1fa6a4c7bd))
* **28-02:** add AV hygiene ship gate ([7a1cb0c](https://github.com/szTheory/rindle/commit/7a1cb0cbbf45db1a4536bfddc0c125c002e34fad))
* **28-02:** gate AV runtime with public doctor task ([05e4402](https://github.com/szTheory/rindle/commit/05e4402d1ff0f8ee19ec47e5fd1499e747413508))
* **28-03:** align stock preset contract with adopter AV story ([3224a4e](https://github.com/szTheory/rindle/commit/3224a4e4e6de0f00640966c3a35ff359b4b5f5d6))
* **28-03:** prove smartphone AV lifecycle in adopter lane ([5737ac3](https://github.com/szTheory/rindle/commit/5737ac37bb4b148106ecef752d6b9b5aeb89e1a2))
* **28-04:** document locked AV troubleshooting contract ([f8da574](https://github.com/szTheory/rindle/commit/f8da574a7e314b49b657be82d26383b60e5dce75))
* **28-04:** document telemetry allowlist contract ([fb88443](https://github.com/szTheory/rindle/commit/fb8844346db0635d5190230fa8e33870c7859034))
* **29-01:** make generated install proof mode-explicit ([5f1d3b6](https://github.com/szTheory/rindle/commit/5f1d3b6c8cd49730460d0c5eb562737e5b7c2fef))
* **29-02:** add generated app AV proof lane ([d41151c](https://github.com/szTheory/rindle/commit/d41151c2f15c1b7823ed77c5d721a29640cb65a4))
* **29-03:** wire package-consumer proof matrix ([6496fea](https://github.com/szTheory/rindle/commit/6496fea64850bbe0f8dfb5f7f14267a6c24cf424))
* **29-04:** teach package-consumer proof matrix in adopter docs ([2480f3f](https://github.com/szTheory/rindle/commit/2480f3f7814b6205e321822843d186870b16bae8))
* **33-01:** implement Rindle.Streaming.Capabilities (closed vocabulary) ([a02a628](https://github.com/szTheory/rindle/commit/a02a6281c0977154d659ff90e521ac9681febbb3))
* **33-01:** promote Rindle.Streaming.Provider to runtime behaviour ([a8769d4](https://github.com/szTheory/rindle/commit/a8769d47f4fba32992327c31aa3e77cc4074dc1e))
* **33-02:** add media_provider_assets migration + Wave 0 smoke test ([4ce124f](https://github.com/szTheory/rindle/commit/4ce124f44af99aecdd190bc0714129b6fd42d405))
* **33-02:** add MediaProviderAsset schema, changeset, Inspect redaction ([198d152](https://github.com/szTheory/rindle/commit/198d1520c86fb64de0ac6bb17d0d898759ad925d))
* **33-02:** add ProviderAssetFSM with D-13 allowlist + telemetry ([67a12d8](https://github.com/szTheory/rindle/commit/67a12d8fe52d9226f8c7321a654fa0a49269f805))
* **33-03:** add Profile DSL :streaming key with NimbleOptions schema (STREAM-05) ([fc2188b](https://github.com/szTheory/rindle/commit/fc2188b25d9a33e9c8b6fbadd4886d403654448e))
* **33-03:** replace streaming_url/3 body with D-19 dispatch tree (STREAM-06) ([39c01ac](https://github.com/szTheory/rindle/commit/39c01acd1297617faeb35b021dffde9295353f1d))
* **33-04:** add 5 streaming reason atom message clauses ([40ffa01](https://github.com/szTheory/rindle/commit/40ffa01a6b281725567b917ef2d67da4c98e301a))
* **33-04:** add Rindle.Capability.report/0 aggregator ([790c066](https://github.com/szTheory/rindle/commit/790c066c2c013235d0c09a98f92866927a8f95f4))
* **34-01:** implement Mux REST adapter, HTTP impl, and event normalizer ([e83ce07](https://github.com/szTheory/rindle/commit/e83ce07fce3a1a034a5f35bd8150f1c13aba66c0))
* **34-01:** wire optional Mux+JOSE deps and adapter scaffolding ([4bc4c3c](https://github.com/szTheory/rindle/commit/4bc4c3ccf8a4dcc1f12ad430ba6f196235605e22))
* **34-02:** add MuxIngestVariant Oban worker for server-push ingest ([d8a7896](https://github.com/szTheory/rindle/commit/d8a7896cb7c1adabecc8c2e523cf81ea95ea0bc4))
* **34-03:** MuxSyncCoordinator cron-driven fan-out enqueuer ([71e2a36](https://github.com/szTheory/rindle/commit/71e2a36d3df77071cb8283f8632afd7fcc58660d))
* **34-03:** MuxSyncProviderAsset per-row defensive sync ([f563e14](https://github.com/szTheory/rindle/commit/f563e148d3eb5efc2b2308603b5fd39f8c75c11d))
* **35-01:** add dispatch_kind/1 + provider-internal telemetry to Mux ([053ba4d](https://github.com/szTheory/rindle/commit/053ba4d5a341a6377b70f4fbe6b938e3980c0a0a))
* **35-01:** implement Rindle.Delivery.WebhookBodyReader ([b729a6e](https://github.com/szTheory/rindle/commit/b729a6eb171ba1f75c8caa98143142a601d04631))
* **35-01:** implement Rindle.Delivery.WebhookPlug ([85a1c8d](https://github.com/szTheory/rindle/commit/85a1c8da8253fa79a698d93de86c7d40b7a3ed98))
* **35-02:** add typed branch for video.upload.asset_created in Event.normalize/1 ([78889bd](https://github.com/szTheory/rindle/commit/78889bdaa0de644e8887875bec5cba891612fdac))
* **35-02:** implement IngestProviderWebhook worker (GREEN) ([a79ee7d](https://github.com/szTheory/rindle/commit/a79ee7de13edd770b48873f9042a4cd3b0a8518f))
* **35-03:** add new Mux webhook fixtures + replace placeholder asset IDs ([9cc374e](https://github.com/szTheory/rindle/commit/9cc374e7f16e9f2d028ae0836658f3a60e322d38))
* **35-03:** implement Rindle.Test.MuxWebhookFixtures.sign_header/3 ([a564596](https://github.com/szTheory/rindle/commit/a5645967df3ae023674aac2e5cf6ec75b4cb7f2f))
* **35-04:** add --provider-stuck flag + format_provider_findings/1 (MUX-14) ([80f813c](https://github.com/szTheory/rindle/commit/80f813c45103f6e3a2dcf08c5ed90e4c078e9ba3))
* **35-04:** add provider_assets report + :provider_stuck filter (MUX-14) ([717a89c](https://github.com/szTheory/rindle/commit/717a89cf061e8a4861ff507b200958e4ad7efbb7))
* **36-01:** append four streaming checks + plumb --streaming flag ([d114579](https://github.com/szTheory/rindle/commit/d114579b6ae56fa46b1a2fc37fa487a3223550d6))
* **36-01:** ship Rindle.Profile.Presets.MuxWeb preset ([7f13bc9](https://github.com/szTheory/rindle/commit/7f13bc9f13f5d0196ac8e198fe9f807aa616ac1e))
* **36-03:** add mux profile fixtures, cleanup script, install_smoke arg ([b74ed96](https://github.com/szTheory/rindle/commit/b74ed96aa1a9f94a644f9da64d660451b1cfaf91))
* **36-03:** extend install-smoke harness with :mux profile mode ([29b4ba4](https://github.com/szTheory/rindle/commit/29b4ba4b3d886c03964b7037ce82f79f23749ed4))
* ship v1.5 adopter hardening ([1cfb960](https://github.com/szTheory/rindle/commit/1cfb960793edab5cdd8a62c50cd17370347737c3))


### Bug Fixes

* **17-02:** define public exdoc module tiers ([ec43d39](https://github.com/szTheory/rindle/commit/ec43d395d10370750a3e06973c288fd6d768a7ce))
* **17-02:** hide internal helper modules from docs ([eaee896](https://github.com/szTheory/rindle/commit/eaee89601b03f430d6257f02e2f9b372cd2754f7))
* **17-04:** hide logging shim and rewrite facade-first onboarding ([1c6e9fa](https://github.com/szTheory/rindle/commit/1c6e9fabbc6a191df5748285b428c8acc4dde4c2))
* **17-05:** hide internal ops modules ([3c7254c](https://github.com/szTheory/rindle/commit/3c7254cca84ae32a55be1f00201439e3f04636b9))
* **17-05:** hide internal pipeline workers ([2358d67](https://github.com/szTheory/rindle/commit/2358d67b1887acd90c375b2037a90e12f07dc747))
* **22-01:** correct liveview upload protocol defects ([f2ad2dc](https://github.com/szTheory/rindle/commit/f2ad2dcbf648ce9b31f9f23beb6e1d5c0328c22b))
* **22:** close review and verification follow-ups ([4f1e84b](https://github.com/szTheory/rindle/commit/4f1e84bdce8485f51b8759a419fb835601785887))
* **25-05:** warn on unsupported runtimes at boot ([b3c25c7](https://github.com/szTheory/rindle/commit/b3c25c70ac5135a49702f85c932809a16f89616f))
* **27-03:** complete asset cancellation flow ([dd1efcc](https://github.com/szTheory/rindle/commit/dd1efccaa079e693497ac29750b37cece66ed436))
* **27-04:** normalize AV runtime seam reasons ([b99388d](https://github.com/szTheory/rindle/commit/b99388d44361a37439b7725398922bec862666fa))
* **29-01:** keep install smoke wrappers mode-specific ([89259a8](https://github.com/szTheory/rindle/commit/89259a88f2cbe85953bdcbe8384d83ec9a731eee))
* **29-04:** align release docs parity and docs build surface ([2dc03c6](https://github.com/szTheory/rindle/commit/2dc03c666cd1b9e635181b2695682dcb4ff6ecd6))
* **33-01:** align v1.4 reservation tripwire with promoted behaviour (D-05) ([dc0f722](https://github.com/szTheory/rindle/commit/dc0f722669278ebebe328c64c2c561f7adbda8ee))
* **33:** CR-01 authorize Branch 5 of streaming_url before provider call ([d16cd02](https://github.com/szTheory/rindle/commit/d16cd026f72587fcf346a809f6c5a3cf9cc24a0f))
* **33:** WR-01 add defensive catch-all to dispatch_provider_signed_url ([a344614](https://github.com/szTheory/rindle/commit/a3446146c0b85549372d0ace42b4ef49bed91eeb))
* **33:** WR-02 drop bare nil from NimbleOptions {:or, [..., nil]} schemas ([730b668](https://github.com/szTheory/rindle/commit/730b668e2b410297a7cbad800167f60d5d1e1e75))
* **33:** WR-03 guard map-shaped do_progressive_streaming_url against missing storage_key ([3a7609b](https://github.com/szTheory/rindle/commit/3a7609be9ee72b55fb81943d404cabdd9498815d))
* **33:** WR-04 cross-check row playback_policy/ingest_mode against streaming_config ([0d35cff](https://github.com/szTheory/rindle/commit/0d35cff8651ff24992e84c14d947a073fe724c66))
* **34-04:** regen dialyzer PLT with :mux/:jose; clean Phase 34 surface ([41fae3b](https://github.com/szTheory/rindle/commit/41fae3bc0849acbb2e8b25af96f329c9c3e16134))
* **34-fix:** BL-01 compensate orphan Mux asset on post-create drift ([1f29ec3](https://github.com/szTheory/rindle/commit/1f29ec35929de7f0d3751327ee8638e802b87a84))
* **34-fix:** BL-02 cancel re-ingest for :errored / :deleted rows ([abd07f5](https://github.com/szTheory/rindle/commit/abd07f581c797239aaf6ab2c836d2db81bb691c9))
* **34-fix:** BL-03 nil-safe Event.extract_playback_ids/1 ([791e4c4](https://github.com/szTheory/rindle/commit/791e4c4db12a2196423952362a11762362541240))
* **34-fix:** BL-04 align provider_state typespec to String.t() ([b18fc10](https://github.com/szTheory/rindle/commit/b18fc10f11e114fc6020fa8b1806cf802fb70f78))
* **36:** CR-01 tag soak Mux assets with passthrough so cleanup script can filter them ([8b291c1](https://github.com/szTheory/rindle/commit/8b291c165f9c6e228538e4131b71ed8ecc690836))
* **36:** CR-02 record provider_asset_id before streaming-URL assertions ([744755e](https://github.com/szTheory/rindle/commit/744755e00822b760406725d2a5946b6b3cc273af))
* **36:** CR-03 decouple shared_env from Mux fixtures for non-mux profiles ([12dfd0f](https://github.com/szTheory/rindle/commit/12dfd0f52005ea8b6dd10544fe6d142a20ab2aa5))
* **36:** WR-01 pin streaming guide to ~&gt; 0.1 until 0.2.0 ships ([a1e5e94](https://github.com/szTheory/rindle/commit/a1e5e948c097d16f3ec453b757899bb1a696dbb8))
* **36:** WR-02 add guides/upgrading.md to mix.exs :extras list ([c6820fb](https://github.com/szTheory/rindle/commit/c6820fbaf71595c5647d642f3b69aa61a258745d))
* **36:** WR-03 require rindle_provider queue when streaming profile present ([b8563e8](https://github.com/szTheory/rindle/commit/b8563e867182a692bdeda38b2c790e2bf2824b8e))
* **36:** WR-04 add rindle_provider to mux lane via single oban_queues_for helper ([0304532](https://github.com/szTheory/rindle/commit/030453261b5e2f969e50ec321e4e56019a9017e6))
* **36:** WR-05 use documented Mox setup-callback form in generated mux test ([ca74c32](https://github.com/szTheory/rindle/commit/ca74c3202a748b00272e561313e8f8598fb2dea5))
* **36:** WR-06 mix rindle.doctor fails loudly on unknown CLI flags ([4368236](https://github.com/szTheory/rindle/commit/43682367f9220eca4f5d2787c5c7eaedd41aeaa0))
* **36:** WR-08 use .md extension for cross-guide link in streaming_providers.md ([a48e18e](https://github.com/szTheory/rindle/commit/a48e18e29b0d893de170766d5f4f5099b131fd58))
* **36:** WR-09 remove unused _app_name parameter from mux_config_block ([9c74f24](https://github.com/szTheory/rindle/commit/9c74f2446e75623714be472613b696e36db88491))
* **36:** WR-10 surface exception class in verify_signing_key_pem rescue ([c901124](https://github.com/szTheory/rindle/commit/c9011242d01b23662229395e203a08d9c2f73fd1))
* **release:** allow publish after skipped recovery gate ([d5c21ad](https://github.com/szTheory/rindle/commit/d5c21ad7dcee2a2052f4a032461f7442ff74a728))
* **release:** install deps for current tooling preflight ([92d581e](https://github.com/szTheory/rindle/commit/92d581e023c3b63784bd64f61b6e5df88229b966))
* **release:** make recovery publish idempotent ([f528bb1](https://github.com/szTheory/rindle/commit/f528bb13d723c74308453d5da8b6ff4fa6d9d119))
* **release:** read frozen version without compiling deps ([e9a8aa3](https://github.com/szTheory/rindle/commit/e9a8aa3e9b3882a2c3e6cc32b58c8c960a5c8cad))
* **release:** run preflight checks from current tooling ([0c12ad3](https://github.com/szTheory/rindle/commit/0c12ad31017ed7832bf42a276cef4d71668d3304))
* **release:** run public smoke in test env ([6dd0d54](https://github.com/szTheory/rindle/commit/6dd0d54081c89b68c630d9642a40453d310008c6))
* **release:** run recovery publish with current tooling ([71a0f99](https://github.com/szTheory/rindle/commit/71a0f99778cca2cdc09958b2a64a336eb8a62db3))
* **release:** support component-tag recovery refs ([65728e5](https://github.com/szTheory/rindle/commit/65728e520868878a32290bdb716332d44509cd8c))

## [Unreleased]

### Added

- Public adopter onboarding for streaming providers — `Rindle.Profile.Presets.MuxWeb`
  preset (signed-HLS twin of `Rindle.Profile.Presets.Web`),
  `mix rindle.doctor --streaming` smoke check (credentials / signing-key
  parse / webhook-secrets / 5s `api.mux.com` ping), the
  [`guides/streaming_providers.md`](guides/streaming_providers.md) end-to-end
  guide (deps, signing key, profile config, webhook plug, cron, cloudflared
  tunnel, secret rotation, doctor recipe, stuck-asset runbook, JOSE perf
  note), and the generated-app `mux-enabled` package-consumer CI lane
  (cassette default + label-gated `mux-soak` lane against real Mux).
- `@doc` annotations on every public `@callback` across `Rindle.Storage`,
  `Rindle.Authorizer`, `Rindle.Analyzer`, `Rindle.Scanner`, and
  `Rindle.Processor`, surfacing the contract for each behaviour callback in
  ExDoc (API-06).
- Behaviour-level named result types on `Rindle.Storage`
  (`put_result`, `delete_result`, `url_result`, `presign_result`,
  `multipart_init_result`, `multipart_complete_result`, `head_result`),
  replacing opaque `map()` returns in callback specs (API-07).
- Module-level named-type aliases on `Rindle.Upload.Broker`
  (`session_only_result`, `initiate_multipart_result`, `presigned_payload`,
  `sign_url_result`, `sign_part_result`, `verify_result`) for adopters using
  Dialyzer (API-07).
- `@spec` annotations on every public function of `Rindle.Upload.Broker`
  (the largest pre-existing spec gap, now closed).
- `@doc` and `@spec` on `Rindle.Profile.__using__/1` macro and
  `Rindle.HTML.picture_tag/3` helper.
- `@doc` on every macro-generated profile function
  (`storage_adapter/0`, `variants/0`, `upload_policy/0`, `validate_upload/1`,
  `delivery_policy/0`, `recipe_digest/1`) and on every `Rindle.Domain.*`
  schema `changeset/2` so the doctor 100% module-doc gate is honored across
  the public surface.
- `Rindle.Processor.Image` promoted to documented public adapter, symmetric
  with `Rindle.Storage.S3` and `Rindle.Storage.Local`. The `variant_spec`
  keys (`:width`, `:height`, `:mode`, `:format`, `:quality`) and supported
  modes (`:fit`, `:crop`, `:fill`) are now documented in the adapter's
  `@moduledoc`.
- `mix doctor` (`~> 0.22.0`) added as a dev/test-only static analyzer, with
  `MIX_ENV=test mix doctor --full --raise` enforced in the CI quality job
  on both Elixir 1.15 and 1.17 lanes (API-08).
- ExDoc grouping: "Storage Adapters" renamed to "Storage and Processor
  Adapters" to host the bundled adapters across both behaviour families.
- Doctor coverage thresholds ratcheted to the D-07 target
  (100% module-doc / 100% overall-doc / 100% moduledoc / 95% module-spec /
  95% overall-spec). Future doc/spec regressions on the public surface
  fail `mix doctor --raise` in CI.
- Convenience helpers: `Rindle.attachment_for/2,3` — fetch the most-recent
  `MediaAttachment` for an `(owner, slot)` pair without writing a raw Ecto
  query. Auto-preloads `:asset` by default; pass `preload: [asset: :variants]`
  (or `preload: []`) to extend or override (API-09).
- Convenience helpers: `Rindle.ready_variants_for/1` — fetch all
  `MediaVariant` rows in the `"ready"` state for an asset (by struct or id),
  ordered by name. Returns an empty list when none are ready (API-10).
- Convenience helpers: `Rindle.attach!/4`, `Rindle.detach!/3`,
  `Rindle.upload!/3`, `Rindle.url!/3`, `Rindle.variant_url!/4` — bang
  variants of the corresponding non-bang functions. Raise
  `Ecto.InvalidChangesetError` for changeset failures, re-raise the
  original exception for storage adapter failures, and raise `Rindle.Error`
  for all other failures (API-11).
- `Rindle.Error` — new exception module with `:action` and `:reason` fields.
  Raised by bang variants for non-changeset, non-adapter-exception failures.
  Provides a structured `message/1` that formats the action and reason into
  a readable string (API-11).

### Fixed

- Mux server-push ingest now wires into the live AV runtime: after the
  configured streaming source variant reaches `ready`,
  `Rindle.Workers.ProcessVariant` enqueues
  `Rindle.Workers.MuxIngestVariant` with the expected storage-key and
  recipe-digest guards, making the Phase 34 idempotent ingest path reachable
  end to end.
- `Rindle.HTML.video_tag/3` and `audio_tag/3` now pass asset/variant structs
  into `Rindle.Delivery.streaming_url/3` on streaming-enabled profiles, and
  provider dispatch now accepts variant-like maps keyed by `asset_id`, so
  Phoenix playback resolves provider-backed HLS URLs through the shipped
  consumer surface instead of tripping the binary-key guard.

### Changed

- Public `@spec`s on `Rindle` facade functions (`initiate_upload/2`,
  `initiate_multipart_upload/2`, `sign_multipart_part/3`,
  `complete_multipart_upload/3`, `verify_completion/2`, `verify_upload/2`,
  `attach/4`, `upload/3`) now use `MediaAsset.t()`, `MediaUploadSession.t()`,
  `MediaAttachment.t()`, and named `Broker.*_result()` types instead of
  `{:ok, map()}` / `{:ok, struct()}`.
- `Rindle.log_variant_processing_failure/3` (the hidden facade shim) now
  emits a compile-time deprecation warning via `@deprecated`. Use
  `Rindle.Internal.VariantFailureLogger.log/3` directly.

### Notes

- Error branches across all tightened specs retain `{:error, term()}` to
  preserve the 0.1.x semver posture (narrowing error terms is a Dialyzer-
  breaking change for adopters pattern-matching on them).

## [0.1.4](https://github.com/szTheory/rindle/compare/rindle-v0.1.3...rindle-v0.1.4) (2026-04-29)


### Bug Fixes

* **test:** supervise ex_marcel table wrapper ([876afd7](https://github.com/szTheory/rindle/commit/876afd79223fd62b028e281f386680d6b5aedcdb))

## [0.1.3](https://github.com/szTheory/rindle/compare/rindle-v0.1.2...rindle-v0.1.3) (2026-04-29)


### Bug Fixes

* **ci:** fall back when rg is unavailable ([f0ad8b4](https://github.com/szTheory/rindle/commit/f0ad8b4a2cb9816e1265a8e7788715b223a58bdd))

## [0.1.2](https://github.com/szTheory/rindle/compare/rindle-v0.1.1...rindle-v0.1.2) (2026-04-29)


### Bug Fixes

* **ci:** write full smoke fixture binary ([3584039](https://github.com/szTheory/rindle/commit/358403901ee0113562c600d5ce2071ee563ef975))

## [0.1.1](https://github.com/szTheory/rindle/compare/rindle-v0.1.0...rindle-v0.1.1) (2026-04-29)


### Bug Fixes

* **ci:** install phx.new for release preflight ([17b3385](https://github.com/szTheory/rindle/commit/17b3385b22d614e079b18c2f825bd411c5d69e49))
* **release:** allow indented version parsing ([a7efefd](https://github.com/szTheory/rindle/commit/a7efefd475ffaf9b488838f6013ebb871a9f2880))
* **release:** read version without deps ([4cae7f5](https://github.com/szTheory/rindle/commit/4cae7f579e5c695c1a678c536edf1f278b19adc5))

## 0.1.0 (2026-04-29)


### Features

* **01-01:** add media domain schemas and changesets ([7431c41](https://github.com/szTheory/rindle/commit/7431c41dc6beca2e19910a784e26021f96a52b03))
* **01-01:** add remaining phase 1 media migrations ([d5fd5be](https://github.com/szTheory/rindle/commit/d5fd5be913b1331e91779b1bd223737d1c7089bf))
* **01-02:** define core behaviour contracts ([1de5088](https://github.com/szTheory/rindle/commit/1de5088d627214b2fd9187c8b79657dc70a02958))
* **01-02:** wire behaviour mocks into test setup ([b681754](https://github.com/szTheory/rindle/commit/b6817545f4e1d8f207d3cd6fa4d9d2000870d5ec))
* **01-03:** add deterministic recipe digest primitives ([d7c304d](https://github.com/szTheory/rindle/commit/d7c304d2992bdf2389ebfef0e58605b6e4d7c568))
* **01-03:** build profile DSL with strict validation ([fb64462](https://github.com/szTheory/rindle/commit/fb64462e343d79bebd19011f0f958d9bd8f48ef9))
* **01-04:** add explicit lifecycle transition allowlists ([1f69a8d](https://github.com/szTheory/rindle/commit/1f69a8dcfdf5b4dfd299eb0b3ea53838d2fb0d13))
* **01-04:** add stale policy primitives and lifecycle matrix tests ([5468215](https://github.com/szTheory/rindle/commit/54682153839980b369748674c6cac00a67627475))
* **01-04:** add structured lifecycle transition logging ([43841fc](https://github.com/szTheory/rindle/commit/43841fca4a330fe973f457788caf68ea3080fe22))
* **01-05:** add byte-based MIME and extension quarantine checks ([82959f1](https://github.com/szTheory/rindle/commit/82959f1296a1e35b4373dcc69f15e2da8c15e051))
* **01-05:** enforce upload limits and safe naming primitives ([9fa16f1](https://github.com/szTheory/rindle/commit/9fa16f11fc74b9788c3aebd8cdd03a8aa8360e4d))
* **01-06:** add profile-scoped local and s3 storage adapters ([5bdd798](https://github.com/szTheory/rindle/commit/5bdd7986545a94e32873762a535940cc1359cd19))
* **02-01:** add direct upload broker with storage head/download ([e35583a](https://github.com/szTheory/rindle/commit/e35583a74035547225c1a268f685b881340533e7))
* **02-02:** add proxied upload with MIME validation test ([1aeeb50](https://github.com/szTheory/rindle/commit/1aeeb5067a9de2e2b02070b76b875fcd6e9f9a91))
* **02-03:** add Image processor adapter via Vix/libvips ([b0c8414](https://github.com/szTheory/rindle/commit/b0c8414e6e7abff223465317e4cdb9c0f115fcb2))
* **02-04:** add PromoteAsset and ProcessVariant Oban workers ([f2462e5](https://github.com/szTheory/rindle/commit/f2462e5b16137dfdec3c7ebf92ecef497418c5e2))
* **02-05:** add atomic attach/detach with idempotent purge ([c25e4ef](https://github.com/szTheory/rindle/commit/c25e4ef892fce4f280b8c1e798493dc36b6cd987))
* **02-06:** add LiveView direct upload helpers ([653cc1d](https://github.com/szTheory/rindle/commit/653cc1ddd56808fbdf002ce9049e7d3a758de713))
* **03-01:** add delivery policy contract ([9c0986d](https://github.com/szTheory/rindle/commit/9c0986dc184aa9ea7b165f0ddb2640933b1d90bc))
* **03-02:** route delivery through policy layer ([b0e450a](https://github.com/szTheory/rindle/commit/b0e450a9d339c9d59a37c0f252036484c902392c))
* **03-03:** add responsive picture helper ([92e7c83](https://github.com/szTheory/rindle/commit/92e7c833ae098c748f2b0a69bb8c46d6b0b04c65))
* **04-01:** implement upload-session cleanup operations and CLI wrappers ([f92c44f](https://github.com/szTheory/rindle/commit/f92c44f50853486f9dc6ffe090347a539a80ddd0))
* **04-01:** lock upload maintenance behavior with regression test suite ([5f94ab6](https://github.com/szTheory/rindle/commit/5f94ab6624790f57b57bafa5776cdf81ce23a7b1))
* **04-02:** implement variant maintenance and storage reconciliation ([98be7f7](https://github.com/szTheory/rindle/commit/98be7f71e7cb159818fbff5459433879d2662ac2))
* **04-03:** add cron-capable maintenance workers with delegation tests ([8dc4c0e](https://github.com/szTheory/rindle/commit/8dc4c0e1848bbadd83d2b7eab1b7c85c81a4baab))
* **04-03:** implement metadata backfill service and CLI ([fde754d](https://github.com/szTheory/rindle/commit/fde754d29004a67fae6701e1cdbd73369acc5923))
* **04:** split fsm_blocked from errors in verify_storage and lock Oban uniqueness contract ([b93e632](https://github.com/szTheory/rindle/commit/b93e632d28c3fd495848d38542161f9abe6fb9bf))
* **05-01:** emit cleanup run telemetry from worker layer ([9a312d6](https://github.com/szTheory/rindle/commit/9a312d65a4357da1e6255d62e803c7c350cf44c3))
* **05-01:** emit state_change telemetry from AssetFSM and VariantFSM ([746d1bc](https://github.com/szTheory/rindle/commit/746d1bca5374e3b152a50da2741a9788638845e3))
* **05-01:** emit upload start/stop and delivery signed telemetry ([40df389](https://github.com/szTheory/rindle/commit/40df389a5544ad71477fab2fd8c97915ac0f3e13))
* **05-03:** add excoveralls and 80% coverage gate ([093170a](https://github.com/szTheory/rindle/commit/093170ac28cf513d9432d5162e4962604f79a489))
* **05-03:** wire libvips and coverage into CI quality job ([5662230](https://github.com/szTheory/rindle/commit/56622304ccf7f6b348f173ecc30c5afaf49f1b2c))
* **05-05:** add explicit files: allowlist to mix.exs package and create LICENSE ([724b7eb](https://github.com/szTheory/rindle/commit/724b7ebcca7461561c72a8b9e1d446e236d1eb23))
* **06-01:** add runtime repo config seam ([d5abb75](https://github.com/szTheory/rindle/commit/d5abb756424dc1b205d127232f3580d89760a84d))
* **06-01:** move facade persistence onto configured repo ([c8c5fdf](https://github.com/szTheory/rindle/commit/c8c5fdffd848cb8f5dd2b885bbc099fd836b3e13))
* **06-02:** keep adopter lifecycle jobs on runtime repo ([051386b](https://github.com/szTheory/rindle/commit/051386b3ceada1ec4673facd4ca2110ca8be4958))
* **06-02:** move broker flows onto runtime repo seam ([8726d45](https://github.com/szTheory/rindle/commit/8726d45345c1cc8c5d9c028abb7133d5c983fcf3))
* **07-01:** add multipart broker and facade entrypoints ([269d5ce](https://github.com/szTheory/rindle/commit/269d5ce42064231fbae9c906d806e19f1c97e353))
* **07-01:** extend storage and session multipart contract ([117b9ed](https://github.com/szTheory/rindle/commit/117b9ede126157784836367d19457b7fc84b9b5d))
* **07-02:** add retry-safe multipart maintenance cleanup ([dbb3a8e](https://github.com/szTheory/rindle/commit/dbb3a8ef8a9a3d1c0406403b51872d0f82fefbeb))
* **07-02:** move upload maintenance to runtime repo seam ([97f043f](https://github.com/szTheory/rindle/commit/97f043f42db47dd5699324a51b03ed6f2cef103d))
* **07-03:** prove multipart adapter and broker flows ([18bd22e](https://github.com/szTheory/rindle/commit/18bd22ec4afec6e7b36ebb4b5b798f26281d8e20))
* **08-01:** centralize storage capability vocabulary ([b42a2a6](https://github.com/szTheory/rindle/commit/b42a2a62a0e55d33d132eebf3da4c961fdde9e5a))
* **08-01:** route capability gates through shared helpers ([c47ef54](https://github.com/szTheory/rindle/commit/c47ef54adc5f753dfdc93c2abed4b16c9deb2329))
* **08-03:** add opt-in cloudflare r2 contract lane ([c3652f7](https://github.com/szTheory/rindle/commit/c3652f75e3f0812de7a0b47041f0ddc00d15419a))
* **09-01:** add generated-app install smoke harness ([630af09](https://github.com/szTheory/rindle/commit/630af099ba689bfce6009242a4e6cb6516873d6f))
* **09-01:** add shared install smoke runner ([b54f37e](https://github.com/szTheory/rindle/commit/b54f37e55bcf05051d9d88085b34476f8e374a12))
* **09-02:** add package-consumer ci smoke lane ([ecb8806](https://github.com/szTheory/rindle/commit/ecb8806ce927783da90e5f330486faf81538dd78))
* **09-02:** reuse install smoke in release checks ([63bc680](https://github.com/szTheory/rindle/commit/63bc680dd3e6b24ea87eccb57393e5fdb8f4dbd6))
* **09-03:** enforce install docs parity ([15d4b68](https://github.com/szTheory/rindle/commit/15d4b68cf00c7e1fd06abced8501dd132757e1fa))
* **10-01:** add first publish release runbook ([0005e5b](https://github.com/szTheory/rindle/commit/0005e5b965b151c2aee9a421b8184eb7cf964af0))
* **10-02:** add release preflight metadata gate ([ba655b2](https://github.com/szTheory/rindle/commit/ba655b2828b630937e631cb06e8842d389728d2f))
* **11-02:** add version drift check script ([977c86b](https://github.com/szTheory/rindle/commit/977c86bf80066455c3349b2d84a73672883bd4c5))
* **11-protected-publish-automation-03:** add E2E dry-run publish to CI ([52abcf6](https://github.com/szTheory/rindle/commit/52abcf6d7281ea7d75d996cb860b4123a608f1af))
* **12-01:** support network install smoke mode ([87de2d3](https://github.com/szTheory/rindle/commit/87de2d3f25975dad4cbb8955388743f04df38b7a))
* **12-01:** verify published artifact in release workflow ([03fa6e5](https://github.com/szTheory/rindle/commit/03fa6e51acc8d7702c558dc4c31fb618816f7cfb))
* **15-02:** define release-candidate proof contract ([1c3a9cf](https://github.com/szTheory/rindle/commit/1c3a9cf9169392350511f90347d9ab508da3d26f))
* **phase-10:** automate release verification gates ([eba7ffa](https://github.com/szTheory/rindle/commit/eba7ffa503bb458019835aeb15b23930e50b7481))
* **release:** automate mainline hex publish ([2e81810](https://github.com/szTheory/rindle/commit/2e81810535e3d8b1dee6d4cee55ec8018849e847))


### Bug Fixes

* **01-02:** avoid duplicate mock module loading ([3d5be2c](https://github.com/szTheory/rindle/commit/3d5be2c41f62eacf0da800214158c53811b10a00))
* **04-01:** CR-01 attempt storage delete before removing DB row ([d21d780](https://github.com/szTheory/rindle/commit/d21d780aec870d68ad11b0737ad798f6bb852715))
* **04-02:** CR-02 default rindle.cleanup_orphans to dry-run ([da0abef](https://github.com/szTheory/rindle/commit/da0abef79c5cb3df2543c427abd25351f076086e))
* **04-02:** use stub for order-independent mock in summary counts test ([4c88f04](https://github.com/szTheory/rindle/commit/4c88f048f9c2d8002f7085b5fb31d8f83675a3d9))
* **04-03:** CR-03 enforce ProcessVariant uniqueness on regenerate runs ([53ef3cb](https://github.com/szTheory/rindle/commit/53ef3cb867f165f75309946183fc8b6bc9848ba8))
* **04-04:** CR-04 exit non-zero from regenerate_variants on insert errors ([1de8edf](https://github.com/szTheory/rindle/commit/1de8edf67bb714d31ea326f4d78c5876347d58aa))
* **04-05:** CR-05 exit non-zero from verify_storage on storage errors ([fe1a1b2](https://github.com/szTheory/rindle/commit/fe1a1b274487a0e76693fbe88fd4caf1bb9ff9fe))
* **04-06:** CR-06 use to_existing_atom + behaviour check for CLI modules ([0878a21](https://github.com/szTheory/rindle/commit/0878a21ca82397a6bb3ba3f66bb3dd41474afa92))
* **04-07:** CR-07 gate maintenance state changes through the FSMs ([d0e66e0](https://github.com/szTheory/rindle/commit/d0e66e092b67872c9154fd986b6741bc32013f9c))
* **04-08:** CR-08 drop expires_at predicate from cleanup query ([56efe02](https://github.com/szTheory/rindle/commit/56efe029f71d7b7b9781fe358ccd2a02de3863a6))
* **04-09:** WR-01 wrap per-asset backfill in try/rescue/after ([0758e6b](https://github.com/szTheory/rindle/commit/0758e6bc605bed9e81c3ad2f39d2ec1d26073754))
* **04-10:** WR-02 add defensive {:error, _} clause to backfill_metadata task ([4472aa6](https://github.com/szTheory/rindle/commit/4472aa6f065db2817b0ad6b0298decace80bdd5b))
* **04-11:** WR-03 surface missing storage adapter; WR-06 log failed event ([25205c0](https://github.com/szTheory/rindle/commit/25205c0757ae72365e0b1da19a799656ec3f7385))
* **04-12:** WR-05 propagate query errors from MetadataBackfill ([0d8598f](https://github.com/szTheory/rindle/commit/0d8598f774f3733868a039d9ce30be6c69dc28b1))
* **04-13:** WR-07 use [@requirements](https://github.com/requirements) for app.start consistently ([45dd4c4](https://github.com/szTheory/rindle/commit/45dd4c41504ef80c080c6010c833fe9c61627986))
* **04-14:** WR-08 reject unknown filter keys in variant maintenance API ([f7951bb](https://github.com/szTheory/rindle/commit/f7951bb1749a24ec176a04e93d0c493aedc2bdf2))
* **04-15:** WR-09 stop raising on adapter resolution; preserve verify walk ([b8aa785](https://github.com/szTheory/rindle/commit/b8aa785a773fc309a20158560fc0d99c83afa999))
* **04:** register --dry-run flag on cleanup_orphans CLI ([2b09dbc](https://github.com/szTheory/rindle/commit/2b09dbca92dcec76666e96103752dc64523f49bd))
* **05-04:** align S3 adapter return shapes with Local; add hackney test dep ([1830821](https://github.com/szTheory/rindle/commit/18308219e660f7b49f730a07f3f5771db76d672c))
* **07-03:** normalize MinIO head 404 responses ([1099b31](https://github.com/szTheory/rindle/commit/1099b31fd6730c644c3cf983675f481991325d4f))
* **09:** ship guides and reuse inspected artifact ([1e6fff1](https://github.com/szTheory/rindle/commit/1e6fff1aa529b4f4f76061500841ef9ea62303e3))
* **10-02:** wire shared release preflight ([e98cbfd](https://github.com/szTheory/rindle/commit/e98cbfd5e35c90c95df127337331f62722e3b272))
* **ci:** give contract lane a postgres service ([b287d9f](https://github.com/szTheory/rindle/commit/b287d9f28bc57aad3cf6c959452833d2a9137f34))
* **ci:** restore cross-version test compatibility ([8182565](https://github.com/szTheory/rindle/commit/818256593aee1f055f335ddbd1922eed98a0e019))
* **ci:** satisfy strict quality checks ([dd39ec4](https://github.com/szTheory/rindle/commit/dd39ec489e8163e8dd65f31f84b0a7b7e2223e8c))
* **phase-07:** close multipart abandonment gap ([5ee51b2](https://github.com/szTheory/rindle/commit/5ee51b235cd11213045c2b6f43b362a23112597c))
* **phase-07:** harden multipart initiation and cleanup ([ec11435](https://github.com/szTheory/rindle/commit/ec114358078eecede92235a00f51c5022e7fc22a))
* **release:** harden preflight artifact unpack path ([2ac71dc](https://github.com/szTheory/rindle/commit/2ac71dc885ccd273fb1939d37f3f785a197d7b03))
* **release:** harden publish preflight ([c2d1149](https://github.com/szTheory/rindle/commit/c2d1149ebd7539528a4070ed283107bca5c04df5))


### Miscellaneous Chores

* release 0.1.0 ([64a4104](https://github.com/szTheory/rindle/commit/64a41043fafd353da0d0a9531d0d1200c3c288bb))

## 0.1.0

- First public Hex.pm release of Rindle.
- Ships the maintainer release runbook and packaged install-smoke contract.
- Publishes the current library metadata, guides, and release preflight checks.
