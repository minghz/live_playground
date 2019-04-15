defmodule DemoWeb.UserLive.PresenceIndex do
  use Phoenix.LiveView

  alias Demo.Accounts
  alias DemoWeb.{UserView, Presence}
  alias Phoenix.Socket.Broadcast

  def mount(%{path_params: %{"name" => name}}, socket) do
    Demo.Accounts.subscribe()
    Phoenix.PubSub.subscribe(Demo.PubSub, "users")
    Presence.track(self(), "users", name, %{
      val: 0,
    })
    socket = assign(socket, :name,  name)
    {:ok, fetch(socket)}
  end

  # def terminate(reason, socket) do
  # end

  def render(assigns), do: UserView.render("index.html", assigns)


  defp fetch(socket) do
    assign(socket, Map.merge(socket.assigns, %{
      users: Accounts.list_users(),
      online_users: Presence.list("users")
    }))
  end

  def handle_info(%Broadcast{event: "presence_diff"}, socket) do
    {:noreply, fetch(socket)}
  end

  def handle_info({Accounts, [:user | _], _}, socket) do
    {:noreply, fetch(socket)}
  end

  def handle_event("delete_user", id, socket) do
    user = Accounts.get_user!(id)
    {:ok, _user} = Accounts.delete_user(user)

    {:noreply, socket}
  end

  defp increment(meta) do
    Map.update(meta, :val, 1, &(&1+1))
  end
  defp decrement(meta) do
    Map.update(meta, :val, 1, &(&1-1))
  end

  def handle_event("inc", thing, socket) do
    Presence.update(self(), "users", socket.assigns.name, fn meta -> increment(meta) end)
    {:noreply, socket }
  end

  def handle_event("dec", _, socket) do
    Presence.update(self(), "users", socket.assigns.name, fn meta -> decrement(meta) end)
    {:noreply, socket }
  end
end
