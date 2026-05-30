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
