#! /bin/bash

set -euo pipefail

PSQL="psql --username=freecodecamp --dbname=salon --no-align --tuples-only --set=ON_ERROR_STOP=1 -c"

# Safely quote user-entered values inside PostgreSQL string literals.
sql_quote() {
  local value=$1
  value=${value//\'/\'\'}
  printf '%s' "$value"
}

FIRST_PROMPT=1
while true; do
  SERVICE_MENU=$($PSQL "SELECT service_id || ') ' || name FROM services ORDER BY service_id;")
  if (( FIRST_PROMPT == 1 )); then
    printf '\n~~~~~ MY SALON ~~~~~\n\nWelcome to My Salon, how can I help you?\n\n%s\n' "$SERVICE_MENU"
    FIRST_PROMPT=0
  else
    printf '\nI could not find that service. What would you like today?\n%s\n' "$SERVICE_MENU"
  fi
  read SERVICE_ID_SELECTED || exit 0

  SERVICE_NAME=''
  if [[ "$SERVICE_ID_SELECTED" =~ ^[0-9]+$ ]]; then
    SERVICE_NAME=$($PSQL "SELECT name FROM services WHERE service_id=$SERVICE_ID_SELECTED;")
  fi

  if [[ -n "$SERVICE_NAME" ]]; then
    break
  fi
done

printf '\nWhat\x27s your phone number?\n'
read CUSTOMER_PHONE || exit 0
PHONE_SQL=$(sql_quote "$CUSTOMER_PHONE")
CUSTOMER_ID=$($PSQL "SELECT customer_id FROM customers WHERE phone='$PHONE_SQL';")

if [[ -z "$CUSTOMER_ID" ]]; then
  printf '\nI don\x27t have a record for that phone number, what\x27s your name?\n'
  read CUSTOMER_NAME || exit 0
  NAME_SQL=$(sql_quote "$CUSTOMER_NAME")
  $PSQL "INSERT INTO customers (phone, name) VALUES ('$PHONE_SQL', '$NAME_SQL') ON CONFLICT (phone) DO NOTHING;" >/dev/null
  CUSTOMER_ID=$($PSQL "SELECT customer_id FROM customers WHERE phone='$PHONE_SQL';")
else
  CUSTOMER_NAME=$($PSQL "SELECT name FROM customers WHERE customer_id=$CUSTOMER_ID;")
fi

printf '\nWhat time would you like your %s, %s?\n' "$SERVICE_NAME" "$CUSTOMER_NAME"
read SERVICE_TIME || exit 0
TIME_SQL=$(sql_quote "$SERVICE_TIME")

$PSQL "INSERT INTO appointments (customer_id, service_id, time) VALUES ($CUSTOMER_ID, $SERVICE_ID_SELECTED, '$TIME_SQL');" >/dev/null
printf '\nI have put you down for a %s at %s, %s.\n' "$SERVICE_NAME" "$SERVICE_TIME" "$CUSTOMER_NAME"
