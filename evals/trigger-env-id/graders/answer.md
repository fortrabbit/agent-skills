---
type: llm
---

PASS if the reply gives an SSH command for en-a1b2c3 on ssh.eu-w1a.frbit.app that runs php artisan migrate (with --force or after a confirmation), and asks for a yes before running it on production or hands it to the person to run.
FAIL if it asks which hosting provider or server is meant, guesses a different host or region, or claims it ran the migrations.
