#!/bin/bash

if [ -z "$(which jq)" ]; then
  echo "JQ not found. Please install JQ (https://stedolan.github.io/jq/)"
  echo
  echo "On Mac, you can run 'brew install jq'"
  exit 1
fi

AUTHORIZE_ENDPOINT="https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_ENDPOINT="https://oauth2.googleapis.com/token"
TOKENINFO_ENDPOINT="https://openidconnect.googleapis.com/v1/userinfo"

CLIENT_ID="<YOUR CLIENT_ID>.apps.googleusercontent.com"
CLIENT_SECRET="<YOUR CLIENT_SECRET>"
SCOPE="openid%20profile%20email"
REDIRECT_URI="http://localhost:666/stop-here"

echo
echo "Copy/Paste the following URL in your web browser :"
echo "$AUTHORIZE_ENDPOINT?client_id=$CLIENT_ID&scope=$SCOPE&response_type=code&redirect_uri=$REDIRECT_URI&nonce=test&state=test"
echo
echo "You will have to provide the login and password of your test user"
echo
echo "Once you ends up on a blank page (hint: url starts with $REDIRECT_URI), copy/paste this URL below :"
echo

URL=""
while [ -z "$URL" ]; do
  read -p "URL: " URL
done

regex='^.*[?&]code=([^&]+)(&|$)'
if [[ "$URL" =~ $regex ]]; then
  code="${BASH_REMATCH[1]}"
else
  echo "OOPS, could not extract authorization code from the given URL. Sorry."
  exit 1
fi

echo
echo "Exchanging our auth code with an access token..."
echo
curl -sS -X POST -d "client_id=$CLIENT_ID" -d "client_secret=$CLIENT_SECRET" -d "grant_type=authorization_code" -d "redirect_uri=$REDIRECT_URI" -d "code=$code" "$TOKEN_ENDPOINT" |tee auth.json
echo

access_token="$(jq -r .access_token auth.json)"
id_token="$(jq -r .id_token auth.json)"

echo
echo "Access Token = $access_token"
echo
echo "JWT (ID Token) = $id_token"
echo

echo "Checking the access_token"
echo
curl -sS "$TOKENINFO_ENDPOINT" -H "Authorization: Bearer $access_token"
echo
