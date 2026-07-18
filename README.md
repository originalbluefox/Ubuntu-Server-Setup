# Ubuntu Server Setup
## For use with Ubuntu 20.04

Hiya, Kyra here.

Yet another little project to help me in my day to day dev tasks, hope someone finds this helpful.


Run me here
```https://raw.githubusercontent.com/originalbluefox/Ubuntu-Server-Setup/refs/heads/main/install.sh | sudo bash ```

Currently, this script doesnt have an interface (I forgot to build one)
So for now, as of ver 1.0.6 you need to use
--opt "(value)"

Current values: full, docker, nginx, certbot, nvm (installs node!), mysql
Flags:
--force, skips the y/n prompt for every command.

Pretty much every command without --force asks for permission before running and prints out the command in full. Please read and make sure you execute the right commands for your needs!
and, as always, be wary of running scripts off the internet. 

Luckily, as far as I know, this isn't malicious so thats cool!

Default node version is 20.18.0 btw

