#!/bin/sh

echo "------------------------------------------------------"
echo " EXQ-SCHEDULE DEMO"
echo " Sidekiq interface can be accessed at http://localhost:3000/"
echo "------------------------------------------------------"

cd sidekiq-ui/
bundle exec rackup -o 0.0.0.0 -p 3000 config.ru &> /dev/null &
cd ../

mix run --no-halt
