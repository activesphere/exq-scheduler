# Exq Scheduler

[![CI](https://github.com/activesphere/exq-scheduler/actions/workflows/ci.yml/badge.svg)](https://github.com/activesphere/exq-scheduler/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/exq_scheduler.svg)](https://hex.pm/packages/exq_scheduler)

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
It uses `"#{exq_namespace}:sidekiq-scheduler"` for storing scheduler internal metadata.

```elixir
config :exq_scheduler, :storage,
  exq_namespace: "exq" # exq redis namespace
  json_serializer: Jason # or Poison, which is the default if not provided
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
  child_spec: {Redix, ["redis://localhost:6379", [name: ExqScheduler.Redis.Client]]}
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

* `retry`: Number of times Exq should retry the job if it fails. If set to true, Exq will use `max_retries` instead. Defaults to `true`.

* `enabled`: Schedule is enabled if set to true. Defaults to
  `true`. Note: if this config value is set, on restart it will
  override the any previous value set via Sidekiq web UI. Don't use
  this option if you want to enable/disable via Sidekiq web UI.

* `include_metadata`: If set to true, the schedule time in unix time format (example
  `{"scheduled_at"=>1527750039.080837}`) will be passed as an
  extra argument to `perform` method in worker. Defaults to `nil`.

* `description`: a text that will be shown in sidekiq web

### Misc

Scheduling each and every job at the exact time might not be possible
every time. The node might get restarted, the process might get
descheduled by the OS etc. To solve this exq scheduler by default
schedules any missed jobs in the last 3 hour. This interval can be
configured by changing `missed_jobs_window` value. Note: this config
value should be more than 3 hour to handle daylight saving properly

```elixir
config :exq_scheduler,
  missed_jobs_window: 3 * 60 * 60 * 1000,
  time_zone: "Asia/Kolkata"
```

* `missed_jobs_window`: Missed jobs interval in milliseconds. Defaults to
  `3 * 60 * 60 * 1000`

* `time_zone`: Default time zone for all schedules. Defaults to system
  time zone.

## Web

Exq Scheduler is compatible with
[sidekiq-scheduler](https://github.com/moove-it/sidekiq-scheduler#sidekiq-web-integration)
web UI. Make sure the `exq_namespace` value and the namespace in
sidekiq are same.

## Example

A Sample Mix project along with sidekiq web UI is avaialbe at
[demo](https://github.com/activesphere/exq-scheduler/tree/master/demo)
directory to demonstrate the configuration.  Sidekiq web interface
requires Ruby to be installed.

To install dependencies

```
> cd demo
> mix deps.get
> cd sidekiq-ui
> bundle install
```

To start it

```
> cd demo
> ./start_demo.sh
```

## Running tests

1. Install sidekiq (requires ruby 2.5.1 and bundler 1.16.1)

        $ (cd sidekiq && gem install bundler:1.16.1 && bundle install)

1. Setup services

        $ docker-compose up

1. Install dependencies

        $ mix deps.get

1. Run tests

        $ mix test
