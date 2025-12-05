#!/usr/bin/env bash
set -eo pipefail

# Made by Bensonheimer992 (https://git.bencraft.cloud/alex/scripts)

# Konfiguration
TEMP_PREFIX=".tmp_$(date +%s)_"
PRIMARY_LANG="deu"
DEFAULT_LANG="und"
LOG_FILE="./audio_tool_debug.log"
MAX_JOBS=1

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging-Funktionen
debug() { :; }
die() {
  echo -e "${RED}✘ $1${NC}" >&2
  exit 1
}
info() {
  echo -e "${GREEN}➔ $1${NC}"
}
warn() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

# Initialisierung
init() {
  > "$LOG_FILE"
}

check_deps() {
  if ! command -v ffmpeg >/dev/null; then die "FFmpeg nicht installiert"; fi
  if ! command -v ffprobe >/dev/null; then die "FFprobe nicht installiert"; fi
  if ! command -v jq >/dev/null; then die "jq nicht installiert"; fi
  if ! command -v xargs >/dev/null; then die "xargs nicht installiert"; fi
}

get_audio_streams() {
  local file="$1"
  ffprobe -v error -select_streams a \
    -show_entries stream=index,codec_name,channels:stream_tags=language \
    -of json "$file" | jq -c '.streams[] | { index: (.index | tonumber), codec: .codec_name, channels: (.channels | tonumber), lang: (try .tags.language catch "'$DEFAULT_LANG'") | sub("und"; "'$DEFAULT_LANG'") }' 2>> "$LOG_FILE"
}

