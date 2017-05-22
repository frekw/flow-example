defmodule Example.Queue do
  def start_link(limit) do
    BlockingQueue.start_link(limit, name: __MODULE__)
  end

  def push(x) do
    BlockingQueue.push(__MODULE__, x)
  end

  def to_stream() do
    BlockingQueue.pop_stream(__MODULE__)
  end
end

defmodule Example.Producer do
  require Logger
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, 0, opts)
  end

  def init(state) do
    loop()

    {:ok, state}
  end

  defp loop do
    Process.send_after(self(), :loop, 10)
  end

  def handle_info(:loop, state) do
    Logger.info("pushing: #{state}")
    Example.Queue.push("message-#{state}")

    loop()

    {:noreply, state + 1}
  end
end

defmodule Example.Pipeline do
  require Logger
  def start_link() do
    Logger.info("Starting pipeline")

    Example.Queue.to_stream()

    # This seems to work as I would expect.
    # |> Flow.from_enumerable(max_demand: 1)

    # This wait for an initial 1000 messages before
    # Flow.each starts running.
    |> Flow.from_enumerable()
    |> Flow.each(fn x -> Logger.info("handled: #{x}") end)
    |> Flow.start_link()
  end
end

defmodule Example do
  use Application
  def start(_type, _args) do
    import Supervisor.Spec
    children = [
      worker(Example.Queue, [:infinity]),
      worker(Example.Producer, []),
      worker(Example.Pipeline, []),
    ]

    Supervisor.start_link(children, strategy: :rest_for_one)
  end
end
