defmodule DemoWeb.Pong do
  use Phoenix.LiveView
  alias DemoWeb.Pong.Ball
  @tick 20
  @paddle_size 100
  
  @player_1_position 200

  @width 800
  @height 800
  @paddle_speed 12
  @paddle_offset 50
  @ball_size 15

  def render(assigns) do
    ~L"""
    <h3 class="score">SCORE:&nbsp;<%= @ball.score %></h3>
    <%= if @game_state == :game_over do %>
      <div class="game-over" style="position: absolute; margin:auto; top: 200px; width:<%= @width %>px; z-index: 20; color: white">
        <h1>GAME OVER</h1>
        <h2>SCORE: <%= @ball.score %></h2>
        <button phx-click="new_game">NEW GAME</button>
      </div>
    <% end %>
    <svg
      class="pong-container"
      phx-keydown="keydown"
      phx-keyup="keyup"
      phx-target="window"
      transform="scale(1,-1)"
      height="<%= @height %>"
      width="<%= @width %>"
      style="
        background-color: #222;
      "
    >
      <circle
        class="ball"
        cx="<%= @ball.position.x %>"
        cy="<%= @ball.position.y %>"
        r="<%= @ball.size/2 %>"
        fill="white"
      />

      <rect
        class="paddle player-1"
        x="<%= @player_1_position - @paddle_size/2 %>"
        y="<%= @paddle_offset - 20 %>"
        width="<%= @paddle_size %>"
        height="20"
        fill="white"
      />
      <rect
        class="paddle player-2"
        x="<%= @player_1_position - @paddle_size/2 %>"
        y="<%= @height - @paddle_offset %>"
        width="<%= @paddle_size %>"
        height="20"
        fill="white"
      />
    </svg>
    """
  end

  def mount(_session, socket) do
    {:ok, socket |> new_game() |> schedule_tick()}
  end

  defp new_game(socket) do
    defaults = %{
      score: 0,
      game_state: :playing,
      heading: :stationary,
      pending_headings: %{left: false, right: false},
      ball: %Ball{
        size: @ball_size,
        bounds: %{
          x: %{min: 0, max: @width},
          y: %{min: @paddle_offset, max: @height - @paddle_offset},
        },
      },
      paddle_size: @paddle_size,
      paddle_offset: @paddle_offset,
      width: @width,
      height: @height,
      tick: @tick,
      player_1_position: @player_1_position,
    }

    socket
    |> assign(defaults)
  end

  def handle_event("update_settings", %{"width" => width, "tick" => tick}, socket) do
    {width, ""} = Integer.parse(width)
    {tick, ""} = Integer.parse(tick)

    new_socket =
      socket
      |> update_size(width)
      |> update_tick(tick)

    {:noreply, new_socket}
  end

  def handle_event("new_game", _, socket) do
    {:noreply, new_game(socket)}
  end

  def handle_event("keydown", key, socket) do
    direction = case key do
      "ArrowLeft" -> :left 
      "ArrowRight" -> :right
      _ -> :none
    end
    {:noreply, set_heading(socket, direction)}
  end

  def handle_event("keyup", key, socket) do
    direction = case key do
      "ArrowLeft" -> :left 
      "ArrowRight" -> :right
      _ -> :none
    end
    {:noreply, unset_heading(socket, direction)}
  end

  def handle_info(:tick, socket) do
    new_socket =
      socket
      |> game_loop()
      |> schedule_tick()

    {:noreply, new_socket}
  end

  defp update_tick(socket, tick) when tick <= 1000 and tick >= 50 do
    assign(socket, :tick, tick)
  end

  defp schedule_tick(socket) do
    Process.send_after(self(), :tick, socket.assigns.tick)
    socket
  end

  defp update_size(socket, width) do
    socket
    |> assign(ball_size: width)
  end

  defp set_heading(socket, :none), do: socket
  defp set_heading(socket, heading) do
    update(socket, :pending_headings, &(Map.put(&1, heading, true)))
  end

  defp unset_heading(socket, :none), do: socket
  defp unset_heading(socket, heading) do
    update(socket, :pending_headings, &(Map.put(&1, heading, false)))
  end

  defp next_heading(socket) do
    case socket.assigns.pending_headings do
      %{left: left, right: right} when left == right -> :stationary
      %{left: true, right: false} -> :left
      %{left: false, right: true} -> :right
    end
  end

  defp next_paddle_position(heading, socket) do
    case heading do
      :stationary -> socket.assigns.player_1_position
      :left -> max(socket.assigns.player_1_position - @paddle_speed, 0+@paddle_size/2)
      :right -> min(socket.assigns.player_1_position + @paddle_speed, @width-@paddle_size/2)
    end
  end

  defp paddle_can_hit_ball?(paddle_position, ball) do
    distance_to_ball = abs(paddle_position - Ball.get_intersect(ball))
    distance_to_ball < @paddle_size/2 + ball.size/2
  end


  defp game_loop(socket) do
    if socket.assigns.game_state == :playing do
      heading = next_heading(socket)
      paddle_position = next_paddle_position(heading, socket)
      maybe_next_ball = Ball.next_position(socket.assigns.ball, [:x])

      if Ball.is_out_of_bounds?(maybe_next_ball, @paddle_offset) do
        socket
        |> game_over()
      else
        can_bounce_directions = if paddle_can_hit_ball?(paddle_position, maybe_next_ball) do
          [:x, :y]
        else
          [:x]
        end

        socket
        |> update(:ball, fn ball ->  Ball.next_position(ball, can_bounce_directions) end)
        |> update(:heading, fn _ -> heading end)
        |> update(:player_1_position, fn _ -> paddle_position end)
      end

    else
      socket
    end
  end

  defp game_over(socket), do: assign(socket, :game_state, :game_over)

end
