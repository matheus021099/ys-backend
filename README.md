# Yousound

## Install

Things you may want to cover:

- Ruby version
  2.4.1

- Development
  git clone git@github.com:yousound/api.git
  git branch staging
  git fetch

  install rbenv or rvm
  set ruby version 2.4.1
  bundle install

  install elasticsearch ( only for local, we use AWS Elasticsearch on server )
  RAKE_ENV=development RAILS_ENV=development elasticsearch
  rake searchkick:reindex CLASS=User
  rake searchkick:reindex CLASS=Album

  cap development staging

- Connect to Server
  chmod 400 ../info/ec2-refactor2017.pem
  ssh -i ../info/ec2-refactor2017.pem ubuntu@52.53.50.11
  sudo service nginx status ( check nginx, web-server running )
  sudo /usr/sbin/passenger-memory-stats ( check passenger, web-application-server is running )

## Flow

### order flow

- when user places an order, he puts the card info and creates the `stripe_token` on front-end (desktop/mobile) side
- it calls `items/buy` API with `stripe_token`
- on API side, it gets the amount from the card with `stripe_token` and then divide the amount to merchants and collaborators.

## Data Structure

### shop_item

- price: each item price, item_total_price = price \* quantity
- tax: total tax on item regarding to quantity

## ToDo

### streams

- rename StreamsChannel to StreamViewersChannel
- rename StreamCreatorsChannel to StreamChannel
- require all channel name and data
