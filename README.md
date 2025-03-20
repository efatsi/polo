# 3 2 1 Polo!!!

Rails app to help coordinate Crozet Bike Polo.

## Setup

Requirements
- Ruby @3.5.5
- Postgres @14

```bash
bundle install

rails db:create
rails db:migrate

foreman start -f Procfile.dev
```
