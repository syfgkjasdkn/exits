defmodule Exits.Supervised do
  @moduledoc """
  This process spawns tasks under a supervisor, it shouldn't crash when the tasks started with `async_nolink` crash.
  """

  use GenServer

  @supervisor Exits.TaskSupervisor

  defstruct tasks: %{}, state: 0

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({f, fun}, _from, %__MODULE__{tasks: tasks} = state)
      when f in [:async, :async_nolink] do
    %Task{ref: ref} = task = apply(Task.Supervisor, f, [@supervisor, fun])
    {:reply, task, %{state | tasks: Map.put(tasks, ref, task)}}
  end

  def handle_call({f, fun, enum}, _from, state)
      when f in [:async_stream, :async_stream_nolink] do
    stream = apply(Task.Supervisor, f, [@supervisor, enum, fun])
    {:reply, stream, state}
  end

  @impl true
  def handle_info({ref, _result}, %__MODULE__{tasks: tasks} = state) when is_reference(ref) do
    # Process.demonitor(ref, [:flush])
    {:noreply, %{state | tasks: Map.delete(tasks, ref)}}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end
end
