# Exq Scheduler [![Build Status](https://travis-ci.org/activesphere/exq-scheduler.svg?branch=master)](https://travis-ci.org/activesphere/exq-scheduler)

Exq Scheduler is a [cron](https://en.wikipedia.org/wiki/Cron) like job scheduler for
[Exq](https://github.com/akira/exq), it's also compatible with Sidekiq
and Resque.

## Installation

```
defp deps do
  [{:exq_scheduler, "~> x.x.x"}]
end
```

## Overview

Exq Scheduler pushes jobs into the queue at intervals specified by the
schedule configuration. It is designed to run on more than one machine
for redundancy without causing duplicate jobs to be scheduled.

## Configuration

By default Exq Scheduler will read the configuration from application environment.

### Storage

Exq Scheduler uses redis to store internal state of the scheduler.

```elixir
config :exq_scheduler, :storage,
  namespace: "exq_scheduler", # redis namespace for data stored by scheduler
  exq_namespace: "exq" # exq redis namespace
```
### Redis Client

Exq Scheduler will start a Redis Client under it's supervisor tree. It
supports both [Redix](https://github.com/whatyouhide/redix) and
[RedixSentinel](https://github.com/ananthakumaran/redix_sentinel). Redix
is used by default. The `name` used in the
[child_spec](https://hexdocs.pm/elixir/Supervisor.html#module-child_spec-1)
and config should be the same.

```elixir
config :exq_scheduler, :redis,
  name: ExqScheduler.Redis.Client,
  child_spec: {Redix, ["redis://localhost:6379", name: ExqScheduler.Redis.Client]}
```

### Schedules

```elixir
config :exq_scheduler, :schedules,
  signup_report: %{
    description: "Send the list of newly signed up users to admin",
    cron: "0 * * * *",
    class: "SignUpReportWorker",
    include_metadata: true,
    args: [],
    queue: "default"
  },
  login_report: %{
    cron: "0 * * * *",
    class: "LoginReportWorker"
  }
```

* `cron`: <kbd>required</kbd> Refer
  [cron](https://en.wikipedia.org/wiki/Cron) documentation for
  syntax. Time zone of a single schedule can be changed by specifying
  the time zone at the end. Example `0 * * * * Asia/Kolkata`.

* `class`: <kbd>required</kbd> Name of the worker class.

* `queue`: Name of the worker queue. Defaults to `"default"`.

* `args`: List of values that should be passed to `perform` method in
  worker. Defaults to `[]`.

* `enabled`: Schedule is disabled if set to nil or false. Defaults to `true`.

* `include_metadata`: If set to non nil/false, the schedule time (example
  `%{"scheduled_at" => "2018-05-25T11:30:00"}`) will be passed as an
  extra argument to `perform` method in worker. Defaults to `nil`.

* `description`: a text that will be shown in sidekiq web

### Misc

Scheduling each and every job at the exact time might not be possible
every time. The node might get restarted, the process might get
descheduled by the OS etc. To solve this exq scheduler by default
schedules any missed jobs in the last 1 hour. This interval can be
configured by changing `missed_jobs_window` value.

```elixir
config :exq_scheduler,
  missed_jobs_window: 60 * 60 * 1000,
  time_zone: "Asia/Kolkata"
```

* `missed_jobs_window`: Missed jobs interval in milliseconds. Defaults to
  `60 * 60 * 1000`

* `time_zone`: Default time zone for all schedules. Defaults to system
  time zone.

## Web

Exq Scheduler is compatible with
[sidekiq-scheduler](https://github.com/moove-it/sidekiq-scheduler#sidekiq-web-integration)
web UI. Make sure the `exq_namespace` value and the namespace in
sidekiq are same.
