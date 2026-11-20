#!/bin/zsh
# Shows how many open pull requests on GitHub wait for your review, in yellow; just the
# icon when none do. Hidden when you have no open pull requests at all, or when gh is
# not logged in.
# Run by SketchyBar every 5 minutes.
# Click: a popup with two sections, each newest first:
#   Assigned to me  assigned to you or asking for your review; dimmed once you reviewed it
#   Authored        your own pull requests
# Each line has a status icon; clicking it opens the pull request in the browser.

source "$HOME/.config/dotfiles/theme/sketchybar.sh"
source "$CONFIG_DIR/helpers/hover.sh"
handle_hover && exit 0

# OR and parentheses need GitHub's advanced search (type ISSUE_ADVANCED below).
SEARCH="is:pr is:open archived:false (author:@me OR assignee:@me OR user-review-requested:@me)"

GRAPHQL_QUERY='query($search: String!) {
  viewer { login }
  search(query: $search, type: ISSUE_ADVANCED, first: 50) {
    nodes {
      ... on PullRequest {
        number title url createdAt isDraft isInMergeQueue reviewDecision
        author { login }
        repository { name }
        assignees(first: 20) { nodes { login } }
        reviewRequests(first: 20) { nodes { requestedReviewer { ... on User { login } } } }
        reviews(first: 100) { nodes { state author { __typename login } } }
        commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
        timelineItems(last: 1, itemTypes: [ADDED_TO_MERGE_QUEUE_EVENT, REMOVED_FROM_MERGE_QUEUE_EVENT]) {
          nodes { __typename }
        }
      }
    }
  }
}'

# Turns the search result into one line per pull request, separated by tabs:
#   section (authored or assigned), status, CI failing (1 or 0), pending your review
#   (1 or 0), repository, number, title, link
# Assigned ones first, then your own, each newest first.
# The status follows the same order of checks as GitHub's merge rules: draft, then the
# merge queue, then the reviews.
TO_LINES='
  .data.viewer.login as $me
  | def is_me: (. // "" | ascii_downcase) == ($me | ascii_downcase);

    # The latest opinion of each reviewer. A comment does not replace an earlier approval
    # or change request. Bots and the author do not count.
    def opinions:
      .author.login as $author
      | [.reviews.nodes[]
          | select(.author != null and .author.__typename != "Bot" and .author.login != $author)
          | select(.state == "APPROVED" or .state == "CHANGES_REQUESTED" or .state == "COMMENTED")]
      | reduce .[] as $review ({};
          if $review.state == "COMMENTED" and has($review.author.login) then .
          else .[$review.author.login] = $review.state end)
      | [.[]];

    # reviewDecision is null when the repository requires no review: use the opinions then.
    def review_status:
      .reviewDecision
      // (opinions
          | if any(. == "CHANGES_REQUESTED") then "CHANGES_REQUESTED"
            elif any(. == "APPROVED") then "APPROVED"
            else "REVIEW_REQUIRED" end);

    # Removed from the merge queue without being merged (it is still open).
    def queue_failed:
      .timelineItems.nodes[-1].__typename == "RemovedFromMergeQueueEvent";

    def status:
      if .isDraft then "DRAFT"
      elif .isInMergeQueue then "IN_MERGE_QUEUE"
      elif queue_failed then "MERGE_QUEUE_FAILED"
      else review_status end;

    def ci_failing:
      .commits.nodes[0].commit.statusCheckRollup.state as $ci
      | $ci == "FAILURE" or $ci == "ERROR";

    # Waits for you: your review is asked for (GitHub asks again after new changes), or
    # you were assigned and have not reviewed it yet.
    def pending_my_review:
      ([.reviewRequests.nodes[].requestedReviewer.login | select(is_me)] | length > 0)
      or (([.assignees.nodes[].login | select(is_me)] | length > 0)
          and ([.reviews.nodes[] | select(.state != "PENDING" and (.author.login | is_me))] | length == 0));

    def flag: if . then 1 else 0 end;

    def line($section):
      [$section, status, (ci_failing | flag), (pending_my_review | flag),
       .repository.name, .number, .title, .url] | @tsv;

    [.data.search.nodes[] | select(.number != null)] | sort_by(.createdAt) | reverse
    | (.[] | select(.author.login | is_me | not) | line("assigned")),
      (.[] | select(.author.login | is_me) | line("authored"))
'

case "$SENDER" in
  mouse.clicked)
    if [[ "$(sketchybar --query "$NAME" | jq -r '.popup.drawing')" == "on" ]]; then
      sketchybar --set "$NAME" popup.drawing=off
    else
      sketchybar --set "$NAME" popup.drawing=on
    fi
    exit 0
    ;;
  mouse.exited.global)
    # The mouse left the icon and its popup.
    sketchybar --set "$NAME" popup.drawing=off
    exit 0
    ;;
