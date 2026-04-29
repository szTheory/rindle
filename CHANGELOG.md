# Changelog

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
