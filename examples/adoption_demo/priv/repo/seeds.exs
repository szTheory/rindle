# Script for populating the Cohort adoption demo database.
#
#     mix run priv/repo/seeds.exs
#
alias AdoptionDemo.{Accounts, Cohort, Media, SeedSupport}

:ok = SeedSupport.ensure_inets()

for {email, name, role} <- [
      {"maya@cohort.test", "Maya Rivera", "instructor"},
      {"alex@cohort.test", "Alex Kim", "student"},
      {"jordan@cohort.test", "Jordan Lee", "student"},
      {"ops@cohort.test", "Ops Operator", "operator"}
    ] do
  Accounts.seed_member!(%{email: email, name: name, role: role})
end

maya = Accounts.get_member_by_email!("maya@cohort.test")
alex = Accounts.get_member_by_email!("alex@cohort.test")
jordan = Accounts.get_member_by_email!("jordan@cohort.test")

course =
  Cohort.seed_course!(%{
    title: "Intro to Elixir",
    slug: "intro-elixir",
    instructor_id: maya.id
  })

lesson_intro =
  Cohort.seed_lesson!(%{
    title: "Pattern matching basics",
    position: 1,
    course_id: course.id
  })

lesson_shared =
  Cohort.seed_lesson!(%{
    title: "Processes and messages",
    position: 2,
    course_id: course.id
  })

avatar_path = SeedSupport.fixture_path("avatar.png")

if File.exists?(avatar_path) do
  unless Media.attachment_for(maya, :avatar) do
    maya_avatar = SeedSupport.upload_image!("maya-avatar.png", File.read!(avatar_path))
    Media.attach!(maya, maya_avatar.id, :avatar)
  end

  unless Media.attachment_for(alex, :avatar) do
    alex_avatar = SeedSupport.upload_image!("alex-avatar.png", File.read!(avatar_path))
    Media.attach!(alex, alex_avatar.id, :avatar)
    Media.attach!(jordan, alex_avatar.id, :avatar)
    IO.puts("Seeded shared avatar asset for Alex and Jordan")
  end
end

video_path = SeedSupport.fixture_path("demo-video.webm")

if File.exists?(video_path) and is_nil(Media.attachment_for(lesson_intro, :video)) do
  lesson_video = SeedSupport.upload_video!("intro-lesson.webm", File.read!(video_path))
  Media.attach!(lesson_intro, lesson_video.id, :video)
  Media.attach!(lesson_shared, lesson_video.id, :video)
  IO.puts("Seeded shared lesson video on two lessons")
end

post =
  Cohort.seed_post!(%{
    title: "Study group this week",
    body: "Who is joining the Thursday review session?",
    member_id: alex.id
  })

if File.exists?(avatar_path) and is_nil(Media.attachment_for(post, :image)) do
  post_image = SeedSupport.upload_image!("study-group.png", File.read!(avatar_path))
  Media.attach!(post, post_image.id, :image)
  IO.puts("Seeded community post image")
end

IO.puts("""
Cohort demo seeded:
  - Maya (instructor) + Alex (student) avatars
  - Shared lesson video across two lessons (erasure collateral)
  - Alex community post with image
  - Jordan (student) without avatar — fresh upload target
  - Ops operator for batch erasure demos
""")

# --- Edge Cases Seeding ---
IO.puts("\nSeeding MediaAsset lifecycle states...")

alias Rindle.Domain.{MediaAsset, MediaVariant, MediaUploadSession}
alias AdoptionDemo.Repo

# Timestamps for naive_datetime fields
now_naive = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
# Timestamps for utc_datetime_usec fields
now_utc = DateTime.utc_now() |> DateTime.truncate(:microsecond)

asset_states = [
  "staged",
  "validating",
  "analyzing",
  "promoting",
  "available",
  "processing",
  "transcoding",
  "ready",
  "degraded",
  "quarantined",
  "deleted"
]

variant_states = [
  "planned",
  "queued",
  "processing",
  "ready",
  "stale",
  "missing",
  "failed",
  "cancelled",
  "purged"
]

upload_session_states = [
  "initialized",
  "signed",
  "resuming",
  "uploading",
  "uploaded",
  "verifying",
  "completed",
  "aborted",
  "expired",
  "failed"
]

seed_assets =
  for {state, idx} <- Enum.with_index(asset_states) do
    kind = if rem(idx, 2) == 0, do: "audio", else: "image"
    
    {profile, content_type} =
      if kind == "audio" do
        {"AdoptionDemo.AudioProfile", "audio/mpeg"}
      else
        {"AdoptionDemo.DocumentProfile", "application/pdf"}
      end
    
    # We prefix keys with seed- so they are easily recognizable, and append timestamp so subsequent runs don't violate constraints
    ts = System.system_time(:millisecond)
    
    Repo.insert!(%MediaAsset{
      state: state,
      storage_key: "seed/#{kind}/#{state}_#{ts}_#{idx}",
      profile: profile,
      kind: kind,
      content_type: content_type,
      filename: "asset_#{state}.ext",
      byte_size: 1024,
      inserted_at: now_naive,
      updated_at: now_naive
    })
  end

IO.puts("Seeding MediaVariant lifecycle states...")

for {state, idx} <- Enum.with_index(variant_states) do
  asset = Enum.at(seed_assets, rem(idx, length(seed_assets)))
  output_kind = if asset.kind == "audio", do: "audio", else: "image"
  ts = System.system_time(:millisecond)
  
  Repo.insert!(%MediaVariant{
    asset_id: asset.id,
    name: "variant_#{state}",
    state: state,
    recipe_digest: "digest_#{state}_#{ts}",
    storage_key: "seed/#{output_kind}/variant_#{state}_#{ts}_#{idx}",
    output_kind: output_kind,
    content_type: "application/octet-stream",
    byte_size: 512,
    inserted_at: now_naive,
    updated_at: now_naive
  })
end

IO.puts("Seeding MediaUploadSession lifecycle states...")

for {state, idx} <- Enum.with_index(upload_session_states) do
  asset = Enum.at(seed_assets, rem(idx, length(seed_assets)))
  ts = System.system_time(:millisecond)
  
  Repo.insert!(%MediaUploadSession{
    asset_id: asset.id,
    state: state,
    upload_key: "seed/upload_#{state}_#{ts}_#{idx}",
    upload_strategy: "presigned_put",
    expires_at: DateTime.add(now_utc, 3600, :second),
    inserted_at: now_naive,
    updated_at: now_naive
  })
end

IO.puts("Finished seeding lifecycle edge cases.")
