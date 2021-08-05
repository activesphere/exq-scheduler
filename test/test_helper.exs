test_env = Application.get_all_env(:exq_scheduler)
ExqScheduler.Time.init(Timex.now(), 60 * 60)

opts =
  TestUtils.add_redis_name(test_env, :redix)
  |> ExqScheduler.redix_spec()
  |> TestUtils.get_opts()

module = ExqScheduler.redis_module(test_env)
{:ok, _} = apply(module, :start_link, opts)

TestUtils.flush_redis()
ExUnit.start(capture_log: true, exclude: [:integration])
