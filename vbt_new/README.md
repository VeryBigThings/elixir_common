# VbtNew

This project powers the `vbt.new` mix task.

If you want to manually test this task, simply invoke `mix vbt.new` from this project's folder. Note that the entire task is tested via `mix test`. The first test run will take about 15 minutes, but subsequent runs will have a fairly reasonable time of about 5 seconds.

Since this project generates a mix archive, you shouldn't add any runtime dependencies to the project (compile-time dependencies are fine).
