defmodule BgpTable.Consumer do
  use GenServer
  use AMQP


  require Logger



  @exchange "pmacct"
  @routing_key "routes"
  @queue "herp1"
  @queue_error "derp1"
  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: BgpTable.Consumer])
  end

  def init(_opts) do
    rabbitmq_connect()
  end

  def handle_info({:basic_deliver, payload, _}, state) do
    payload |> JSON.decode!
    |> classify_event
    |> BgpTable.LookupTable.Prefix.process
    {:noreply, state}
  end
  def handle_info({:basic_consume_ok, _}, chan) do
    Logger.info("Ready to receive messages from rabbitmq")
    {:noreply, chan}
  end
  def handle_info({:basic_cancel, _}, chan) do
    Logger.error("Got cancel shutting down")
    {:stop, :normal, chan}
  end
  def handle_info({:basic_cancel_ok, _}, chan) do
    Logger.info("Shutdown complete")
    {:noreply, chan}
  end
  def handle_info({:DOWN, _, :process, _pid, reason}, _) do
    Logger.error("Connection to rabbitmq lost #{inspect reason}")
    {:ok, chan} = rabbitmq_connect()
    {:noreply, chan}
  end
  def handle_info(data, state) do
    Logger.debug("Unknown message #{inspect data}")
    {:noreply, state}
  end

  defp rabbitmq_connect do
    Logger.info("Connecting to rabbitmq")
    case Connection.open("amqp://guest:guest@localhost") do
      {:ok, conn} ->
        {:ok, chan} = Channel.open(conn)
        Queue.declare(chan, @queue_error, durable: true)
        Queue.declare(chan, @queue, durable: true)
        Exchange.direct(chan, @exchange)
        Queue.bind(chan, @queue, @exchange, routing_key: @routing_key)
        {:ok, _consumer_tag} = Basic.consume(chan, @queue)
        Logger.info("Connection successful")
        {:ok, chan}
      {:error, msg} ->
        Logger.error("Connection error sleep 10sec #{inspect msg}")
        :timer.sleep(10000)
        rabbitmq_connect
    end
  end

  defp classify_event(msg) do
    {event, msg} = Map.pop(msg, "event_type")
    case event do
      "log" ->
        case msg["log_type"] do
          "update"   -> {:update, msg}
          "withdraw" -> {:delete, msg}
          "delete"   -> {:delete, msg}
          _          -> {:unknown, msg}
        end
      _  -> {:unknown, msg}
    end
  end

end
