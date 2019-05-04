defmodule Exits.Trapping do
  @moduledoc """
  This process spawns tasks and traps exits, it shouldn't crash when the tasks crash.

  Trapping exits to avoid task crashes is [considered](https://hexdocs.pm/elixir/Task.html#async/3-linking) a bad practice.
  """

  use GenServer

  defstruct tasks: %{}, state: 0

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_info({:task, fun}, %__MODULE__{tasks: tasks} = state) do
    %Task{ref: ref} = task = Task.async(fun)
    {:noreply, %{state | tasks: Map.put(tasks, ref, task)}}
  end

  def handle_info({ref, _result}, %__MODULE__{tasks: tasks} = state) when is_reference(ref) do
    {:noreply, %{state | tasks: Map.delete(tasks, ref)}}
  end

  def handle_info({:EXIT, _pid, _reason}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end
end
