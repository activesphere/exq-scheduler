# ExqScheduler [![Build Status](https://travis-ci.org/activesphere/exq_scheduler.svg?branch=master)](https://travis-ci.org/activesphere/exq_scheduler)

## TODO
1. Loading Schedule: Schedule defined in the following fmt:
{cron, first/last run, job}. job uses Exq.Support.Job struct. Insert into redis.
(Validate they use the same format). Would be nice to use their respective UIs
2. Clock: Publishes ticks
3. Scheduler Server: Recieves ticks, checks with Storage if any jobs have to
run. Uses some sort of sliding window & performs a  range query to check for
unhandled jobs.
5. TaskRunner: Inserts matched jobs into respective job queues
6. Send a PR to extend exq's web component
7. Support rufus-scheduler styled every syntax. every, first_in, first_at, first,
   last_in, last_at, last
8. Extension of 7, schedule format needs to be similar to sidekiq-scheduler
