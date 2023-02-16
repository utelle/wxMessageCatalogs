#!/bin/sh
# Script for checking for changes in the list of message ids

# The programs we use
MSGFMT="msgfmt --verbose"
MSGSTAT="msgfmt --statistics"
MSGMERGE="msgmerge"
XGETTEXT="xgettext"
XARGS=xargs

# wxWidgets root directory
WXDIR="../wxWidgets"
I18NDIR="../../wxWidgets/samples/internat"

# Language catalog used for check
LANGCAT="fr.po"

# Previous standard message catalog
WXSTDCTLG_OLD="wxstd.pot"
WXSTDCTLG_NEW="wxstd.pot.new"
I18NCTLG_NEW="internat.pot"

# Common xgettext args: C++ syntax, use the specified macro names as markers
XGETTEXT_ARGS="-C -k_ -kwxPLURAL:1,2 -kwxGETTEXT_IN_CONTEXT:1c,2 -kwxGETTEXT_IN_CONTEXT_PLURAL:1c,2,3 -kwxTRANSLATE -kwxTRANSLATE_IN_CONTEXT:1c,2 -kwxGetTranslation --add-comments=TRANSLATORS: -j --no-location -v"

# Flag whether to force an update of the message catalogs
force=0

# --- Internal functions ---

# Function to count the number of messages that are
#   1) translated messages (TR)
#   2) fuzzy translations (FZ)
#   3) untranslated messages (UT)
#   4) total number of messages (TOTAL)
# Returns results in global variables TR, FZ, UT, and TOTAL
count_msgids () {
  local x
  x=`LC_MESSAGES=en_US $MSGSTAT "$1" -o /dev/null 2>&1 | tail -n 1 | sed -e 's/[,\.]//g' \
    -e 's/\([0-9]\+\) translated messages\?/TR=\1/' \
    -e 's/\([0-9]\+\) fuzzy translations\?/FZ=\1/' \
    -e 's/\([0-9]\+\) untranslated messages\?/UT=\1/'`; \
  TR=0 FZ=0 UT=0; \
  eval $x; \
  TOTAL=`expr $TR + $FZ + $UT`
}

# Function to merge updated standard catalog into language specific catalog
merge_pot_into_po () {
  echo "Merge $1.po with $WXSTDCTLG_OLD:"
  $MSGMERGE "$1.po" $WXSTDCTLG_OLD > $1.po.new && mv $1.po.new $1.po;
}

# Function to generate compiled language catalog from source catalog
generate_mo_from_po () {
  echo "Generate $1.mo from $1.po"
  $MSGFMT -c -o "$1.mo" $1.po
}

# Check the wxWidgets standard message catalogs
check_wxstd () {
  echo "--- Check wxWidgets standard catalog"
  echo "--- Extract messages from sources"

  # Create new empty message catalog template
  rm -f $WXSTDCTLG_NEW
  touch $WXSTDCTLG_NEW

  # Extract messages from the wxWidgets source code
  (find $WXDIR/include -name "*.h"; find $WXDIR/src -name "*.cpp"; find $WXDIR/src -name "*.mm") | LC_COLLATE=C sort | $XARGS $XGETTEXT $XGETTEXT_ARGS -o $WXSTDCTLG_NEW

  # Compare old and new message catalog template

  echo "--- Compare old and new standard message catalog"

  # Compare old and new standard catalog, but ignore the timestamp in the header
  tail -n +12 $WXSTDCTLG_OLD > "temp_ctlg.old"
  tail -n +12 $WXSTDCTLG_NEW > "temp_ctlg.new"
#  if cmp -s <(tail -n +12 $WXSTDCTLG_OLD) <(tail -n +12 $WXSTDCTLG_NEW);
  if cmp -s "temp_ctlg.old" "temp_ctlg.new"
  then
    echo "No changes in standard message catalog $WXSTDCTLG_OLD detected."
    DoGen=0
  else
    echo "Changes in standard message catalog $WXSTDCTLG_OLD detected."

    count_msgids "$WXSTDCTLG_OLD"
    TOTALstdold=$TOTAL
    echo "Old standard catalog $WXSTDCTLG_OLD contains $TOTALstdold strings."

    count_msgids "$WXSTDCTLG_NEW"
    TOTALstdnew=$TOTAL
    echo "New standard catalog $WXSTDCTLG_NEW contains $TOTALstdnew strings."

    # Check for real changes in one specific message catalog
    # Just look at the statistics
    count_msgids "$LANGCAT"
    TRold=$TR
    FZold=$FZ
    UTold=$UT
    TOTALold=$TOTAL
    echo "Old language catalog $LANGCAT: $TRold translated, $UTold untranslated, $TOTALold total."

    echo "Merge $LANGCAT with $WXSTDCTLG_NEW"
    $MSGMERGE "$LANGCAT" $WXSTDCTLG_NEW > "$LANGCAT.new"

    count_msgids "$LANGCAT.new"
    TRnew=$TR
    FZnew=$FZ
    UTnew=$UT
    TOTALnew=$TOTAL
    echo "New language catalog $LANGCAT.new: $TRnew translated, $UTnew untranslated, $TOTALnew total."
    rm -f "$LANGCAT.new"

    if [ $TOTALstdold -ne $TOTALstdnew ]; then
      echo "The total number of message ids changed in the standard catalog."
      DoGen=1
    elif [ $TOTALold -ne $TOTALnew ]; then
      echo "The total number of message ids in the standard catalog did not change, but"
      echo "the total number of message ids in the specific language catalog changed."
      DoGen=1
    elif [ $UTold -ne $UTnew ]; then
      echo "The total number of message ids in the standard catalog did not change, and"
      echo "the total number of message ids in the specific language catalog did not change, but"
      echo "the number of untranslated message ids in the specific language catalog changed."
      DoGen=1
    else
      DoGen=0
    fi
  fi

  # Remove temp files
  rm "temp_ctlg.old"
  rm "temp_ctlg.new"

  if [ $force -eq 1 ] && [ $DoGen -eq 0 ];
  then
    echo "Forced update of catalogs requested."
    DoGen=1
  fi

  # Check whether we need to update the message catalogs and to regenerate the compiled catalogs
  if [ $DoGen -eq 1 ];
  then
    echo "Relevant changes were detected in the standard catalog."
    echo "Update message catalogs and regenerate compiled catalogs per language."

    # Replace standard catalog template by new version
    mv wxstd.pot.new $WXSTDCTLG_OLD

    # Determine the list of supported languages
    WX_LINGUAS=`ls *.po 2> /dev/null | sed 's/wxstd.pot//g' | sed 's/.po//g'`
    echo "List of supported languages"
    echo $WX_LINGUAS
    for t in $WX_LINGUAS; do
      merge_pot_into_po $t
      generate_mo_from_po $t
    done
  else
    echo "No relevant changes were detected in the standard catalog."
  fi
}

