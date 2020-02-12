#!/bin/sh

TARGET="$1"
OWD=$(pwd)

if [ ! -d "$TARGET" ]
then
  echo "$TARGET is not a directory"
  exit 1
fi

if [ -d "$TARGET/.git" ]
then
  echo '[i] The target is a git repo'
  cd "$TARGET"
  SLUG=$(git remote -v | tail -n1 | tr '\t' ' ' | tr -s ' ' | cut -d' ' -f2 | cut -d'/' -f4-5 | cut -d '.' -f1 | sed -e 's/\//--/g')
  cd "$OWD"
else
  SLUG=$(basename $TARGET)
fi


OWASPDC_DIRECTORY="$HOME/OWASP-Dependency-Check"
DATA_DIRECTORY="$OWASPDC_DIRECTORY/data/$SLUG"
REPORT_DIRECTORY="$OWASPDC_DIRECTORY/reports/$SLUG"

if [ ! -d "$DATA_DIRECTORY" ]; then
    echo "[i] Initially creating persistent directories"
    mkdir -p "$DATA_DIRECTORY"
    chmod -R 777 "$DATA_DIRECTORY"

    mkdir -p "$REPORT_DIRECTORY"
    chmod -R 777 "$REPORT_DIRECTORY"
fi


# Make sure we are using the latest version
docker pull owasp/dependency-check

docker run --rm \
    --userns host \
    --volume "$TARGET":/src \
    --volume "$DATA_DIRECTORY":/usr/share/dependency-check/data \
    --volume "$REPORT_DIRECTORY":/report \
    owasp/dependency-check \
    --scan /src \
    --format "ALL" \
    --out "/report" \
    --project "OWASP Check - $SLUG" \
     --enableExperimental
    # Use suppression like this: (/src == $pwd)
    # --suppression "/src/security/dependency-check-suppression.xml"

