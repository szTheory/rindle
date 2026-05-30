defmodule AdoptionDemo.Cohort do
  @moduledoc false

  import Ecto.Query

  alias AdoptionDemo.Cohort.{Course, Lesson, Post}
  alias AdoptionDemo.Repo

  def list_courses do
    Repo.all(
      from c in Course,
        preload: [:instructor, lessons: ^from(l in Lesson, order_by: l.position)],
        order_by: c.title
    )
  end

  def get_course!(id), do: Repo.get!(Course, id) |> Repo.preload([:instructor, :lessons])

  def get_lesson!(id), do: Repo.get!(Lesson, id) |> Repo.preload(:course)

  def list_posts do
    Repo.all(from p in Post, preload: :member, order_by: [desc: p.inserted_at])
  end

  def get_post!(id), do: Repo.get!(Post, id) |> Repo.preload(:member)

  def seed_course!(attrs) do
    slug = attrs[:slug] || attrs["slug"]

    case Repo.get_by(Course, slug: slug) do
      %Course{} = course ->
        course

      nil ->
        %Course{}
        |> Ecto.Changeset.change(attrs)
        |> Repo.insert!()
    end
  end

  def seed_lesson!(attrs) do
    course_id = attrs[:course_id] || attrs["course_id"]
    position = attrs[:position] || attrs["position"]

    case Repo.one(from l in Lesson, where: l.course_id == ^course_id and l.position == ^position) do
      %Lesson{} = lesson ->
        lesson

      nil ->
        %Lesson{}
        |> Ecto.Changeset.change(attrs)
        |> Repo.insert!()
    end
  end

  def seed_post!(attrs) do
    title = attrs[:title] || attrs["title"]
    member_id = attrs[:member_id] || attrs["member_id"]

    case Repo.one(from p in Post, where: p.title == ^title and p.member_id == ^member_id) do
      %Post{} = post ->
        post

      nil ->
        %Post{}
        |> Ecto.Changeset.change(attrs)
        |> Repo.insert!()
    end
  end
end
