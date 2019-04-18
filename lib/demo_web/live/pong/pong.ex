defmodule DemoWeb.Pong do
  use Phoenix.LiveView
  alias DemoWeb.Pong.Ball
  @tick 20
  @paddle_size 100
  
  @player_1_position 200

  @width 400
  @height 400
  @paddle_speed 10
  @paddle_offset 50
  @ball_size 15
  

  def render(%{game_state: :over} = assigns) do
    ~L"""
    <div class="pong-container">
      <div class="game-over">
        <h1>GAME OVER <small>SCORE: <%= @score %></h1>
        <button phx-click="new_game">NEW GAME</button>
      </div>
    </div>
    """
  end

  def render(%{game_state: :playing} = assigns) do
    ~L"""
    <div class="pong-options">
      <form phx-change="update_settings">
        <select name="tick" onchange="this.blur()">
          <option value="5" <%= if @tick == 50, do: "selected" %>>50</option>
          <option value="10" <%= if @tick == 100, do: "selected" %>>100</option>
          <option value="20" <%= if @tick == 200, do: "selected" %>>200</option>
          <option value="50" <%= if @tick == 500, do: "selected" %>>500</option>
        </select>
        <input type="range" min="5" max="50" name="width" value="<%= @ball.size %>" />
        <%= @ball.size %>px
      </form>
    </div>
    <h3 class="score">SCORE:&nbsp;<%= @score %></h3>
    <div
      class="pong-container"
      phx-keydown="keydown"
      phx-keyup="keyup"
      phx-target="window"
      style="
        position: relative;
        height: <%= @height %>px;
        width: <%= @width %>px;
        background-color: #222;
      "
    >
      <div
        class="ball"
        style="
          position:absolute;
          left: <%= @ball.position.x - @ball.size/2 %>px;
          bottom: <%= @ball.position.y - @ball.size/2 %>px;
          width: <%= @ball.size %>px;
          height: <%= @ball.size %>px;
          background-color: white;
        "
      ></div>

      <div
        class="paddle player-1"
        style="
          position:absolute;
          left: <%= @player_1_position - @paddle_size/2 %>px;
          top: <%= @height - @paddle_offset %>px;
          width: <%= @paddle_size %>px;
          height: 20px;
          background-color: white;
        "
      ></div>
      <div
        class="paddle player-2"
        style="
          position:absolute;
          left: <%= @player_1_position - @paddle_size/2 %>px;
          bottom: <%= @height - @paddle_offset %>px;
          width: <%= @paddle_size %>px;
          height: 20px;
          background-color: white;
        "
      ></div>
    </div>
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
          x: %{min: @ball_size/2, max: @width - @ball_size/2},
          y: %{min: @paddle_offset + @ball_size/2, max: @height - @paddle_offset - @ball_size/2},
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
  defp unset_heading(socket, :none), do: socket

  defp set_heading(socket, heading) do
    update(socket, :pending_headings, &(Map.put(&1, heading, true)))
  end
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


  # defp game_loop(%{assigns: %{pending_headings: %{}} = socket), do: socket

  defp paddle_hit_ball?(paddle_position, ball) do
    distance_to_ball = abs(paddle_position - Ball.get_intersect(ball))
    distance_to_ball < @paddle_size/2 + ball.size/2
  end


  defp game_loop(socket) do
    if socket.assigns.game_state == :playing do
      heading = next_heading(socket)
      # {row_before, col_before} = coord(socket)
      # maybe_row = row(row_before, heading)
      # maybe_col = col(col_before, heading)
      paddle_position = next_paddle_position(heading, socket)

      if Ball.will_go_out_of_bounds?(socket.assigns.ball, :y)
      and not paddle_hit_ball?(paddle_position, socket.assigns.ball) do
        socket
        |> game_over()
      else
        socket
        |> update(:ball, fn ball ->  Ball.next_position(ball) end)
        |> update(:heading, fn _ -> heading end)
        |> update(:player_1_position, fn _ -> paddle_position end)
      end

    else
      socket
    end
  end

  defp game_over(socket), do: assign(socket, :game_state, :over)

end
