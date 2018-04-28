#!/bin/bash

function refresh_config_when_stale_nodes_found() {
  function timestamp() {
    date_string=`date -u +"%d %b %H:%M:%S.%s"`
    echo "${date_string:0:19}"
  }
  expected_num_other_sentinels=$((EXPECTED_NUM_SENTINELS - 1))
  current_num_other_sentinels=$(echo $(redis-cli -p 26379 sentinel master mymaster) | grep -o "num-other-sentinels [0-9]*" | sed 's/[^0-9]*//g')

  if ((${current_num_other_sentinels} > ${expected_num_other_sentinels})); then
    echo "$(timestamp) - Discrepancy found with number of sentinels - checking if master is currently down"
    sleep 6
    master_down_regex="s_down,o_down,master"
    # TODO maybe get sentinel config (SENTINEL sentinels mymaster) and refresh only if 'last-ok-ping-reply' is above threshold
    # Current implementation could pose a problem if number of sentinel replicas is increased and old pods aren't cycled out quickly
    master_down="$(echo $(redis-cli -p 26379 sentinel master mymaster) | grep -o $master_down_regex)"
    if [[ -z "$master_down" ]]; then
      echo "$(timestamp) - Master accessible, resynchronizing sentinel config"
      result=$(redis-cli -p 26379 sentinel reset mymaster)
      if [ $result -eq 1 ]; then
        echo "$(timestamp) - Successfully resynchronised sentinel config"
        exit 0
      else
        echo "$(timestamp) - Unable to resynchronize sentinel config"
        exit 1
      fi
    else
      echo "$(timestamp) - Master is down - unable to resynchronize sentinel config"
      exit 0
    fi
  fi
}

refresh_config_when_stale_nodes_found