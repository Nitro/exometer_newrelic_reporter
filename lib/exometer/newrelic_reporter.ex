defmodule Exometer.NewrelicReporter do
  require Logger
  use Application

  @behaviour :exometer_report

  alias Exometer.NewrelicReporter.{Collector, Reporter}

  def start(_type, opts) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Collector, opts),
      worker(Reporter, opts)
    ]

    opts = [strategy: :one_for_one, name: Collector.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Entrypoint to our reporter, invoked by Exometer with configuration options.
  """
  def exometer_init(opts) do 
    Logger.info "New Relic plugin starting with opts: #{inspect(opts)}"
    Reporter.set_configuration(opts)
    {:ok, opts}
  end

  @doc """
  Invoked by Exometer when there is new data to report.
  """
  def exometer_report(metric, data_point, _extra, values, settings) do
    Collector.collect(metric, data_point, values, settings)
    {:ok, settings}
  end

  def exometer_call(_, _, opts),            do: {:ok, opts}
  def exometer_cast(_, opts),               do: {:ok, opts}
  def exometer_info(_, opts),               do: {:ok, opts}
  def exometer_newentry(_, opts),           do: {:ok, opts}
  def exometer_setopts(_, _, _, opts),      do: {:ok, opts}
  def exometer_subscribe(_, _, _, _, opts), do: {:ok, opts}
  def exometer_terminate(_, _),             do: nil
  def exometer_unsubscribe(_, _, _, opts),  do: {:ok, opts}
end
