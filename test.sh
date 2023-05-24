#!/bin/bash
typeset -A config # init array
config=( # set default values in config array
    [username]="root"
    [password]=""
    [hostname]="localhost"
)


while read line
do
    if echo $line | grep -F = &>/dev/null
    then
        varname=$(echo "$line" | cut -d '=' -f 1)
        config[$varname]=$(echo "$line" | cut -d '=' -f 2-)
    fi
done < general.conf

echo ${config[username]} # should be loaded from defaults
echo ${config[password]} # should be loaded from config file
echo ${config[hostname]} # includes the "injected" code, but it's fine here
echo ${config[PROMPT_COMMAND]} # also respects variables that you may not have
               # been looking for, but they're sandboxed inside the $config array