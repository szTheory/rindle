defmodule Rindle.Migration.V1.Preflight do
  @moduledoc false

  @spec classify(:public_to_rindle | :rindle_to_public, map()) ::
          :already_upgraded
          | :already_reversed
          | {:provisionable_absent_target | :movable_existing_target, map()}
          | {:refusal, atom()}
  def classify(:public_to_rindle, snapshot) do
    cond do
      complete_source?(snapshot) and
          snapshot.target_relations == [] and
          valid_marker?(snapshot.source_marker, snapshot) and
          snapshot.source_owned? and not snapshot.target_exists? and
          snapshot.database_create? ->
        {:provisionable_absent_target, snapshot}

      complete_source?(snapshot) and
          snapshot.target_relations == [] and
          valid_marker?(snapshot.source_marker, snapshot) and
          snapshot.source_owned? and snapshot.target_exists? and snapshot.target_usable? ->
        {:movable_existing_target, snapshot}

      snapshot.source_relations == [] and complete_target?(snapshot) and
          valid_marker?(snapshot.target_marker, snapshot) ->
        :already_upgraded

      not snapshot.source_owned? ->
        {:refusal, :source_not_owned}

      not complete_source?(snapshot) ->
        {:refusal, :public_incomplete}

      not valid_marker?(snapshot.source_marker, snapshot) ->
        {:refusal, :public_marker_invalid}

      snapshot.target_relations != [] ->
        {:refusal, :rindle_not_empty}

      not snapshot.target_exists? and not snapshot.database_create? ->
        {:refusal, :database_create_denied}

      snapshot.target_exists? and not snapshot.target_usable? ->
        {:refusal, :rindle_unusable}

      true ->
        {:refusal, :mixed_state}
    end
  end

  def classify(:rindle_to_public, snapshot) do
    cond do
      complete_target?(snapshot) and snapshot.source_relations == [] and
          valid_marker?(snapshot.target_marker, snapshot) and snapshot.target_owned? and
          snapshot.public_usable? ->
        {:movable_existing_target, snapshot}

      complete_source?(snapshot) and snapshot.target_relations == [] and
          valid_marker?(snapshot.source_marker, snapshot) ->
        :already_reversed

      not snapshot.target_owned? ->
        {:refusal, :source_not_owned}

      not complete_target?(snapshot) ->
        {:refusal, :rindle_incomplete}

      not valid_marker?(snapshot.target_marker, snapshot) ->
        {:refusal, :rindle_marker_invalid}

      snapshot.source_relations != [] ->
        {:refusal, :public_not_empty}

      not snapshot.public_usable? ->
        {:refusal, :public_unusable}

      true ->
        {:refusal, :mixed_state}
    end
  end

  defp complete_source?(snapshot), do: snapshot.source_relations == snapshot.owned_relations
  defp complete_target?(snapshot), do: snapshot.target_relations == snapshot.owned_relations
  defp valid_marker?(versions, snapshot), do: versions == [snapshot.current_version]
end
