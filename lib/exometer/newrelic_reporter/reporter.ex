defmodule Exometer.NewrelicReporter.Reporter do
  @moduledoc """
  Retrieves stored metrics and sends them to NewRelic every N milliseconds
  """

  use GenServer
  require Logger

  alias __MODULE__, as: Reporter
  alias Exometer.NewrelicReporter.Transformer
  alias Exometer.NewrelicReporter.Collector
  alias Exometer.NewrelicReporter.Request

  @default_interval 60000

  def start_link(opts \\ []) do
    GenServer.start_link(Reporter, opts, name: Reporter)
  end

  @doc """
  Start our reporter. The main work is triggered once we
  get our configuration passed to set_configuration/1.
  """
  def init(opts) do
    Logger.info "New Relic Reporter configured with: #{inspect(opts)}"

    opts_with_interval = case Keyword.fetch(opts, :interval) do
      {:ok, _} -> opts
      :error -> Keyword.put_new(opts, :interval, @default_interval)
    end

    new_opts = opts_with_interval |> Keyword.merge(opts)
    report_now(new_opts)
    {:ok, new_opts}
  end

  @doc """
  Report into New Relic "now" (after waiting about 1000ms). Used
  when we need to send data more or less right away, without
  waiting on the timer loop.
  """
  def report_now(opts) do
    Process.send_after(Reporter, :report, 1000)
    opts
  end

  # Takes exactly what's in the metrics store and posts the contents
  # to New Relic using the call_count field to contain the metric value
  defp prepare_raw_metrics do
    Collector.peek |> Transformer.transform
  end

  # Take the data from the metrics store and synthesize normal New Relic
  # metrics
  defp synthesize_metrics(opts) do
    case Keyword.fetch(opts, :synthesize_metrics) do
      {:ok, metrics} ->
        Collector.peek |> Transformer.synthesize(metrics)
      :error ->
        []
    end
  end

# %{timed: %{"proxyHandler-handle" => %{50 => [{1487680368, 1234}]}}}

  @doc """
  Collect, aggregate, format, and report our metrics to NewRelic
  """
  def handle_info(:report, opts) do
    Logger.info "Reporting to New Relic"

    synthesize_metrics(opts) ++ prepare_raw_metrics() |> Request.request(opts)
    Collector.empty
    wait_then_report(opts)
    {:noreply, opts}
  end

  def handle_cast(msg, opts) do
    Logger.debug "Got unexpected message: #{inspect(msg)}"
    {:noreply, opts}
  end

  defp wait_then_report(opts) do
    Process.send_after(Reporter, :report, opts[:interval])
    opts
  end
end
