---
type: llm
---

PASS if the reply gives a way to dump the acme-shop database that needs no database password: one SSH command that runs mysqldump on the environment, with an environment ID (en-a1b2c3 or en-d4e5f6) and region eu-w1a filled in, for the person to run in their own terminal. Asking whether production or staging is meant is fine, as long as the command is shown for at least one of them.
FAIL if it only offers the SSH tunnel with a password prompt, asks for the database password in the chat, shows a command with an unfilled placeholder such as <skill-dir>, or claims it has pulled the database itself.
