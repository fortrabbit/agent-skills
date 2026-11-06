---
max_turns: 15
allowed_tools: [Skill, Read, Glob, Grep]
tags: [trigger, deploy]
---

My deploy broke, this is the end of the log:

```
[en-a1b2c3] Running composer install --no-dev --optimize-autoloader
Your requirements could not be resolved to an installable set of packages.
  Problem 1
    - stripe/stripe-php v16.2.0 requires php >=8.4 -> your php version (8.3.14) does not satisfy that requirement.
Deployment dp-a1b2c3 failed
```

How do I fix it?
