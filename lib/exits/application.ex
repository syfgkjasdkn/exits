defmodule Exits.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: Exits.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: Exits.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