esac

pull_requests="$(gh api graphql -f query="$GRAPHQL_QUERY" -f search="$SEARCH" --jq "$TO_LINES" 2>/dev/null)"

# Not logged in or offline: keep showing the last list.
(( $? == 0 )) || exit 0

if [[ -z "$pull_requests" ]]; then
  sketchybar --set "$NAME" drawing=off popup.drawing=off
  exit 0
fi

# Sets the icon and its color for a status. Like the review alerts in Slack: needs review,
# approved, changes requested, draft, in the merge queue, or dropped from it.
# All are filled circles, so they read well at a glance and differ by shape as well as color.
set_status_icon() {
  case "$1" in
    DRAFT)              status_icon=$'\U000f06ff'; status_color="$DIM_COLOR" ;;     # pencil
    IN_MERGE_QUEUE)     status_icon=$'\U000f07c3'; status_color="$ACCENT_COLOR" ;;  # dots: waiting in line
    MERGE_QUEUE_FAILED) status_icon=$'\U000f0159'; status_color="$RED_COLOR" ;;     # x
    CHANGES_REQUESTED)  status_icon=$'\U000f0376'; status_color="$RED_COLOR" ;;     # minus
    APPROVED)           status_icon=$'\U000f05e0'; status_color="$GREEN_COLOR" ;;   # check
    *)                  status_icon=$'\U000f0b94'; status_color="$YELLOW_COLOR" ;;  # eye: needs review
  esac
}

CI_FAILING_ICON=$'\U000f0026'   # warning triangle
ROW_FONT="JetBrainsMono Nerd Font Mono:Regular:13.0"
# The Mono font squeezes icons into one character width, so they need a bigger size.
STATUS_ICON_FONT="JetBrainsMono Nerd Font Mono:Regular:20.0"

# The popup: a heading per section, then one line per pull request, like
# "(icon) Fix login redirect ...  dotfiles#12". Replace the lines from last time.
sketchybar --remove '/github\.popup\..*/' >/dev/null 2>&1   # nothing to remove the first time

changes=()
line_number=0
pending=0
previous_section=""

add_heading() {
  local item="github.popup.heading.$1"
  changes+=(--add item "$item" popup.github
            --set "$item" icon.drawing=off
                  label="$2" label.color="$DIM_COLOR" label.font="JetBrainsMono Nerd Font Mono:Bold:12.0"
                  label.padding_left=12 label.padding_right=12)
}

while IFS=$'\t' read -r section pr_status ci_failing pending_review repository pr_number title url; do
  line_number=$(( line_number + 1 ))

  if [[ "$section" != "$previous_section" ]]; then
    case "$section" in
      authored) add_heading authored "Authored" ;;
      assigned) add_heading assigned "Assigned to me" ;;
    esac
    previous_section="$section"
  fi

  # Assigned pull requests you already reviewed step back.
  text_color="$TEXT_COLOR"
  if [[ "$section" == "assigned" ]]; then
    if (( pending_review )); then
      pending=$(( pending + 1 ))
    else
      text_color="$DIM_COLOR"
    fi
  fi

  # Long titles are shortened, so the popup stays a reasonable width.
  if (( ${#title} > 60 )); then
    title="${title[1,59]}…"
  fi
  text="$title  $repository#$pr_number"
  if (( ci_failing )); then
    text="$text  $CI_FAILING_ICON"
  fi

  set_status_icon "$pr_status"
  item="github.popup.pr.$line_number"
  changes+=(--add item "$item" popup.github
            --set "$item" icon="$status_icon" icon.color="$status_color" icon.font="$STATUS_ICON_FONT"
                  icon.padding_left=12 icon.padding_right=8
                  label="$text" label.color="$text_color" label.font="$ROW_FONT" label.padding_right=12
                  click_script="sketchybar --set github popup.drawing=off; open '$url'")
done <<< "$pull_requests"

# The number of pull requests waiting for your review, in yellow like the other alerts;
# just the icon when there are none (with the same space on both sides as other icons).
if (( pending > 0 )); then
  changes+=(--set "$NAME" drawing=on icon.color="$YELLOW_COLOR" icon.padding_right=4
                  label="$pending" label.color="$YELLOW_COLOR" label.drawing=on)
else
  changes+=(--set "$NAME" drawing=on icon.color="$DIM_COLOR" icon.padding_right=8 label.drawing=off)
fi

sketchybar "${changes[@]}"
