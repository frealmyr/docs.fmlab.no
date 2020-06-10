#!/bin/bash
# Color formatting for terminal output
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
normal=$(tput sgr0)

if [ $1 = "start" ]; then
  if [ -z $2 ]; then
    echo "homelab: starting all stacks.."
    for d in */; do # only match directories
      for subd in $d*/; do # only match sub-directories
        printf "\n%40s\n" "homelab: ${green}now starting ${yellow}$subd ${normal}"
        ( cd "$subd" && docker-compose up -d ) # Use a subshell to avoid having to cd back to the root each time.
      done
    done
  else
    for d in $2/; do # only match directories
      for subd in $d*/; do # only match sub-directories
        printf "\n%40s\n" "homelab: ${green}now starting ${yellow}$subd ${normal}"
        ( cd "$subd" && ulimit -n 50000 && docker-compose up -d ) # Use a subshell to avoid having to cd back to the root each time.
      done
    done
  fi
elif [ $1 = "stop" ]; then
  if [ -z $2 ]; then
    echo "homelab: stopping all stacks.."
    for d in */; do # only match directories
      for subd in $d*/; do # only match sub-directories
        printf "\n%40s\n" "homelab: ${green}now stopping ${yellow}$subd ${normal}"
        ( cd "$subd" && docker-compose down ) # Use a subshell to avoid having to cd back to the root each time.
      done
    done
  else
    for d in $2/; do # only match directories
      for subd in $d*/; do # only match sub-directories
        printf "\n%40s\n" "homelab: ${red}now stopping ${yellow}$subd ${normal}"
        ( cd "$subd" && docker-compose down ) # Use a subshell to avoid having to cd back to the root each time.
      done
    done
  fi
else
  echo "\nRun this script with arguments: "
  printf "%40s\n" "./$0 ${green}start${normal}|${red}stop ${normal}[optional_dir]"
fi
