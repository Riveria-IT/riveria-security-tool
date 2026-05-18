#!/usr/bin/env bash

recalculate_score() {
    local i
    SCORE=100
    for ((i=0; i<${#ISSUE_LEVELS[@]}; i++)); do
        case "${ISSUE_LEVELS[$i]}" in
            WARNUNG) SCORE=$((SCORE - 4)) ;;
            KRITISCH) SCORE=$((SCORE - 12)) ;;
        esac
    done

    [ "$SCORE" -lt 0 ] && SCORE=0
    [ "$SCORE" -gt 100 ] && SCORE=100

    if [ "$SCORE" -ge 75 ]; then
        STATUS_LABEL="Gut"
    elif [ "$SCORE" -ge 50 ]; then
        STATUS_LABEL="Mittel"
    else
        STATUS_LABEL="Kritisch"
    fi
}