process_file() {
  local file="$1"
  local interactive="$2"

  echo -e "\nVerarbeite Datei: $file"
  check_deps
  [ -f "$file" ] || die "Datei nicht gefunden: $file"

  # Audio-Streams analysieren
  mapfile -t audio_streams < <(get_audio_streams "$file")

  # Zähle englische/undefinierte Spuren
  candidate_count=0
  for stream in "${audio_streams[@]}"; do
    lang=$(jq -r '.lang' <<< "$stream")
    if [ "$lang" == "eng" ] || [ "$lang" == "$DEFAULT_LANG" ]; then
      candidate_count=$((candidate_count + 1))
    fi
  done

  # FFmpeg-Befehl initialisieren
  ffmpeg_cmd=( ffmpeg -v warning -i "$file" -map 0:v -c:v copy -map 0:s? -c:s copy )
  audio_output_index=0
  declare -a overview
  declare -A conv_mappings
  count_keep=0
  count_convert=0
  count_delete=0

  # Verarbeite jeden Audio-Stream
  for stream in "${audio_streams[@]}"; do
    index=$(jq -r '.index' <<< "$stream")
    lang=$(jq -r '.lang' <<< "$stream")
    codec=$(jq -r '.codec' <<< "$stream")
    channels=$(jq -r '.channels' <<< "$stream")
    new_lang="$lang"
    action="behalten"

    # Dynamische Qualitätseinstellung
    if [[ "$channels" -le 2 ]]; then
      aac_quality=2
    elif [[ "$channels" -le 6 ]]; then
      aac_quality=1
    else
      aac_quality=0
    fi

    # Sprachverarbeitung
    if [ "$lang" == "$DEFAULT_LANG" ]; then
      new_lang="$PRIMARY_LANG"
      action="→$PRIMARY_LANG"
    elif [ "$lang" == "eng" ]; then
      if [ "$candidate_count" -eq 2 ] && [ "$codec" == "mp2" ]; then
        action="gelöscht"
      else
        new_lang="$([ "$candidate_count" -eq 2 ] && echo "$PRIMARY_LANG" || echo "eng")"
        action="→$new_lang"
      fi
    elif [ "$lang" == "ger" ]; then
      new_lang="deu"
      action="→deu"
    elif [ "$lang" == "fre" ]; then
      new_lang="fra"
      action="→fra"
    elif [ "$lang" == "dut" ]; then
      new_lang="nld"
      action="→nld"
    elif [ "$lang" == "jap" ]; then
      new_lang="jpn"
      action="→jpn"
    fi

    # Füge Mapping zur Übersicht hinzu
    if [ "$action" != "behalten" ] && [ "$action" != "gelöscht" ]; then
      conv_mappings["$lang"]="$lang${action}"
    fi

    # Verarbeite Aktion
    if [ "$action" == "gelöscht" ]; then
      overview+=( "Spur $index: $codec [$lang] => $action" )
      count_delete=$((count_delete + 1))
    else
      ffmpeg_cmd+=( -map "0:$index" )
      ffmpeg_cmd+=( -c:a:$audio_output_index aac -q:a:$audio_output_index $aac_quality )
      ffmpeg_cmd+=( -metadata:s:a:$audio_output_index "language=$new_lang" )
      ffmpeg_cmd+=( -filter:a:$audio_output_index "dynaudnorm=f=150:g=11" )
      
      overview+=( "Spur $index: $codec [$lang] => ${new_lang}" )
      
      if [ "$new_lang" != "$lang" ]; then
        count_convert=$((count_convert + 1))
      else
        count_keep=$((count_keep + 1))
      fi
      
      audio_output_index=$((audio_output_index + 1))
    fi
  done

  # Ausgabe-Streams finalisieren
  ffmpeg_cmd+=( -map 0:t? -c:t copy )
  ffmpeg_cmd+=( -y )

  # Übersicht anzeigen
  echo -e "\nGefundene Sprachen:"
  for mapping in "${!conv_mappings[@]}"; do
    echo " - ${conv_mappings[$mapping]}"
  done
  echo ""
  echo "Aktionen:"
  echo " • Behalten: $count_keep Spur(en)"
  echo " • Konvertieren: $count_convert Spur(en)"
  if [ "$count_delete" -gt 0 ]; then
    echo " • Löschen: $count_delete Spur(en)"
  fi
  echo ""

  # Interaktive Bestätigung
  if [[ "$interactive" == true ]]; then
    read -p "Weiter verarbeiten? (j/n) " -n1 -r
    echo
    [[ $REPLY =~ ^[Jj]$ ]] || { info "Abbruch durch Benutzer"; return; }
  else
    info "Batch-Modus: Automatisch fortfahren"
  fi

  # Temporäre Datei verarbeiten
  temp_file="${TEMP_PREFIX}$(basename "$file")"
  ffmpeg_cmd+=( "$temp_file" )

  info "Starte FFmpeg-Verarbeitung..."
  if "${ffmpeg_cmd[@]}" >> "$LOG_FILE" 2>&1; then
    mv -v "$temp_file" "$file" >> "$LOG_FILE" 2>&1
    info "✓ Erfolgreich verarbeitet: $file"
  else
    tail -n 20 "$LOG_FILE" >&2
    die "FFmpeg-Verarbeitung fehlgeschlagen für: $file"
  fi
}

wait_for_slot() {
  while (( $(jobs -r | wc -l) >= MAX_JOBS )); do
    sleep 0.5
  done
}

main() {
  init "$@"
  case "$1" in
    --batch)
      [ -z "$2" ] && die "Bitte einen Ordner angeben."
      mapfile -d $'\0' files < <(find "$2" \( -type d \( -iname "trailers" -o -iname "*.trickplay" \) -prune \) \
        -o -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" \
                    -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" \) -print0)
      for file in "${files[@]}"; do
        wait_for_slot
        process_file "$file" false &
      done
      wait
      ;;
    --process)
      process_file "$2" false
      ;;
    --interactive)
      [ -z "$2" ] && die "Bitte eine Videodatei angeben."
      process_file "$2" true
      ;;
    *)
      echo -e "Verwendung:"
      echo -e "  $0 --batch <Ordner>"
      echo -e "  $0 --interactive <Datei>"
      exit 1
      ;;
  esac
}

main "$@"