# Check the samples' message catalogs
check_samples () {
  echo "--- Check samples' message catalogs"

  # Sample 'internat'
  cd internat

  # Create new empty message catalog template
  rm -f $I18NCTLG_NEW
  touch $I18NCTLG_NEW

  # Extract messages from the source code of sample 'internat'
  (find $I18NDIR -name "*.cpp") | LC_COLLATE=C sort | $XARGS $XGETTEXT $XGETTEXT_ARGS -o $I18NCTLG_NEW

  count_msgids "$I18NCTLG_NEW"
  TOTALi18n=$TOTAL
  echo "New I18N sample catalog $I18NCTLG_NEW contains $TOTALi18n strings."

  I18N_LINGUAS=`ls -d */`
  echo "List of supported I18N languages"
  echo $I18N_LINGUAS

  for t in $I18N_LINGUAS; do
    # Check for real changes in a specific message catalog
    # Just look at the statistics
    count_msgids "${t}internat.po"
    TRi18nOld=$TR
    FZi18nOld=$FZ
    UTi18nOld=$UT
    TOTALi18nOld=$TOTAL
    echo "Old I18N catalog ${t}internat.po: $TRi18nOld translated, $UTi18nOld untranslated, $TOTALi18nOld total."

    echo "Merge ${t}internat.po with $I18NCTLG_NEW"
    $MSGMERGE "${t}internat.po" $I18NCTLG_NEW > "${t}internat.po.new"

    count_msgids "${t}internat.po.new"
    TRi18nNew=$TR
    FZi18nNew=$FZ
    UTi18nNew=$UT
    TOTALi18nNew=$TOTAL
    echo "New I18N catalog ${t}internat.po.new: $TRi18nNew translated, $UTi18nNew untranslated, $TOTALi18nNew total."

    updI18n=0
    if [ $TOTALi18nOld -ne $TOTALi18nNew ]; then
      echo "The total number of message ids in the specific language catalog changed."
      updI18n=1
    elif [ $UTold -ne $UTnew ]; then
      echo "The total number of message ids in the specific language catalog did not change, but"
      echo "the number of untranslated message ids in the specific language catalog changed."
      updI18n=1
    else
      updI18n=0
    fi

    if [ $force -eq 1 ] && [ $updI18n -eq 0 ]; then
      echo "Forced update of catalog ${t}internat requested."
      updI18n=1
    fi

    # Check whether we need to update the message catalogs and to regenerate the compiled catalogs
    if [ $updI18n -eq 1 ]; then
      echo "Relevant changes were detected in catalog '${t}internat'."
      echo "Update message catalog '${t}internat' and regenerate compiled catalog."
      $MSGMERGE "${t}internat.po" $I18NCTLG_NEW > ${t}internat.po.new && mv ${t}internat.po.new ${t}internat.po;
      generate_mo_from_po "${t}internat"
    else
      echo "No relevant changes were detected in catalog '${t}internat'."
      rm "${t}internat.po.new"
    fi
  done

  cd ..
}

# --- Main procedure ---

echo "--- Check started `date`"

while getopts 'fh' opt; do
  case "$opt" in
    f)
      force=1
      ;;
    h)
      echo -e "Usage: $(basename $0) [-f]\n  -f   Force update of message catalogs"
      exit 0
      ;;
    ?)
      echo -e "Usage: $(basename $0) [-f]\n  -f   Force update of message catalogs"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

echo "--- Clone wxWidgets repository"
# Clone wxWidgets repository
git clone --single-branch --depth=1 -b master https://github.com/wxWidgets/wxWidgets.git wxWidgets

# Switch to directory containing the standard message catalog
cd wxstd
echo "Working directory: `pwd`"

# Check wxWidgets standard catalogs
check_wxstd

# Test only: check file status
ls -l wxstd*
ls -l $LANGCAT*

cd ../samples

# Check catalogs os internat sample
check_samples

echo "--- Clean up"

cd ..

# Remove wxWidgets repository
rm -rf wxWidgets

echo "--- Check completed `date`"
