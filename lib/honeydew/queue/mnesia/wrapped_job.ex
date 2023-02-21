defmodule Honeydew.Queue.Mnesia.WrappedJob do
  alias Honeydew.Job

  @record_name :wrapped_job
  @record_fields [:key, :last_run, :job]

  job_filter_map =
    %Job{}
    |> Map.from_struct()
    |> Enum.map(fn {k, _} ->
      {k, :_}
    end)

  @job_filter struct(Job, job_filter_map)

  defstruct [:run_at, :last_run, :id, :job]

  def record_name, do: @record_name
  def record_fields, do: @record_fields

  def new(%Job{delay_secs: delay_secs} = job) do
    id = :erlang.unique_integer()
    run_at = now() + delay_secs
    last_run = System.system_time(:millisecond)

    job = %{job | private: id}

    %__MODULE__{id: id, job: job, run_at: run_at, last_run: last_run}
  end

  def from_record({@record_name, {run_at, id}, last_run, job}) do
    %__MODULE__{run_at: run_at, last_run: last_run, id: id, job: job}
  end

  def to_record(%__MODULE__{run_at: run_at, last_run: last_run, id: id, job: job}) do
    {@record_name, key(run_at, id), last_run, job}
  end

  def key({@record_name, key, _last_run, _job}) do
    key
  end

  def key(run_at, id) do
    {run_at, id}
  end

  def id_from_key({_run_at, id}) do
    id
  end

  def recalc_run_at(%__MODULE__{last_run: last_run, job: job} = wrapped_job) do
    delta_t = now - System.system_time(:second)
    %__MODULE__{wrapped_job | run_at: round(last_run / 1000.0) + delta_t + job.delay_secs}
  end

  def id_pattern(id) do
    %__MODULE__{
      id: id,
      run_at: :_,
      last_run: :_,
      job: :_
    }
    |> to_record
  end

  def filter_pattern(map) do
    job = struct(@job_filter, map)

    %__MODULE__{
      id: :_,
      run_at: :_,
      last_run: :_,
      job: job
    }
    |> to_record
  end

  def reserve_match_spec do
    pattern =
      %__MODULE__{
        id: :_,
        run_at: :"$1",
        last_run: :"_",
        job: :_
      }
      |> to_record

    [
      {
        pattern,
        [{:"=<", :"$1", now()}],
        [:"$_"]
      }
    ]
  end

  defp now do
    :erlang.monotonic_time(:second)
  end
end
