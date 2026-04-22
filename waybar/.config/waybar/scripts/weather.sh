#!/usr/bin/env bash
# Weather widget for waybar. Fetches wttr.in and emits JSON for a custom module.
# Env: WEATHER_UNITS=f|c (default f), WEATHER_LOCATION=<wttr.in location> (default auto)

set -u

UNITS="${WEATHER_UNITS:-f}"
LOCATION="${WEATHER_LOCATION:-}"

raw=$(curl -fsS --max-time 8 "https://wttr.in/${LOCATION}?format=j1" 2>/dev/null) || {
  printf '{"text":"󰆐","tooltip":"weather unavailable","class":"error"}\n'
  exit 0
}

read -r code desc temp_c temp_f feels_c feels_f humidity wind_kmph wind_mph area region obs sunrise sunset < <(
  printf '%s' "$raw" | jq -r '
    [ .current_condition[0].weatherCode,
      .current_condition[0].weatherDesc[0].value,
      .current_condition[0].temp_C,
      .current_condition[0].temp_F,
      .current_condition[0].FeelsLikeC,
      .current_condition[0].FeelsLikeF,
      .current_condition[0].humidity,
      .current_condition[0].windspeedKmph,
      .current_condition[0].windspeedMiles,
      (.nearest_area[0].areaName[0].value // ""),
      (.nearest_area[0].region[0].value // ""),
      .current_condition[0].localObsDateTime,
      .weather[0].astronomy[0].sunrise,
      .weather[0].astronomy[0].sunset
    ] | map(gsub(" "; "_")) | join(" ")
  '
)
desc=${desc//_/ }
area=${area//_/ }
region=${region//_/ }
obs=${obs//_/ }
sunrise=${sunrise//_/ }
sunset=${sunset//_/ }

to_minutes() {
  local t="$1" hhmm ampm h m
  hhmm=${t% *}
  ampm=${t##* }
  h=${hhmm%:*}
  m=${hhmm#*:}
  h=$((10#$h))
  m=$((10#$m))
  if [ "$ampm" = "PM" ] && [ "$h" -ne 12 ]; then h=$((h+12)); fi
  if [ "$ampm" = "AM" ] && [ "$h" -eq 12 ]; then h=0; fi
  echo $((h*60 + m))
}

now_min=$((10#$(date +%H)*60 + 10#$(date +%M)))
sr_min=$(to_minutes "$sunrise")
ss_min=$(to_minutes "$sunset")
is_day=1
[ "$now_min" -lt "$sr_min" ] || [ "$now_min" -ge "$ss_min" ] && is_day=0

case "$code" in
  113) [ "$is_day" -eq 1 ] && icon="󰖙" || icon="󰖔" ;;
  116) [ "$is_day" -eq 1 ] && icon="󰖕" || icon="󰼱" ;;
  119|122) icon="󰖐" ;;
  143|248|260) icon="󰖑" ;;
  176|263|266|293|296|353) icon="󰖗" ;;
  299|302|305|308|356|359) icon="󰖖" ;;
  179|182|185|227|323|326|329|332|362|365|368|371) icon="󰖘" ;;
  230|335|338) icon="󰼶" ;;
  200|386|389|392|395) icon="󰙾" ;;
  281|284|311|314|317|320|350|374|377) icon="󰙿" ;;
  *) icon="󰖕" ;;
esac

if [ "$UNITS" = "c" ]; then
  text="${icon} ${temp_c}°"
  feels="${feels_c}°C"
  wind="${wind_kmph} km/h"
else
  text="${icon} ${temp_f}°"
  feels="${feels_f}°F"
  wind="${wind_mph} mph"
fi

place="$area"
[ -n "$region" ] && place="$area, $region"

tooltip=$(printf '<b>%s</b>\n%s\nFeels like %s · Humidity %s%%\nWind %s\n<i>Updated %s</i>' \
  "$desc" "$place" "$feels" "$humidity" "$wind" "$obs")

jq -nc --arg text "$text" --arg tooltip "$tooltip" --arg cls "code-$code" \
  '{text:$text, tooltip:$tooltip, class:$cls}'
