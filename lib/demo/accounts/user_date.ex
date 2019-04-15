defmodule Demo.Accounts.UserData do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_data" do
    has_one :user_id, Demo.Accounts.User
    field :counter_value, :string
    field :settings_json, :string

    timestamps()
  end

  @doc false
  def changeset(user_data, attrs) do
    user_data
    |> cast(attrs, [:counter_value, :settings_json])
    |> validate_required([:counter_value, :settings_json])
    |> unique_constraint(:user_id)
  end
end
